"""Endpoints utilisateur : profil courant + onboarding F02."""
from fastapi import APIRouter

from app.deps import CurrentUserDep, DbDep
from app.schemas.auth import UserPublic, UserUpdate

router = APIRouter()


@router.get("/me", response_model=UserPublic)
async def get_me(user: CurrentUserDep) -> UserPublic:
    return UserPublic.model_validate(user)


@router.patch("/me", response_model=UserPublic)
async def update_me(
    payload: UserUpdate, db: DbDep, user: CurrentUserDep
) -> UserPublic:
    data = payload.model_dump(exclude_unset=True)
    for key, value in data.items():
        setattr(user, key, value)
    await db.flush()
    return UserPublic.model_validate(user)
