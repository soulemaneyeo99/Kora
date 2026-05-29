"""Modele Category : catalogue de classification des transactions.

- Les categories "systeme" ont user_id=NULL et is_default=True : visibles par tous.
- Les categories utilisateur ont user_id non nul : visibles uniquement par leur proprietaire.
"""
from uuid import UUID

from sqlalchemy import Boolean, ForeignKey, Index, String
from sqlalchemy.dialects.postgresql import ENUM as PgEnum
from sqlalchemy.orm import Mapped, mapped_column

from app.domain.base import Base, TimestampMixin, UUIDPrimaryKeyMixin
from app.domain.enums import CategoryKind


class Category(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "categories"

    user_id: Mapped[UUID | None] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=True,
        index=True,
    )
    name: Mapped[str] = mapped_column(String(60), nullable=False)
    kind: Mapped[CategoryKind] = mapped_column(
        PgEnum(CategoryKind, name="category_kind", create_type=True),
        nullable=False,
    )
    # Icone : Material Symbol ou simple emoji. Pas de logique cote backend.
    icon: Mapped[str | None] = mapped_column(String(32), nullable=True)
    color: Mapped[str | None] = mapped_column(String(9), nullable=True)  # #RRGGBB[AA]
    is_default: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)

    __table_args__ = (
        # Un nom unique par utilisateur. Les categories systeme (user_id NULL)
        # ne sont pas contraintes par cette unicite a cause du NULL — c'est ok,
        # on les gere via le seed.
        Index(
            "ix_categories_user_name_unique",
            "user_id",
            "name",
            unique=True,
            postgresql_where=user_id.isnot(None),
        ),
    )

    def __repr__(self) -> str:
        return f"<Category id={self.id} name={self.name!r} kind={self.kind.value}>"
