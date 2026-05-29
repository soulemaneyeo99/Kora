"""Modele User."""
from datetime import datetime

from sqlalchemy import Boolean, DateTime
from sqlalchemy import Enum as SAEnum
from sqlalchemy import String
from sqlalchemy.orm import Mapped, mapped_column

from app.domain.base import Base, TimestampMixin, UUIDPrimaryKeyMixin
from app.domain.enums import IncomeBracket, PrimaryGoal


class User(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "users"

    phone_e164: Mapped[str] = mapped_column(
        String(20), unique=True, index=True, nullable=False
    )
    display_name: Mapped[str | None] = mapped_column(String(80), nullable=True)
    locale: Mapped[str] = mapped_column(String(10), default="fr_CI", nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)

    last_login_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )

    # Onboarding F02 - profil progressif (CDC chapitre 4.1).
    income_bracket: Mapped[IncomeBracket | None] = mapped_column(
        SAEnum(IncomeBracket, name="income_bracket"), nullable=True
    )
    primary_goal: Mapped[PrimaryGoal | None] = mapped_column(
        SAEnum(PrimaryGoal, name="primary_goal"), nullable=True
    )

    @property
    def has_completed_onboarding(self) -> bool:
        """True une fois que display_name + bracket + goal sont remplis."""
        return bool(self.display_name and self.income_bracket and self.primary_goal)

    def __repr__(self) -> str:
        return f"<User id={self.id} phone={self.phone_e164}>"
