"""Endpoints transactions : CRUD + listing filtre/paginé."""
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status

from app.deps import CurrentUserDep, DbDep
from app.schemas.transaction import (
    TransactionCreate,
    TransactionFilters,
    TransactionListOut,
    TransactionOut,
    TransactionUpdate,
)
from app.services import transaction as svc

router = APIRouter()


@router.get("", response_model=TransactionListOut)
async def list_transactions(
    db: DbDep,
    user: CurrentUserDep,
    filters: TransactionFilters = Depends(),
) -> TransactionListOut:
    items, total = await svc.list_for_user(db, user_id=user.id, filters=filters)
    return TransactionListOut(
        items=[TransactionOut.model_validate(t) for t in items],
        total=total,
        limit=filters.limit,
        offset=filters.offset,
    )


@router.post("", response_model=TransactionOut, status_code=status.HTTP_201_CREATED)
async def create_transaction(
    payload: TransactionCreate, db: DbDep, user: CurrentUserDep
) -> TransactionOut:
    try:
        tx = await svc.create_for_user(db, user_id=user.id, payload=payload)
    except svc.CategoryKindMismatch as e:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, str(e)) from e
    except svc.DuplicateSourceRef as e:
        raise HTTPException(status.HTTP_409_CONFLICT, str(e)) from e
    return TransactionOut.model_validate(tx)


@router.get("/{tx_id}", response_model=TransactionOut)
async def get_transaction(
    tx_id: UUID, db: DbDep, user: CurrentUserDep
) -> TransactionOut:
    try:
        tx = await svc.get_for_user(db, user_id=user.id, tx_id=tx_id)
    except svc.TransactionNotFound as e:
        raise HTTPException(status.HTTP_404_NOT_FOUND, str(e)) from e
    return TransactionOut.model_validate(tx)


@router.patch("/{tx_id}", response_model=TransactionOut)
async def update_transaction(
    tx_id: UUID,
    payload: TransactionUpdate,
    db: DbDep,
    user: CurrentUserDep,
) -> TransactionOut:
    try:
        tx = await svc.update_for_user(
            db, user_id=user.id, tx_id=tx_id, payload=payload
        )
    except svc.TransactionNotFound as e:
        raise HTTPException(status.HTTP_404_NOT_FOUND, str(e)) from e
    except svc.CategoryKindMismatch as e:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, str(e)) from e
    return TransactionOut.model_validate(tx)


@router.delete("/{tx_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_transaction(
    tx_id: UUID, db: DbDep, user: CurrentUserDep
) -> None:
    try:
        await svc.delete_for_user(db, user_id=user.id, tx_id=tx_id)
    except svc.TransactionNotFound as e:
        raise HTTPException(status.HTTP_404_NOT_FOUND, str(e)) from e
