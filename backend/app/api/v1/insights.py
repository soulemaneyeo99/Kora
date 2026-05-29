"""Endpoints insights : conseil du jour + badges (CDC F11, F19)."""
from fastapi import APIRouter

from app.deps import CurrentUserDep, DbDep
from app.schemas.insights import Badge, DailyTip
from app.services import insights as svc

router = APIRouter()


@router.get("/daily-tip", response_model=DailyTip)
async def get_daily_tip(user: CurrentUserDep) -> DailyTip:
    """Conseil du jour personnalise (selection deterministe user_id + date)."""
    return svc.get_tip_of_the_day(user.id)


@router.get("/badges", response_model=list[Badge])
async def get_badges(db: DbDep, user: CurrentUserDep) -> list[Badge]:
    """Etat des 8 badges Phase 1 (CDC F19)."""
    return await svc.compute_badges(db, user_id=user.id)
