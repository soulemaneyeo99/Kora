"""Schemas Pydantic pour les paiements de commission."""
from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict

from app.domain.enums import PaymentProvider, PaymentStatus


class CommissionEstimate(BaseModel):
    goal_id: UUID
    goal_target_xof: int
    commission_rate: float
    commission_amount_xof: int


class PaymentInitiateOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    goal_id: UUID | None
    amount_xof: int
    provider: PaymentProvider
    provider_url: str | None
    provider_ref: str | None
    status: PaymentStatus
    created_at: datetime


class PaymentOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    goal_id: UUID | None
    amount_xof: int
    purpose: str
    provider: PaymentProvider
    provider_ref: str | None
    provider_url: str | None
    status: PaymentStatus
    failure_reason: str | None
    created_at: datetime
    updated_at: datetime


class CinetPayWebhookIn(BaseModel):
    """Payload envoye par CinetPay sur callback (forme stub).

    Le contrat reel a verifier dans la doc CinetPay au moment de la mise en prod.
    """

    cpm_trans_id: str
    cpm_amount: int
    cpm_currency: str
    cpm_result: str  # "00" = succes, autre = echec
    signature: str | None = None
