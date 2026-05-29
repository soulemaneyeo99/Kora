"""Schemas Pydantic pour les transactions."""
from datetime import date, datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field

from app.domain.enums import TxKind, TxSource


class TransactionCreate(BaseModel):
    amount_xof: int = Field(..., gt=0, le=10**12, description="Montant en FCFA, > 0")
    kind: TxKind
    category_id: UUID | None = None
    description: str | None = Field(default=None, max_length=200)
    counterparty: str | None = Field(default=None, max_length=120)
    occurred_at: datetime = Field(..., description="ISO 8601, UTC ou avec offset")
    source: TxSource = TxSource.MANUAL
    source_ref: str | None = Field(default=None, max_length=120)


class TransactionUpdate(BaseModel):
    amount_xof: int | None = Field(default=None, gt=0, le=10**12)
    kind: TxKind | None = None
    category_id: UUID | None = None
    description: str | None = Field(default=None, max_length=200)
    counterparty: str | None = Field(default=None, max_length=120)
    occurred_at: datetime | None = None


class TransactionOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    amount_xof: int
    kind: TxKind
    source: TxSource
    source_ref: str | None
    category_id: UUID | None
    description: str | None
    counterparty: str | None
    occurred_at: datetime
    created_at: datetime


class TransactionListOut(BaseModel):
    items: list[TransactionOut]
    total: int
    limit: int
    offset: int


class TransactionFilters(BaseModel):
    """Filtres acceptes en query string sur GET /transactions."""

    kind: TxKind | None = None
    category_id: UUID | None = None
    date_from: date | None = None
    date_to: date | None = None
    source: TxSource | None = None
    limit: int = Field(default=50, ge=1, le=200)
    offset: int = Field(default=0, ge=0)
