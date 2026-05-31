"""Schemas Pydantic pour les devices push."""
from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field

from app.domain.enums import DevicePlatform


class DeviceRegisterIn(BaseModel):
    """Body POST /users/me/devices.

    Le token est opaque cote provider (FCM/APNS). On limite la taille a 512
    chars pour eviter qu'un client envoie un blob abusif.
    """

    token: str = Field(..., min_length=10, max_length=512)
    platform: DevicePlatform
    label: str | None = Field(default=None, min_length=1, max_length=80)
    locale: str | None = Field(default=None, min_length=2, max_length=10)


class DeviceOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    platform: DevicePlatform
    label: str | None
    locale: str
    is_active: bool
    last_used_at: datetime
    created_at: datetime


class NotificationTestOut(BaseModel):
    """Renvoye par POST /notifications/test."""

    sent_to_devices: int
    push_provider: str  # "log" ou "fcm"
    title: str
    body: str
