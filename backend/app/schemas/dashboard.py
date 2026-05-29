"""Schemas du dashboard de coaching financier."""
from datetime import date
from uuid import UUID

from pydantic import BaseModel


class CategoryBreakdownItem(BaseModel):
    category_id: UUID | None
    category_name: str
    amount_xof: int
    pct_of_total: float


class PeriodTotals(BaseModel):
    income_xof: int
    expense_xof: int
    net_xof: int  # income - expense
    transactions_count: int


class DashboardSummary(BaseModel):
    period_start: date
    period_end: date

    current_period: PeriodTotals
    previous_period: PeriodTotals

    top_expense_categories: list[CategoryBreakdownItem]
    income_by_category: list[CategoryBreakdownItem]

    savings_total_xof: int  # somme des soldes de pots
    active_goals_count: int
    completed_goals_count: int


class DisciplineScore(BaseModel):
    """Score de discipline 0-100. Plus c'est haut, mieux c'est."""

    score: int  # 0..100
    grade: str  # A, B, C, D, E
    components: dict[str, int]  # detail des sous-scores
    period_start: date
    period_end: date
    insights: list[str]  # phrases courtes pour coacher l'utilisateur
