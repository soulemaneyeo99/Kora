"""Endpoints savings pots : CRUD + deposit/withdraw."""
from uuid import UUID

from fastapi import APIRouter, HTTPException, status

from app.deps import CurrentUserDep, DbDep
from app.schemas.savings_pot import (
    SavingsPotCreate,
    SavingsPotMovement,
    SavingsPotOut,
    SavingsPotUpdate,
)
from app.services import savings_pot as svc

router = APIRouter()


@router.get("", response_model=list[SavingsPotOut])
async def list_pots(db: DbDep, user: CurrentUserDep) -> list[SavingsPotOut]:
    pots = await svc.list_for_user(db, user_id=user.id)
    return [SavingsPotOut.model_validate(p) for p in pots]


@router.post("", response_model=SavingsPotOut, status_code=status.HTTP_201_CREATED)
async def create_pot(
    payload: SavingsPotCreate, db: DbDep, user: CurrentUserDep
) -> SavingsPotOut:
    try:
        pot = await svc.create_for_user(db, user_id=user.id, payload=payload)
    except svc.SavingsPotDuplicateName as e:
        raise HTTPException(status.HTTP_409_CONFLICT, str(e)) from e
    return SavingsPotOut.model_validate(pot)


@router.get("/{pot_id}", response_model=SavingsPotOut)
async def get_pot(
    pot_id: UUID, db: DbDep, user: CurrentUserDep
) -> SavingsPotOut:
    try:
        pot = await svc.get_for_user(db, user_id=user.id, pot_id=pot_id)
    except svc.SavingsPotNotFound as e:
        raise HTTPException(status.HTTP_404_NOT_FOUND, str(e)) from e
    return SavingsPotOut.model_validate(pot)


@router.patch("/{pot_id}", response_model=SavingsPotOut)
async def update_pot(
    pot_id: UUID,
    payload: SavingsPotUpdate,
    db: DbDep,
    user: CurrentUserDep,
) -> SavingsPotOut:
    try:
        pot = await svc.update_for_user(
            db, user_id=user.id, pot_id=pot_id, payload=payload
        )
    except svc.SavingsPotNotFound as e:
        raise HTTPException(status.HTTP_404_NOT_FOUND, str(e)) from e
    except svc.SavingsPotDuplicateName as e:
        raise HTTPException(status.HTTP_409_CONFLICT, str(e)) from e
    return SavingsPotOut.model_validate(pot)


@router.delete("/{pot_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_pot(pot_id: UUID, db: DbDep, user: CurrentUserDep) -> None:
    try:
        await svc.delete_for_user(db, user_id=user.id, pot_id=pot_id)
    except svc.SavingsPotNotFound as e:
        raise HTTPException(status.HTTP_404_NOT_FOUND, str(e)) from e


@router.post("/{pot_id}/deposit", response_model=SavingsPotOut)
async def deposit(
    pot_id: UUID,
    payload: SavingsPotMovement,
    db: DbDep,
    user: CurrentUserDep,
) -> SavingsPotOut:
    try:
        pot = await svc.deposit(
            db, user_id=user.id, pot_id=pot_id, amount_xof=payload.amount_xof
        )
    except svc.SavingsPotNotFound as e:
        raise HTTPException(status.HTTP_404_NOT_FOUND, str(e)) from e
    return SavingsPotOut.model_validate(pot)


@router.post("/{pot_id}/withdraw", response_model=SavingsPotOut)
async def withdraw(
    pot_id: UUID,
    payload: SavingsPotMovement,
    db: DbDep,
    user: CurrentUserDep,
) -> SavingsPotOut:
    try:
        pot = await svc.withdraw(
            db, user_id=user.id, pot_id=pot_id, amount_xof=payload.amount_xof
        )
    except svc.SavingsPotNotFound as e:
        raise HTTPException(status.HTTP_404_NOT_FOUND, str(e)) from e
    except svc.InsufficientFunds as e:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, str(e)) from e
    return SavingsPotOut.model_validate(pot)
