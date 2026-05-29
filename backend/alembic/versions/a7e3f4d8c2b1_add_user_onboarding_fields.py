"""add user onboarding fields (F02)

Revision ID: a7e3f4d8c2b1
Revises: 5b7971de8f55
Create Date: 2026-05-29 12:00:00.000000
"""

from collections.abc import Sequence
from typing import Union

import sqlalchemy as sa
from alembic import op

revision: str = "a7e3f4d8c2b1"
down_revision: Union[str, None] = "5b7971de8f55"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


INCOME_BRACKET_VALUES = ("under_80k", "k80_150", "k150_300", "over_300k")
PRIMARY_GOAL_VALUES = ("save", "pay_bills", "buy", "business")


def upgrade() -> None:
    income_bracket = sa.Enum(*INCOME_BRACKET_VALUES, name="income_bracket")
    primary_goal = sa.Enum(*PRIMARY_GOAL_VALUES, name="primary_goal")
    income_bracket.create(op.get_bind(), checkfirst=True)
    primary_goal.create(op.get_bind(), checkfirst=True)

    op.add_column(
        "users",
        sa.Column("income_bracket", income_bracket, nullable=True),
    )
    op.add_column(
        "users",
        sa.Column("primary_goal", primary_goal, nullable=True),
    )


def downgrade() -> None:
    op.drop_column("users", "primary_goal")
    op.drop_column("users", "income_bracket")
    sa.Enum(name="primary_goal").drop(op.get_bind(), checkfirst=True)
    sa.Enum(name="income_bracket").drop(op.get_bind(), checkfirst=True)
