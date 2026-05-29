"""Service Transaction : creation, listing filtree, modification, suppression.

Regles metier :
- amount_xof > 0 : le signe vient de `kind`.
- Si une categorie est fournie, son `kind` doit correspondre a celui de la transaction
  (sauf pour TRANSFER qui n'a pas de categorie).
- Idempotence : si (user_id, source_ref) existe deja, on retourne l'existant.
"""
from datetime import datetime, time, timezone
from uuid import UUID

from sqlalchemy import and_, func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.domain.enums import TxKind
from app.domain.transaction import Transaction
from app.schemas.transaction import (
    TransactionCreate,
    TransactionFilters,
    TransactionUpdate,
)
from app.services.category import CategoryNotFound, get_for_user as get_category


class TransactionError(Exception):
    pass


class TransactionNotFound(TransactionError):
    pass


class CategoryKindMismatch(TransactionError):
    """La categorie est de type income mais la transaction est expense (ou inverse)."""


class DuplicateSourceRef(TransactionError):
    """source_ref deja utilise pour cet utilisateur."""


async def _validate_category(
    db: AsyncSession, *, user_id: UUID, payload_kind: TxKind, category_id: UUID | None
) -> None:
    if category_id is None:
        return
    if payload_kind == TxKind.TRANSFER:
        raise CategoryKindMismatch(
            "Un transfert ne peut pas etre associe a une categorie"
        )
    try:
        cat = await get_category(db=db, user_id=user_id, category_id=category_id)
    except CategoryNotFound as e:
        raise CategoryKindMismatch(str(e)) from e

    if cat.kind.value != payload_kind.value:
        raise CategoryKindMismatch(
            f"La categorie est {cat.kind.value} mais la transaction est {payload_kind.value}"
        )


async def find_by_source_ref(
    db: AsyncSession, *, user_id: UUID, source_ref: str
) -> Transaction | None:
    stmt = select(Transaction).where(
        and_(Transaction.user_id == user_id, Transaction.source_ref == source_ref)
    )
    return (await db.execute(stmt)).scalar_one_or_none()


async def create_for_user(
    db: AsyncSession, *, user_id: UUID, payload: TransactionCreate
) -> Transaction:
    # Dedup via source_ref si fourni : on renvoie l'existant.
    if payload.source_ref:
        existing = await find_by_source_ref(
            db=db, user_id=user_id, source_ref=payload.source_ref
        )
        if existing is not None:
            return existing

    await _validate_category(
        db=db,
        user_id=user_id,
        payload_kind=payload.kind,
        category_id=payload.category_id,
    )

    tx = Transaction(
        user_id=user_id,
        amount_xof=payload.amount_xof,
        kind=payload.kind,
        source=payload.source,
        source_ref=payload.source_ref,
        category_id=payload.category_id,
        description=payload.description,
        counterparty=payload.counterparty,
        occurred_at=payload.occurred_at,
    )
    db.add(tx)
    try:
        await db.flush()
    except IntegrityError as e:
        await db.rollback()
        raise DuplicateSourceRef(
            "Cette transaction existe deja (source_ref deja utilise)"
        ) from e
    return tx


async def get_for_user(
    db: AsyncSession, *, user_id: UUID, tx_id: UUID
) -> Transaction:
    stmt = select(Transaction).where(
        and_(Transaction.id == tx_id, Transaction.user_id == user_id)
    )
    tx = (await db.execute(stmt)).scalar_one_or_none()
    if tx is None:
        raise TransactionNotFound(f"Transaction {tx_id} introuvable")
    return tx


def _build_list_query(user_id: UUID, filters: TransactionFilters):
    stmt = select(Transaction).where(Transaction.user_id == user_id)
    if filters.kind is not None:
        stmt = stmt.where(Transaction.kind == filters.kind)
    if filters.category_id is not None:
        stmt = stmt.where(Transaction.category_id == filters.category_id)
    if filters.source is not None:
        stmt = stmt.where(Transaction.source == filters.source)
    if filters.date_from is not None:
        start = datetime.combine(filters.date_from, time.min, tzinfo=timezone.utc)
        stmt = stmt.where(Transaction.occurred_at >= start)
    if filters.date_to is not None:
        end = datetime.combine(filters.date_to, time.max, tzinfo=timezone.utc)
        stmt = stmt.where(Transaction.occurred_at <= end)
    return stmt


async def list_for_user(
    db: AsyncSession, *, user_id: UUID, filters: TransactionFilters
) -> tuple[list[Transaction], int]:
    base = _build_list_query(user_id, filters)

    total = (
        await db.execute(select(func.count()).select_from(base.subquery()))
    ).scalar_one()

    stmt = (
        base.order_by(Transaction.occurred_at.desc(), Transaction.created_at.desc())
        .limit(filters.limit)
        .offset(filters.offset)
    )
    items = list((await db.execute(stmt)).scalars().all())
    return items, int(total)


async def update_for_user(
    db: AsyncSession, *, user_id: UUID, tx_id: UUID, payload: TransactionUpdate
) -> Transaction:
    tx = await get_for_user(db=db, user_id=user_id, tx_id=tx_id)
    data = payload.model_dump(exclude_unset=True)

    # Si on change kind ou category, re-valider la coherence.
    if "category_id" in data or "kind" in data:
        new_kind = data.get("kind", tx.kind)
        new_cat = data.get("category_id", tx.category_id)
        await _validate_category(
            db=db, user_id=user_id, payload_kind=new_kind, category_id=new_cat
        )

    for field, value in data.items():
        setattr(tx, field, value)
    await db.flush()
    return tx


async def delete_for_user(
    db: AsyncSession, *, user_id: UUID, tx_id: UUID
) -> None:
    tx = await get_for_user(db=db, user_id=user_id, tx_id=tx_id)
    await db.delete(tx)
    await db.flush()
