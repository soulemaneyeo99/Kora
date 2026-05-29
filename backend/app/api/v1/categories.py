"""Endpoints categories : CRUD utilisateur."""
from uuid import UUID

from fastapi import APIRouter, HTTPException, Query, status

from app.deps import CurrentUserDep, DbDep
from app.domain.enums import CategoryKind
from app.schemas.category import CategoryCreate, CategoryOut, CategoryUpdate
from app.services import category as svc

router = APIRouter()


@router.get("", response_model=list[CategoryOut])
async def list_categories(
    db: DbDep,
    user: CurrentUserDep,
    kind: CategoryKind | None = Query(default=None),
) -> list[CategoryOut]:
    cats = await svc.list_for_user(db, user_id=user.id, kind=kind)
    return [CategoryOut.model_validate(c) for c in cats]


@router.post("", response_model=CategoryOut, status_code=status.HTTP_201_CREATED)
async def create_category(
    payload: CategoryCreate, db: DbDep, user: CurrentUserDep
) -> CategoryOut:
    try:
        cat = await svc.create_for_user(db, user_id=user.id, payload=payload)
    except svc.CategoryDuplicateName as e:
        raise HTTPException(status.HTTP_409_CONFLICT, str(e)) from e
    return CategoryOut.model_validate(cat)


@router.get("/{category_id}", response_model=CategoryOut)
async def get_category(
    category_id: UUID, db: DbDep, user: CurrentUserDep
) -> CategoryOut:
    try:
        cat = await svc.get_for_user(db, user_id=user.id, category_id=category_id)
    except svc.CategoryNotFound as e:
        raise HTTPException(status.HTTP_404_NOT_FOUND, str(e)) from e
    return CategoryOut.model_validate(cat)


@router.patch("/{category_id}", response_model=CategoryOut)
async def update_category(
    category_id: UUID,
    payload: CategoryUpdate,
    db: DbDep,
    user: CurrentUserDep,
) -> CategoryOut:
    try:
        cat = await svc.update_for_user(
            db, user_id=user.id, category_id=category_id, payload=payload
        )
    except svc.CategoryNotFound as e:
        raise HTTPException(status.HTTP_404_NOT_FOUND, str(e)) from e
    except svc.CategoryNotEditable as e:
        raise HTTPException(status.HTTP_403_FORBIDDEN, str(e)) from e
    except svc.CategoryDuplicateName as e:
        raise HTTPException(status.HTTP_409_CONFLICT, str(e)) from e
    return CategoryOut.model_validate(cat)


@router.delete("/{category_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_category(
    category_id: UUID, db: DbDep, user: CurrentUserDep
) -> None:
    try:
        await svc.delete_for_user(db, user_id=user.id, category_id=category_id)
    except svc.CategoryNotFound as e:
        raise HTTPException(status.HTTP_404_NOT_FOUND, str(e)) from e
    except svc.CategoryNotEditable as e:
        raise HTTPException(status.HTTP_403_FORBIDDEN, str(e)) from e
