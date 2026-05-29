"""Modele Goal : objectif d'epargne ou financier de l'utilisateur.

Un goal peut etre lie ou non a un SavingsPot. Lie : la progression est calculee
sur la base du solde du pot. Pas lie : la progression est manuellement ajustable
(via deposit/withdraw direct sur le goal).
"""
from datetime import date
from uuid import UUID

from sqlalchemy import CheckConstraint, Date, ForeignKey, Integer, String
from sqlalchemy.dialects.postgresql import ENUM as PgEnum
from sqlalchemy.orm import Mapped, mapped_column

from app.domain.base import Base, TimestampMixin, UUIDPrimaryKeyMixin
from app.domain.enums import GoalStatus


class Goal(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "goals"

    user_id: Mapped[UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    savings_pot_id: Mapped[UUID | None] = mapped_column(
        ForeignKey("savings_pots.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )

    title: Mapped[str] = mapped_column(String(120), nullable=False)
    description: Mapped[str | None] = mapped_column(String(500), nullable=True)
    target_amount_xof: Mapped[int] = mapped_column(Integer, nullable=False)
    current_amount_xof: Mapped[int] = mapped_column(
        Integer, nullable=False, default=0
    )

    target_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    status: Mapped[GoalStatus] = mapped_column(
        PgEnum(GoalStatus, name="goal_status", create_type=True),
        nullable=False,
        default=GoalStatus.ACTIVE,
    )

    __table_args__ = (
        CheckConstraint(
            "target_amount_xof > 0", name="ck_goals_target_positive"
        ),
        CheckConstraint(
            "current_amount_xof >= 0", name="ck_goals_current_non_negative"
        ),
    )

    @property
    def progress_pct(self) -> float:
        if self.target_amount_xof == 0:
            return 0.0
        return min(100.0, 100.0 * self.current_amount_xof / self.target_amount_xof)

    def __repr__(self) -> str:
        return f"<Goal id={self.id} title={self.title!r} {self.current_amount_xof}/{self.target_amount_xof}>"
