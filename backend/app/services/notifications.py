"""Service notifications : dispatch des push aux devices actifs d'un user.

Encapsule la lecture des tokens en DB, l'appel au push provider, et la
desactivation automatique des tokens invalides retournes par le provider.
"""
from __future__ import annotations

import logging
from uuid import UUID

from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.domain.device_token import DeviceToken
from app.services.push_provider import PushMessage, PushProvider, PushResult

logger = logging.getLogger(__name__)


class NotificationService:
    def __init__(self, *, push_provider: PushProvider) -> None:
        self._push = push_provider

    @property
    def provider_name(self) -> str:
        return self._push.name

    async def send_to_user(
        self,
        db: AsyncSession,
        *,
        user_id: UUID,
        message: PushMessage,
    ) -> PushResult:
        """Envoie a tous les devices actifs de l'user. Desactive les invalides."""
        rows = (
            await db.execute(
                select(DeviceToken.token).where(
                    DeviceToken.user_id == user_id,
                    DeviceToken.is_active.is_(True),
                )
            )
        ).scalars().all()

        if not rows:
            return PushResult(sent=0, failed=0, invalid_tokens=[])

        result = await self._push.send(tokens=list(rows), message=message)

        if result.invalid_tokens:
            await db.execute(
                update(DeviceToken)
                .where(
                    DeviceToken.user_id == user_id,
                    DeviceToken.token.in_(result.invalid_tokens),
                )
                .values(is_active=False)
            )
            await db.flush()
            logger.info(
                "Desactive %d device(s) invalides pour user %s",
                len(result.invalid_tokens),
                user_id,
            )
        return result
