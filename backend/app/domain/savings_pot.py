"""Modele SavingsPot : enveloppe virtuelle dans laquelle l'utilisateur met de cote.

Note : KORA n'est PAS depositaire d'argent. Le solde represente une intention,
pas une garantie de fonds. Les mouvements sont enregistres mais l'argent reste
chez l'utilisateur (sur Mobile Money, en cash, etc.).
"""
from uuid import UUID

from sqlalchemy import CheckConstraint, ForeignKey, Index, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from app.domain.base import Base, TimestampMixin, UUIDPrimaryKeyMixin


class SavingsPot(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "savings_pots"

    user_id: Mapped[UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    name: Mapped[str] = mapped_column(String(80), nullable=False)
    balance_xof: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    icon: Mapped[str | None] = mapped_column(String(32), nullable=True)
    color: Mapped[str | None] = mapped_column(String(9), nullable=True)

    __table_args__ = (
        CheckConstraint(
            "balance_xof >= 0", name="ck_savings_pots_balance_non_negative"
        ),
        Index("ix_savings_pots_user_name_unique", "user_id", "name", unique=True),
    )

    def __repr__(self) -> str:
        return f"<SavingsPot id={self.id} name={self.name!r} balance={self.balance_xof}>"
