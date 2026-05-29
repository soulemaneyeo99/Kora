"""Schemas Pydantic pour l'authentification OTP."""
from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class OTPRequestIn(BaseModel):
    phone: str = Field(..., min_length=5, max_length=20, examples=["0712345678"])


class OTPRequestOut(BaseModel):
    message: str
    expires_in_seconds: int
    # Expose uniquement si DEBUG_OTP=true. None en prod.
    debug_otp: str | None = None


class OTPVerifyIn(BaseModel):
    phone: str = Field(..., min_length=5, max_length=20)
    code: str = Field(..., min_length=4, max_length=8)


class UserPublic(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    phone_e164: str
    display_name: str | None
    locale: str


class TokenOut(BaseModel):
    access_token: str
    token_type: str = "Bearer"
    expires_at: datetime
    user: UserPublic
