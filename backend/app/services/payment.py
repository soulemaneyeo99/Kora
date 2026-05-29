"""Service Payment : calcul commission, initiation, traitement webhook."""
import math
from uuid import UUID

from sqlalchemy import and_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import Settings
from app.domain.enums import GoalStatus, PaymentProvider as PaymentProviderEnum
from app.domain.enums import PaymentStatus
from app.domain.goal import Goal
from app.domain.payment import Payment
from app.services.payment_provider import (
    PaymentProvider,
    PaymentProviderError,
)


class PaymentError(Exception):
    pass


class GoalNotEligibleForCommission(PaymentError):
    """Goal pas atteint a 100% ou commission deja en cours/payee."""


class GoalNotFound(PaymentError):
    pass


class PaymentNotFound(PaymentError):
    pass


def compute_commission_amount(target_xof: int, rate: float) -> int:
    """Arrondi superieur pour ne jamais sous-facturer.

    Pour target=80000 et rate=0.005 -> 400 XOF.
    """
    if target_xof <= 0 or rate <= 0:
        return 0
    return math.ceil(target_xof * rate)


async def estimate_commission(
    db: AsyncSession, *, user_id: UUID, goal_id: UUID, rate: float
) -> tuple[Goal, int]:
    goal = (
        await db.execute(
            select(Goal).where(and_(Goal.id == goal_id, Goal.user_id == user_id))
        )
    ).scalar_one_or_none()
    if goal is None:
        raise GoalNotFound(f"Goal {goal_id} introuvable")
    amount = compute_commission_amount(goal.target_amount_xof, rate)
    return goal, amount


async def _provider_enum_from(provider: PaymentProvider) -> PaymentProviderEnum:
    return PaymentProviderEnum(provider.name)


async def initiate_commission_payment(
    db: AsyncSession,
    *,
    user_id: UUID,
    goal_id: UUID,
    settings: Settings,
    provider: PaymentProvider,
) -> Payment:
    goal, amount = await estimate_commission(
        db, user_id=user_id, goal_id=goal_id, rate=settings.commission_rate
    )

    if goal.status != GoalStatus.COMPLETED and goal.current_amount_xof < goal.target_amount_xof:
        raise GoalNotEligibleForCommission(
            "L'objectif doit etre atteint a 100% avant de payer la commission"
        )
    if amount <= 0:
        raise GoalNotEligibleForCommission("Montant de commission invalide")

    # Bloque si une commission est deja pending/initiated/succeeded pour ce goal.
    existing = (
        await db.execute(
            select(Payment).where(
                Payment.user_id == user_id,
                Payment.goal_id == goal_id,
                Payment.status.in_(
                    [
                        PaymentStatus.PENDING,
                        PaymentStatus.INITIATED,
                        PaymentStatus.SUCCEEDED,
                    ]
                ),
            )
        )
    ).scalars().first()
    if existing is not None:
        if existing.status == PaymentStatus.SUCCEEDED:
            raise GoalNotEligibleForCommission(
                "Commission deja payee pour cet objectif"
            )
        # Sinon : on renvoie l'existant pour ne pas multiplier les tentatives.
        return existing

    payment = Payment(
        user_id=user_id,
        goal_id=goal_id,
        amount_xof=amount,
        purpose="goal_commission",
        provider=await _provider_enum_from(provider),
        status=PaymentStatus.PENDING,
    )
    db.add(payment)
    await db.flush()

    internal_ref = f"kora-{payment.id.hex[:16]}"
    description = f"Commission KORA - {goal.title[:60]}"

    try:
        result = await provider.initiate(
            amount_xof=amount,
            internal_ref=internal_ref,
            description=description,
        )
    except PaymentProviderError as e:
        payment.status = PaymentStatus.FAILED
        payment.failure_reason = str(e)[:300]
        await db.flush()
        raise

    payment.provider_ref = result.provider_ref
    payment.provider_url = result.checkout_url
    payment.status = PaymentStatus.INITIATED
    await db.flush()
    return payment


async def list_for_user(db: AsyncSession, *, user_id: UUID) -> list[Payment]:
    stmt = (
        select(Payment)
        .where(Payment.user_id == user_id)
        .order_by(Payment.created_at.desc())
    )
    return list((await db.execute(stmt)).scalars().all())


async def get_for_user(
    db: AsyncSession, *, user_id: UUID, payment_id: UUID
) -> Payment:
    stmt = select(Payment).where(
        and_(Payment.id == payment_id, Payment.user_id == user_id)
    )
    p = (await db.execute(stmt)).scalar_one_or_none()
    if p is None:
        raise PaymentNotFound(f"Paiement {payment_id} introuvable")
    return p


async def apply_webhook_status(
    db: AsyncSession,
    *,
    provider: PaymentProviderEnum,
    provider_ref: str,
    succeeded: bool,
    failure_reason: str | None = None,
) -> Payment | None:
    """Idempotent : si deja `succeeded`, on ne degrade pas."""
    stmt = select(Payment).where(
        Payment.provider == provider, Payment.provider_ref == provider_ref
    )
    payment = (await db.execute(stmt)).scalar_one_or_none()
    if payment is None:
        return None

    if payment.status == PaymentStatus.SUCCEEDED:
        return payment

    payment.status = PaymentStatus.SUCCEEDED if succeeded else PaymentStatus.FAILED
    if not succeeded and failure_reason:
        payment.failure_reason = failure_reason[:300]
    await db.flush()
    return payment
