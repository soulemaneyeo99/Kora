"""Modele DeviceToken : token push (FCM/APNS) enregistre par le mobile.

Un user peut avoir plusieurs devices (telephone + tablette). On stocke le
token brut (chaine opaque cote provider) + la plateforme. On desactive
plutot qu'on supprime quand le device demande l'unregister : ca preserve
l'historique de delivery.
"""
from datetime import datetime
from uuid import UUID

from sqlalchemy import Boolean, DateTime
from sqlalchemy import Enum as SAEnum
from sqlalchemy import ForeignKey, Index, String
from sqlalchemy.orm import Mapped, mapped_column

from app.domain.base import Base, TimestampMixin, UUIDPrimaryKeyMixin, utcnow
from app.domain.enums import DevicePlatform


class DeviceToken(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "device_tokens"

    user_id: Mapped[UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    # Token opaque cote provider (FCM registration token ou APNS device token).
    token: Mapped[str] = mapped_column(String(512), nullable=False)
    platform: Mapped[DevicePlatform] = mapped_column(
        SAEnum(
            DevicePlatform,
            name="device_platform",
            values_callable=lambda e: [v.value for v in e],
        ),
        nullable=False,
    )
    label: Mapped[str | None] = mapped_column(String(80), nullable=True)
    locale: Mapped[str] = mapped_column(String(10), default="fr_CI", nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    last_used_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=utcnow, nullable=False
    )

    __table_args__ = (
        Index(
            "ix_device_tokens_user_token_unique",
            "user_id",
            "token",
            unique=True,
        ),
    )

    def __repr__(self) -> str:
        return (
            f"<DeviceToken id={self.id} user={self.user_id} "
            f"platform={self.platform.value} active={self.is_active}>"
        )
