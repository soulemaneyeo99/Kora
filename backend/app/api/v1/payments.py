"""Endpoints paiement : estimation, initiation, listing, webhook CinetPay."""
import logging
from uuid import UUID

from fastapi import APIRouter, Header, HTTPException, status

from app.deps import (
    CurrentUserDep,
    DbDep,
    PaymentProviderDep,
    SettingsDep,
)
from app.domain.enums import PaymentProvider as PaymentProviderEnum
from app.schemas.payment import (
    CinetPayWebhookIn,
    CommissionEstimate,
    PaymentInitiateOut,
    PaymentOut,
)
from app.services import payment as svc
from app.services.payment_provider import PaymentProviderError

logger = logging.getLogger(__name__)
router = APIRouter()


@router.get(
    "/commission/{goal_id}/estimate", response_model=CommissionEstimate
)
async def estimate(
    goal_id: UUID,
    db: DbDep,
    user: CurrentUserDep,
    settings: SettingsDep,
) -> CommissionEstimate:
    try:
        goal, amount = await svc.estimate_commission(
            db, user_id=user.id, goal_id=goal_id, rate=settings.commission_rate
        )
    except svc.GoalNotFound as e:
        raise HTTPException(status.HTTP_404_NOT_FOUND, str(e)) from e
    return CommissionEstimate(
        goal_id=goal.id,
        goal_target_xof=goal.target_amount_xof,
        commission_rate=settings.commission_rate,
        commission_amount_xof=amount,
    )


@router.post(
    "/commission/{goal_id}/initiate",
    response_model=PaymentInitiateOut,
    status_code=status.HTTP_201_CREATED,
)
async def initiate(
    goal_id: UUID,
    db: DbDep,
    user: CurrentUserDep,
    settings: SettingsDep,
    provider: PaymentProviderDep,
) -> PaymentInitiateOut:
    try:
        payment = await svc.initiate_commission_payment(
            db,
            user_id=user.id,
            goal_id=goal_id,
            settings=settings,
            provider=provider,
        )
    except svc.GoalNotFound as e:
        raise HTTPException(status.HTTP_404_NOT_FOUND, str(e)) from e
    except svc.GoalNotEligibleForCommission as e:
        raise HTTPException(status.HTTP_409_CONFLICT, str(e)) from e
    except PaymentProviderError as e:
        raise HTTPException(
            status.HTTP_502_BAD_GATEWAY, f"Provider paiement : {e}"
        ) from e
    return PaymentInitiateOut.model_validate(payment)


@router.get("", response_model=list[PaymentOut])
async def list_payments(
    db: DbDep, user: CurrentUserDep
) -> list[PaymentOut]:
    items = await svc.list_for_user(db, user_id=user.id)
    return [PaymentOut.model_validate(p) for p in items]


@router.get("/{payment_id}", response_model=PaymentOut)
async def get_payment(
    payment_id: UUID, db: DbDep, user: CurrentUserDep
) -> PaymentOut:
    try:
        p = await svc.get_for_user(db, user_id=user.id, payment_id=payment_id)
    except svc.PaymentNotFound as e:
        raise HTTPException(status.HTTP_404_NOT_FOUND, str(e)) from e
    return PaymentOut.model_validate(p)


# ---- Webhook CinetPay ------------------------------------------------------


@router.post("/webhook/cinetpay", status_code=status.HTTP_200_OK)
async def cinetpay_webhook(
    payload: CinetPayWebhookIn,
    db: DbDep,
    provider: PaymentProviderDep,
    x_signature: str | None = Header(default=None, alias="X-Signature"),
) -> dict[str, str]:
    raw = payload.model_dump()
    if not provider.verify_webhook_signature(
        payload=raw, signature=x_signature or payload.signature
    ):
        logger.warning("Webhook CinetPay : signature invalide ref=%s", payload.cpm_trans_id)
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Signature invalide")

    succeeded = payload.cpm_result == "00"
    failure_reason = None if succeeded else f"CinetPay result={payload.cpm_result}"

    payment = await svc.apply_webhook_status(
        db,
        provider=PaymentProviderEnum.CINETPAY,
        provider_ref=payload.cpm_trans_id,
        succeeded=succeeded,
        failure_reason=failure_reason,
    )
    if payment is None:
        # CinetPay ne doit pas re-essayer indefiniment : on accuse reception sans erreur.
        logger.warning(
            "Webhook CinetPay : paiement inconnu provider_ref=%s", payload.cpm_trans_id
        )
        return {"status": "ignored", "reason": "unknown_payment"}

    return {"status": "processed", "payment_status": payment.status.value}
