"""add device tokens for push notifications

Revision ID: b8e5c7f2a9d3
Revises: a7e3f4d8c2b1
Create Date: 2026-05-31 09:00:00.000000
"""

from collections.abc import Sequence
from typing import Union

import sqlalchemy as sa
from alembic import op

revision: str = "b8e5c7f2a9d3"
down_revision: Union[str, None] = "a7e3f4d8c2b1"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


DEVICE_PLATFORM_VALUES = ("android", "ios", "web")


def upgrade() -> None:
    # 1) Cree le type enum si absent. checkfirst evite l'erreur si un deploy
    #    precedent l'a deja cree (cas Render redeploy avec migration partielle).
    bind = op.get_bind()
    sa.Enum(*DEVICE_PLATFORM_VALUES, name="device_platform").create(
        bind, checkfirst=True
    )

    # 2) Cree la table en referençant l'enum SANS retenter le CREATE TYPE.
    #    Sans create_type=False, SQLAlchemy relance un CREATE TYPE et explose
    #    sur DuplicateObjectError.
    platform_col = sa.Enum(
        *DEVICE_PLATFORM_VALUES, name="device_platform", create_type=False
    )
    op.create_table(
        "device_tokens",
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("token", sa.String(length=512), nullable=False),
        sa.Column("platform", platform_col, nullable=False),
        sa.Column("label", sa.String(length=80), nullable=True),
        sa.Column("locale", sa.String(length=10), nullable=False),
        sa.Column("is_active", sa.Boolean(), nullable=False),
        sa.Column("last_used_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        op.f("ix_device_tokens_user_id"),
        "device_tokens",
        ["user_id"],
        unique=False,
    )
    op.create_index(
        "ix_device_tokens_user_token_unique",
        "device_tokens",
        ["user_id", "token"],
        unique=True,
    )


def downgrade() -> None:
    op.drop_index(
        "ix_device_tokens_user_token_unique", table_name="device_tokens"
    )
    op.drop_index(op.f("ix_device_tokens_user_id"), table_name="device_tokens")
    op.drop_table("device_tokens")
    sa.Enum(name="device_platform").drop(op.get_bind(), checkfirst=True)
