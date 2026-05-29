"""Service SavingsPot : CRUD + mouvements deposit/withdraw."""
from uuid import UUID

from sqlalchemy import and_, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.domain.savings_pot import SavingsPot
from app.schemas.savings_pot import SavingsPotCreate, SavingsPotUpdate


class SavingsPotError(Exception):
    pass


class SavingsPotNotFound(SavingsPotError):
    pass


class SavingsPotDuplicateName(SavingsPotError):
    pass


class InsufficientFunds(SavingsPotError):
    """Tentative de retrait > solde."""


async def list_for_user(db: AsyncSession, *, user_id: UUID) -> list[SavingsPot]:
    stmt = (
        select(SavingsPot)
        .where(SavingsPot.user_id == user_id)
        .order_by(SavingsPot.created_at)
    )
    return list((await db.execute(stmt)).scalars().all())


async def get_for_user(
    db: AsyncSession, *, user_id: UUID, pot_id: UUID
) -> SavingsPot:
    stmt = select(SavingsPot).where(
        and_(SavingsPot.id == pot_id, SavingsPot.user_id == user_id)
    )
    pot = (await db.execute(stmt)).scalar_one_or_none()
    if pot is None:
        raise SavingsPotNotFound(f"Enveloppe {pot_id} introuvable")
    return pot


async def create_for_user(
    db: AsyncSession, *, user_id: UUID, payload: SavingsPotCreate
) -> SavingsPot:
    pot = SavingsPot(
        user_id=user_id,
        name=payload.name,
        icon=payload.icon,
        color=payload.color,
        balance_xof=payload.initial_balance_xof,
    )
    db.add(pot)
    try:
        await db.flush()
    except IntegrityError as e:
        await db.rollback()
        raise SavingsPotDuplicateName(
            f"Vous avez deja une enveloppe nommee {payload.name!r}"
        ) from e
    return pot


async def update_for_user(
    db: AsyncSession, *, user_id: UUID, pot_id: UUID, payload: SavingsPotUpdate
) -> SavingsPot:
    pot = await get_for_user(db=db, user_id=user_id, pot_id=pot_id)
    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(pot, field, value)
    try:
        await db.flush()
    except IntegrityError as e:
        await db.rollback()
        raise SavingsPotDuplicateName("Nom deja utilise") from e
    return pot


async def delete_for_user(
    db: AsyncSession, *, user_id: UUID, pot_id: UUID
) -> None:
    pot = await get_for_user(db=db, user_id=user_id, pot_id=pot_id)
    await db.delete(pot)
    await db.flush()


async def deposit(
    db: AsyncSession, *, user_id: UUID, pot_id: UUID, amount_xof: int
) -> SavingsPot:
    pot = await get_for_user(db=db, user_id=user_id, pot_id=pot_id)
    pot.balance_xof += amount_xof
    await db.flush()
    return pot


async def withdraw(
    db: AsyncSession, *, user_id: UUID, pot_id: UUID, amount_xof: int
) -> SavingsPot:
    pot = await get_for_user(db=db, user_id=user_id, pot_id=pot_id)
    if amount_xof > pot.balance_xof:
        raise InsufficientFunds(
            f"Solde insuffisant ({pot.balance_xof} XOF disponibles)"
        )
    pot.balance_xof -= amount_xof
    await db.flush()
    return pot
