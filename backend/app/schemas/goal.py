"""Schemas Pydantic pour les objectifs financiers."""
from datetime import date, datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, computed_field

from app.domain.enums import GoalStatus


class GoalCreate(BaseModel):
    title: str = Field(..., min_length=1, max_length=120)
    description: str | None = Field(default=None, max_length=500)
    target_amount_xof: int = Field(..., gt=0, le=10**12)
    target_date: date | None = None
    savings_pot_id: UUID | None = None


class GoalUpdate(BaseModel):
    title: str | None = Field(default=None, min_length=1, max_length=120)
    description: str | None = Field(default=None, max_length=500)
    target_amount_xof: int | None = Field(default=None, gt=0, le=10**12)
    target_date: date | None = None
    status: GoalStatus | None = None
    savings_pot_id: UUID | None = None


class GoalContribution(BaseModel):
    """Versement / retrait manuel sur un objectif (pas lie a un pot)."""

    amount_xof: int = Field(..., gt=0, le=10**12)
    note: str | None = Field(default=None, max_length=200)


class GoalOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    title: str
    description: str | None
    target_amount_xof: int
    current_amount_xof: int
    target_date: date | None
    status: GoalStatus
    savings_pot_id: UUID | None
    created_at: datetime

    @computed_field  # type: ignore[prop-decorator]
    @property
    def progress_pct(self) -> float:
        if self.target_amount_xof == 0:
            return 0.0
        return round(
            min(100.0, 100.0 * self.current_amount_xof / self.target_amount_xof),
            2,
        )
