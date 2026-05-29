"""Schemas Pydantic pour les enveloppes d'epargne."""
from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class SavingsPotCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=80)
    icon: str | None = Field(default=None, max_length=32)
    color: str | None = Field(default=None, pattern=r"^#[0-9A-Fa-f]{6}([0-9A-Fa-f]{2})?$")
    initial_balance_xof: int = Field(default=0, ge=0, le=10**12)


class SavingsPotUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=80)
    icon: str | None = Field(default=None, max_length=32)
    color: str | None = Field(default=None, pattern=r"^#[0-9A-Fa-f]{6}([0-9A-Fa-f]{2})?$")


class SavingsPotMovement(BaseModel):
    amount_xof: int = Field(..., gt=0, le=10**12)
    note: str | None = Field(default=None, max_length=200)


class SavingsPotOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    name: str
    balance_xof: int
    icon: str | None
    color: str | None
    created_at: datetime
