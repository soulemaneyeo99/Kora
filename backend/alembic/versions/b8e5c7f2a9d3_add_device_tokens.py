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
    device_platform = sa.Enum(*DEVICE_PLATFORM_VALUES, name="device_platform")
    device_platform.create(op.get_bind(), checkfirst=True)

    op.create_table(
        "device_tokens",
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("token", sa.String(length=512), nullable=False),
        sa.Column("platform", device_platform, nullable=False),
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
