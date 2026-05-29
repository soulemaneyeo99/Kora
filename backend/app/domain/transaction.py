"""Modele Transaction : mouvement d'argent unitaire.

Notes monetaires :
- XOF n'a pas de sous-unites. On stocke en entier de XOF (1 = 1 FCFA).
- `amount_xof` est TOUJOURS positif. Le sens est porte par `kind`.

Idempotence :
- `source_ref` (ex : id de notif Android) + `user_id` doivent etre uniques quand
  source_ref est present. Permet l'ingestion sans doublon.
"""
from datetime import datetime
from uuid import UUID

from sqlalchemy import (
    CheckConstraint,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    String,
)
from sqlalchemy.dialects.postgresql import ENUM as PgEnum
from sqlalchemy.orm import Mapped, mapped_column

from app.domain.base import Base, TimestampMixin, UUIDPrimaryKeyMixin
from app.domain.enums import TxKind, TxSource


class Transaction(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "transactions"

    user_id: Mapped[UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    category_id: Mapped[UUID | None] = mapped_column(
        ForeignKey("categories.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )

    amount_xof: Mapped[int] = mapped_column(Integer, nullable=False)
    kind: Mapped[TxKind] = mapped_column(
        PgEnum(TxKind, name="tx_kind", create_type=True),
        nullable=False,
    )
    source: Mapped[TxSource] = mapped_column(
        PgEnum(TxSource, name="tx_source", create_type=True),
        nullable=False,
        default=TxSource.MANUAL,
    )
    source_ref: Mapped[str | None] = mapped_column(String(120), nullable=True)

    description: Mapped[str | None] = mapped_column(String(200), nullable=True)
    counterparty: Mapped[str | None] = mapped_column(
        String(120), nullable=True
    )  # ex : "MTN MoMo", "Wave Sender Hash"

    occurred_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, index=True
    )

    __table_args__ = (
        CheckConstraint("amount_xof > 0", name="ck_transactions_amount_positive"),
        # Dedup ingestion : meme user + meme source_ref => meme transaction.
        Index(
            "ix_transactions_user_source_ref_unique",
            "user_id",
            "source_ref",
            unique=True,
            postgresql_where=source_ref.isnot(None),
        ),
        # Acces frequent : dernieres transactions d'un user.
        Index("ix_transactions_user_occurred_at", "user_id", "occurred_at"),
    )

    def __repr__(self) -> str:
        return (
            f"<Transaction id={self.id} user={self.user_id} "
            f"{self.kind.value} {self.amount_xof} XOF>"
        )
