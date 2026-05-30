"""Schemas Pydantic pour l'authentification OTP."""
from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field

from app.domain.enums import IncomeBracket, PrimaryGoal


class OTPRequestIn(BaseModel):
    phone: str = Field(..., min_length=5, max_length=20, examples=["0712345678"])


class OTPRequestOut(BaseModel):
    message: str
    expires_in_seconds: int
    # Expose uniquement si DEBUG_OTP=true. None en prod.
    debug_otp: str | None = None
    # True quand AUTH_DEMO_MODE=true : le mobile peut alors auto-soumettre.
    demo_mode: bool = False


class OTPVerifyIn(BaseModel):
    phone: str = Field(..., min_length=5, max_length=20)
    code: str = Field(..., min_length=4, max_length=8)


class UserPublic(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    phone_e164: str
    display_name: str | None
    locale: str
    income_bracket: IncomeBracket | None = None
    primary_goal: PrimaryGoal | None = None
    has_completed_onboarding: bool = False


class UserUpdate(BaseModel):
    """PATCH /users/me - tous les champs sont optionnels."""

    display_name: str | None = Field(default=None, min_length=1, max_length=80)
    income_bracket: IncomeBracket | None = None
    primary_goal: PrimaryGoal | None = None


class TokenOut(BaseModel):
    access_token: str
    token_type: str = "Bearer"
    expires_at: datetime
    user: UserPublic
