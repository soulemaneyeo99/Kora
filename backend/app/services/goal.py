"""Service Goal : CRUD + contributions + auto-completion.

Si le goal est lie a un SavingsPot, `current_amount_xof` est synchronise sur le
solde du pot a chaque lecture. Sinon, ce champ est ajuste manuellement par les
endpoints /contribute et /withdraw.
"""
from uuid import UUID

from sqlalchemy import and_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.domain.enums import GoalStatus
from app.domain.goal import Goal
from app.schemas.goal import GoalCreate, GoalUpdate
from app.services.savings_pot import (
    SavingsPotNotFound,
    get_for_user as get_pot,
)


class GoalError(Exception):
    pass


class GoalNotFound(GoalError):
    pass


class GoalLinkedPotInvalid(GoalError):
    """Le savings_pot_id fourni n'existe pas pour cet utilisateur."""


class GoalNotEditable(GoalError):
    """Tentative de modifier un goal cloture (completed/abandoned)."""


async def _validate_pot_link(
    db: AsyncSession, *, user_id: UUID, pot_id: UUID | None
) -> None:
    if pot_id is None:
        return
    try:
        await get_pot(db=db, user_id=user_id, pot_id=pot_id)
    except SavingsPotNotFound as e:
        raise GoalLinkedPotInvalid(str(e)) from e


async def _sync_with_pot(db: AsyncSession, goal: Goal) -> Goal:
    """Si le goal est lie a un pot, recopie le solde dans current_amount_xof."""
    if goal.savings_pot_id is None:
        return goal
    from app.domain.savings_pot import SavingsPot  # import local pour eviter cycles

    pot_row = (
        await db.execute(
            select(SavingsPot).where(SavingsPot.id == goal.savings_pot_id)
        )
    ).scalar_one_or_none()
    if pot_row is not None:
        goal.current_amount_xof = pot_row.balance_xof
        if (
            goal.status == GoalStatus.ACTIVE
            and goal.current_amount_xof >= goal.target_amount_xof
        ):
            goal.status = GoalStatus.COMPLETED
    return goal


async def list_for_user(
    db: AsyncSession, *, user_id: UUID, status: GoalStatus | None = None
) -> list[Goal]:
    stmt = select(Goal).where(Goal.user_id == user_id)
    if status is not None:
        stmt = stmt.where(Goal.status == status)
    stmt = stmt.order_by(Goal.created_at.desc())
    goals = list((await db.execute(stmt)).scalars().all())
    for g in goals:
        await _sync_with_pot(db, g)
    return goals


async def get_for_user(db: AsyncSession, *, user_id: UUID, goal_id: UUID) -> Goal:
    stmt = select(Goal).where(and_(Goal.id == goal_id, Goal.user_id == user_id))
    goal = (await db.execute(stmt)).scalar_one_or_none()
    if goal is None:
        raise GoalNotFound(f"Objectif {goal_id} introuvable")
    await _sync_with_pot(db, goal)
    return goal


async def create_for_user(
    db: AsyncSession, *, user_id: UUID, payload: GoalCreate
) -> Goal:
    await _validate_pot_link(db=db, user_id=user_id, pot_id=payload.savings_pot_id)

    goal = Goal(
        user_id=user_id,
        title=payload.title,
        description=payload.description,
        target_amount_xof=payload.target_amount_xof,
        target_date=payload.target_date,
        savings_pot_id=payload.savings_pot_id,
        status=GoalStatus.ACTIVE,
    )
    db.add(goal)
    await db.flush()
    await _sync_with_pot(db, goal)
    return goal


async def update_for_user(
    db: AsyncSession, *, user_id: UUID, goal_id: UUID, payload: GoalUpdate
) -> Goal:
    goal = await get_for_user(db=db, user_id=user_id, goal_id=goal_id)
    if goal.status != GoalStatus.ACTIVE and payload.status != GoalStatus.ACTIVE:
        raise GoalNotEditable(
            "Un objectif cloture ne peut etre modifie (sauf reactivation explicite)"
        )

    data = payload.model_dump(exclude_unset=True)
    if "savings_pot_id" in data:
        await _validate_pot_link(
            db=db, user_id=user_id, pot_id=data["savings_pot_id"]
        )

    for field, value in data.items():
        setattr(goal, field, value)
    await db.flush()
    await _sync_with_pot(db, goal)
    return goal


async def delete_for_user(
    db: AsyncSession, *, user_id: UUID, goal_id: UUID
) -> None:
    goal = await get_for_user(db=db, user_id=user_id, goal_id=goal_id)
    await db.delete(goal)
    await db.flush()


async def contribute(
    db: AsyncSession, *, user_id: UUID, goal_id: UUID, amount_xof: int
) -> Goal:
    """Ajout manuel — utilise uniquement quand pas de pot lie."""
    goal = await get_for_user(db=db, user_id=user_id, goal_id=goal_id)
    if goal.savings_pot_id is not None:
        raise GoalNotEditable(
            "Ce goal est lie a une enveloppe : depose dans l'enveloppe directement"
        )
    if goal.status != GoalStatus.ACTIVE:
        raise GoalNotEditable("Objectif non actif")

    goal.current_amount_xof += amount_xof
    # Auto-completion
    if goal.current_amount_xof >= goal.target_amount_xof:
        goal.status = GoalStatus.COMPLETED
    await db.flush()
    return goal


async def withdraw(
    db: AsyncSession, *, user_id: UUID, goal_id: UUID, amount_xof: int
) -> Goal:
    goal = await get_for_user(db=db, user_id=user_id, goal_id=goal_id)
    if goal.savings_pot_id is not None:
        raise GoalNotEditable(
            "Ce goal est lie a une enveloppe : retire de l'enveloppe directement"
        )
    if amount_xof > goal.current_amount_xof:
        raise GoalNotEditable(
            f"Montant > progres actuel ({goal.current_amount_xof} XOF)"
        )
    goal.current_amount_xof -= amount_xof
    # Si on retire d'un goal complete, il redevient actif
    if goal.status == GoalStatus.COMPLETED:
        goal.status = GoalStatus.ACTIVE
    await db.flush()
    return goal
