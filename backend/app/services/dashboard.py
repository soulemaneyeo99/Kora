"""Service dashboard : agregations sur transactions, pots et goals."""
from datetime import date, datetime, time, timezone
from uuid import UUID

from sqlalchemy import case, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.domain.category import Category
from app.domain.enums import GoalStatus, TxKind
from app.domain.goal import Goal
from app.domain.savings_pot import SavingsPot
from app.domain.transaction import Transaction
from app.schemas.dashboard import (
    CategoryBreakdownItem,
    DashboardSummary,
    PeriodTotals,
)


def _as_utc_range(start: date, end: date) -> tuple[datetime, datetime]:
    return (
        datetime.combine(start, time.min, tzinfo=timezone.utc),
        datetime.combine(end, time.max, tzinfo=timezone.utc),
    )


async def _totals(
    db: AsyncSession, *, user_id: UUID, start: datetime, end: datetime
) -> PeriodTotals:
    stmt = select(
        func.coalesce(
            func.sum(
                case((Transaction.kind == TxKind.INCOME, Transaction.amount_xof), else_=0)
            ),
            0,
        ).label("income"),
        func.coalesce(
            func.sum(
                case((Transaction.kind == TxKind.EXPENSE, Transaction.amount_xof), else_=0)
            ),
            0,
        ).label("expense"),
        func.count(Transaction.id).label("tx_count"),
    ).where(
        Transaction.user_id == user_id,
        Transaction.occurred_at >= start,
        Transaction.occurred_at <= end,
    )
    row = (await db.execute(stmt)).one()
    income, expense, count = int(row.income), int(row.expense), int(row.tx_count)
    return PeriodTotals(
        income_xof=income,
        expense_xof=expense,
        net_xof=income - expense,
        transactions_count=count,
    )


async def _breakdown_by_category(
    db: AsyncSession,
    *,
    user_id: UUID,
    start: datetime,
    end: datetime,
    kind: TxKind,
    limit: int = 5,
) -> list[CategoryBreakdownItem]:
    stmt = (
        select(
            Transaction.category_id,
            func.coalesce(Category.name, "Sans categorie").label("name"),
            func.sum(Transaction.amount_xof).label("total"),
        )
        .join(Category, Category.id == Transaction.category_id, isouter=True)
        .where(
            Transaction.user_id == user_id,
            Transaction.kind == kind,
            Transaction.occurred_at >= start,
            Transaction.occurred_at <= end,
        )
        .group_by(Transaction.category_id, Category.name)
        .order_by(func.sum(Transaction.amount_xof).desc())
        .limit(limit)
    )
    rows = (await db.execute(stmt)).all()
    grand_total = sum(int(r.total) for r in rows) or 1
    return [
        CategoryBreakdownItem(
            category_id=r.category_id,
            category_name=str(r.name),
            amount_xof=int(r.total),
            pct_of_total=round(100.0 * int(r.total) / grand_total, 1),
        )
        for r in rows
    ]


async def _savings_total(db: AsyncSession, *, user_id: UUID) -> int:
    stmt = select(func.coalesce(func.sum(SavingsPot.balance_xof), 0)).where(
        SavingsPot.user_id == user_id
    )
    return int((await db.execute(stmt)).scalar_one())


async def _goals_counts(
    db: AsyncSession, *, user_id: UUID
) -> tuple[int, int]:
    stmt = select(Goal.status, func.count()).where(Goal.user_id == user_id).group_by(
        Goal.status
    )
    rows = (await db.execute(stmt)).all()
    counts: dict[str, int] = {}
    for status_val, c in rows:
        # status_val peut etre un GoalStatus (Enum) ou un str selon driver/version.
        key = status_val.value if isinstance(status_val, GoalStatus) else str(status_val).lower()
        counts[key] = int(c)
    return (
        counts.get(GoalStatus.ACTIVE.value, 0),
        counts.get(GoalStatus.COMPLETED.value, 0),
    )


async def build_summary(
    db: AsyncSession,
    *,
    user_id: UUID,
    period_start: date,
    period_end: date,
) -> DashboardSummary:
    start_dt, end_dt = _as_utc_range(period_start, period_end)
    period_days = max((period_end - period_start).days + 1, 1)
    prev_end = period_start
    prev_start_date = date.fromordinal(period_start.toordinal() - period_days)
    prev_start_dt, prev_end_dt = _as_utc_range(prev_start_date, prev_end)

    current = await _totals(db, user_id=user_id, start=start_dt, end=end_dt)
    previous = await _totals(db, user_id=user_id, start=prev_start_dt, end=prev_end_dt)
    top_expenses = await _breakdown_by_category(
        db, user_id=user_id, start=start_dt, end=end_dt, kind=TxKind.EXPENSE
    )
    incomes = await _breakdown_by_category(
        db, user_id=user_id, start=start_dt, end=end_dt, kind=TxKind.INCOME
    )
    savings = await _savings_total(db, user_id=user_id)
    active_goals, completed_goals = await _goals_counts(db, user_id=user_id)

    return DashboardSummary(
        period_start=period_start,
        period_end=period_end,
        current_period=current,
        previous_period=previous,
        top_expense_categories=top_expenses,
        income_by_category=incomes,
        savings_total_xof=savings,
        active_goals_count=active_goals,
        completed_goals_count=completed_goals,
    )
