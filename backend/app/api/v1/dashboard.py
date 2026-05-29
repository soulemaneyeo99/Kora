"""Endpoints dashboard : resume + score de discipline."""
from datetime import date, timedelta

from fastapi import APIRouter, Query

from app.deps import CurrentUserDep, DbDep
from app.schemas.dashboard import DashboardSummary, DisciplineScore
from app.services import dashboard as dashboard_svc
from app.services import discipline as discipline_svc

router = APIRouter()


def _default_period() -> tuple[date, date]:
    today = date.today()
    return today.replace(day=1), today


@router.get("/summary", response_model=DashboardSummary)
async def get_summary(
    db: DbDep,
    user: CurrentUserDep,
    period_start: date | None = Query(default=None),
    period_end: date | None = Query(default=None),
) -> DashboardSummary:
    default_start, default_end = _default_period()
    start = period_start or default_start
    end = period_end or default_end
    return await dashboard_svc.build_summary(
        db, user_id=user.id, period_start=start, period_end=end
    )


@router.get("/score", response_model=DisciplineScore)
async def get_score(
    db: DbDep,
    user: CurrentUserDep,
    period_start: date | None = Query(default=None),
    period_end: date | None = Query(default=None),
) -> DisciplineScore:
    # Pour le score, defaut = 30 derniers jours roulants.
    end = period_end or date.today()
    start = period_start or (end - timedelta(days=30))
    return await discipline_svc.compute_score(
        db, user_id=user.id, period_start=start, period_end=end
    )
