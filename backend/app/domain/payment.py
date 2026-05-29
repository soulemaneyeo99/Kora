"""Modele Payment : commission de reussite payee par l'utilisateur a KORA.

Politique :
- Une commission de COMMISSION_RATE est due quand un goal atteint 100%.
- Engagement pris a la creation du goal ; pas de prelevement automatique : c'est
  l'utilisateur qui declenche le paiement via /payments/commission.
- Tant qu'un goal a une commission `pending` ou `succeeded`, on n'en cree pas une 2e.
"""
from uuid import UUID

from sqlalchemy import CheckConstraint, ForeignKey, Integer, String, UniqueConstraint
from sqlalchemy.dialects.postgresql import ENUM as PgEnum
from sqlalchemy.orm import Mapped, mapped_column

from app.domain.base import Base, TimestampMixin, UUIDPrimaryKeyMixin
from app.domain.enums import PaymentProvider, PaymentStatus


class Payment(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "payments"

    user_id: Mapped[UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    goal_id: Mapped[UUID | None] = mapped_column(
        ForeignKey("goals.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )

    amount_xof: Mapped[int] = mapped_column(Integer, nullable=False)
    purpose: Mapped[str] = mapped_column(
        String(40), nullable=False, default="goal_commission"
    )

    provider: Mapped[PaymentProvider] = mapped_column(
        PgEnum(PaymentProvider, name="payment_provider", create_type=True),
        nullable=False,
    )
    provider_ref: Mapped[str | None] = mapped_column(String(120), nullable=True)
    provider_url: Mapped[str | None] = mapped_column(String(500), nullable=True)

    status: Mapped[PaymentStatus] = mapped_column(
        PgEnum(PaymentStatus, name="payment_status", create_type=True),
        nullable=False,
        default=PaymentStatus.PENDING,
    )
    failure_reason: Mapped[str | None] = mapped_column(String(300), nullable=True)

    __table_args__ = (
        CheckConstraint("amount_xof > 0", name="ck_payments_amount_positive"),
        UniqueConstraint("provider", "provider_ref", name="uq_payments_provider_ref"),
    )

    def __repr__(self) -> str:
        return (
            f"<Payment id={self.id} {self.amount_xof} XOF "
            f"{self.provider.value}/{self.status.value}>"
        )
