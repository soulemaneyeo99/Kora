"""Service Category : CRUD + acces aux defauts systeme.

Une categorie est visible par un utilisateur si :
- elle est systeme (user_id IS NULL), OU
- elle lui appartient (user_id == current_user.id).
"""
from uuid import UUID

from sqlalchemy import and_, or_, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.domain.category import Category
from app.domain.enums import CategoryKind
from app.schemas.category import CategoryCreate, CategoryUpdate


class CategoryError(Exception):
    pass


class CategoryNotFound(CategoryError):
    pass


class CategoryDuplicateName(CategoryError):
    pass


class CategoryNotEditable(CategoryError):
    """Tentative de modifier/supprimer une categorie systeme."""


# ---- catalogue par defaut, seed au demarrage ------------------------------

DEFAULT_INCOME_CATEGORIES: list[tuple[str, str | None, str | None]] = [
    # (name, icon, color)
    ("Salaire", "work", "#10b981"),
    ("Mobile Money recu", "smartphone", "#3b82f6"),
    ("Vente", "storefront", "#22c55e"),
    ("Autre revenu", "payments", "#6b7280"),
]

DEFAULT_EXPENSE_CATEGORIES: list[tuple[str, str | None, str | None]] = [
    ("Nourriture", "restaurant", "#f97316"),
    ("Transport", "directions_bus", "#0ea5e9"),
    ("Logement", "home", "#a855f7"),
    ("Sante", "medical_services", "#ef4444"),
    ("Education", "school", "#14b8a6"),
    ("Loisirs", "sports_esports", "#eab308"),
    ("Mobile Money envoye", "send", "#3b82f6"),
    ("Frais bancaires", "account_balance", "#64748b"),
    ("Vetements", "checkroom", "#ec4899"),
    ("Autre depense", "more_horiz", "#6b7280"),
]


async def seed_default_categories(db: AsyncSession) -> int:
    """Idempotent : cree les categories systeme manquantes. Retourne le nb cree."""
    existing = (
        await db.execute(
            select(Category.name, Category.kind).where(Category.user_id.is_(None))
        )
    ).all()
    existing_set = {(name, kind) for name, kind in existing}

    created = 0
    for name, icon, color in DEFAULT_INCOME_CATEGORIES:
        if (name, CategoryKind.INCOME) in existing_set:
            continue
        db.add(
            Category(
                user_id=None,
                name=name,
                kind=CategoryKind.INCOME,
                icon=icon,
                color=color,
                is_default=True,
            )
        )
        created += 1

    for name, icon, color in DEFAULT_EXPENSE_CATEGORIES:
        if (name, CategoryKind.EXPENSE) in existing_set:
            continue
        db.add(
            Category(
                user_id=None,
                name=name,
                kind=CategoryKind.EXPENSE,
                icon=icon,
                color=color,
                is_default=True,
            )
        )
        created += 1

    if created:
        await db.flush()
    return created


# ---- CRUD utilisateur ------------------------------------------------------


async def list_for_user(
    db: AsyncSession,
    *,
    user_id: UUID,
    kind: CategoryKind | None = None,
) -> list[Category]:
    stmt = select(Category).where(
        or_(Category.user_id.is_(None), Category.user_id == user_id)
    )
    if kind is not None:
        stmt = stmt.where(Category.kind == kind)
    stmt = stmt.order_by(Category.is_default.desc(), Category.name)
    result = await db.execute(stmt)
    return list(result.scalars().all())


async def get_for_user(
    db: AsyncSession, *, user_id: UUID, category_id: UUID
) -> Category:
    stmt = select(Category).where(
        and_(
            Category.id == category_id,
            or_(Category.user_id.is_(None), Category.user_id == user_id),
        )
    )
    cat = (await db.execute(stmt)).scalar_one_or_none()
    if cat is None:
        raise CategoryNotFound(f"Categorie {category_id} introuvable")
    return cat


async def create_for_user(
    db: AsyncSession, *, user_id: UUID, payload: CategoryCreate
) -> Category:
    cat = Category(
        user_id=user_id,
        name=payload.name,
        kind=payload.kind,
        icon=payload.icon,
        color=payload.color,
        is_default=False,
    )
    db.add(cat)
    try:
        await db.flush()
    except IntegrityError as e:
        await db.rollback()
        raise CategoryDuplicateName(
            f"Vous avez deja une categorie nommee {payload.name!r}"
        ) from e
    return cat


async def update_for_user(
    db: AsyncSession, *, user_id: UUID, category_id: UUID, payload: CategoryUpdate
) -> Category:
    cat = await get_for_user(db=db, user_id=user_id, category_id=category_id)
    if cat.user_id is None:
        raise CategoryNotEditable("Une categorie systeme ne peut pas etre modifiee")

    data = payload.model_dump(exclude_unset=True)
    for field, value in data.items():
        setattr(cat, field, value)
    try:
        await db.flush()
    except IntegrityError as e:
        await db.rollback()
        raise CategoryDuplicateName(
            "Nom deja utilise pour une autre categorie"
        ) from e
    return cat


async def delete_for_user(
    db: AsyncSession, *, user_id: UUID, category_id: UUID
) -> None:
    cat = await get_for_user(db=db, user_id=user_id, category_id=category_id)
    if cat.user_id is None:
        raise CategoryNotEditable("Une categorie systeme ne peut pas etre supprimee")
    await db.delete(cat)
    await db.flush()
