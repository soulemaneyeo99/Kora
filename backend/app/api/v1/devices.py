"""Endpoints devices push : enregistrement, liste, desactivation."""
from uuid import UUID

from fastapi import APIRouter, HTTPException, status
from sqlalchemy import select

from app.deps import CurrentUserDep, DbDep
from app.domain.device_token import DeviceToken
from app.domain.base import utcnow
from app.schemas.device import DeviceOut, DeviceRegisterIn

router = APIRouter()


@router.post(
    "/me/devices",
    response_model=DeviceOut,
    status_code=status.HTTP_201_CREATED,
)
async def register_device(
    payload: DeviceRegisterIn, db: DbDep, user: CurrentUserDep
) -> DeviceOut:
    """Upsert d'un token push.

    Idempotent : meme token reposte -> reactive + bump last_used_at.
    Permet au mobile de re-register a chaque demarrage sans creer de doublons.
    """
    existing = (
        await db.execute(
            select(DeviceToken).where(
                DeviceToken.user_id == user.id,
                DeviceToken.token == payload.token,
            )
        )
    ).scalar_one_or_none()

    if existing is not None:
        existing.platform = payload.platform
        if payload.label is not None:
            existing.label = payload.label
        if payload.locale is not None:
            existing.locale = payload.locale
        existing.is_active = True
        existing.last_used_at = utcnow()
        await db.flush()
        return DeviceOut.model_validate(existing)

    device = DeviceToken(
        user_id=user.id,
        token=payload.token,
        platform=payload.platform,
        label=payload.label,
        locale=payload.locale or user.locale,
        is_active=True,
        last_used_at=utcnow(),
    )
    db.add(device)
    await db.flush()
    return DeviceOut.model_validate(device)


@router.get("/me/devices", response_model=list[DeviceOut])
async def list_devices(db: DbDep, user: CurrentUserDep) -> list[DeviceOut]:
    rows = (
        await db.execute(
            select(DeviceToken)
            .where(DeviceToken.user_id == user.id)
            .order_by(DeviceToken.last_used_at.desc())
        )
    ).scalars().all()
    return [DeviceOut.model_validate(r) for r in rows]


@router.delete(
    "/me/devices/{device_id}", status_code=status.HTTP_204_NO_CONTENT
)
async def deactivate_device(
    device_id: UUID, db: DbDep, user: CurrentUserDep
) -> None:
    """Soft-delete : on garde la row mais on coupe les push."""
    device = (
        await db.execute(
            select(DeviceToken).where(
                DeviceToken.id == device_id,
                DeviceToken.user_id == user.id,
            )
        )
    ).scalar_one_or_none()
    if device is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Device introuvable")
    device.is_active = False
    await db.flush()
