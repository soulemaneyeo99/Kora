"""Dependances FastAPI partagees : Redis, OTP service, current user."""
from collections.abc import AsyncGenerator
from typing import Annotated

import redis.asyncio as redis
from fastapi import Depends, Header, HTTPException, status
from jose import JWTError
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import Settings, get_settings
from app.core.security import decode_access_token
from app.db import get_db
from app.domain.user import User
from app.services.ingestion import IngestionService
from app.services.notifications import NotificationService
from app.services.otp import OtpService
from app.services.parsers import get_default_registry
from app.services.payment_provider import PaymentProvider, get_payment_provider
from app.services.push_provider import get_push_provider
from app.services.sms_provider import get_sms_provider

SettingsDep = Annotated[Settings, Depends(get_settings)]
DbDep = Annotated[AsyncSession, Depends(get_db)]


async def get_redis(settings: SettingsDep) -> AsyncGenerator[redis.Redis, None]:
    client = redis.from_url(settings.redis_url, decode_responses=True)
    try:
        yield client
    finally:
        await client.aclose()


RedisDep = Annotated[redis.Redis, Depends(get_redis)]


def get_otp_service(redis_client: RedisDep, settings: SettingsDep) -> OtpService:
    return OtpService(
        redis_client=redis_client,
        sms_provider=get_sms_provider(settings),
        debug_expose=settings.debug_otp,
        demo_mode=settings.auth_demo_mode,
    )


OtpServiceDep = Annotated[OtpService, Depends(get_otp_service)]


def get_ingestion_service() -> IngestionService:
    return IngestionService(registry=get_default_registry())


IngestionServiceDep = Annotated[IngestionService, Depends(get_ingestion_service)]


def get_payment_provider_dep(settings: SettingsDep) -> PaymentProvider:
    return get_payment_provider(settings)


PaymentProviderDep = Annotated[PaymentProvider, Depends(get_payment_provider_dep)]


def get_notification_service(settings: SettingsDep) -> NotificationService:
    return NotificationService(push_provider=get_push_provider(settings))


NotificationServiceDep = Annotated[
    NotificationService, Depends(get_notification_service)
]


async def get_current_user(
    db: DbDep,
    authorization: Annotated[str | None, Header()] = None,
) -> User:
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Token manquant")

    token = authorization.split(" ", 1)[1].strip()
    try:
        user_id = decode_access_token(token)
    except JWTError as e:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Token invalide") from e

    user = (await db.execute(select(User).where(User.id == user_id))).scalar_one_or_none()
    if user is None or not user.is_active:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Utilisateur introuvable")

    return user


CurrentUserDep = Annotated[User, Depends(get_current_user)]
