"""Endpoints insights : conseil du jour, badges, next action, forecast."""
from fastapi import APIRouter

from app.deps import CurrentUserDep, DbDep
from app.schemas.insights import Badge, DailyTip, EndOfMonthForecast, NextAction
from app.services import coaching as coaching_svc
from app.services import insights as svc

router = APIRouter()


@router.get("/daily-tip", response_model=DailyTip)
async def get_daily_tip(db: DbDep, user: CurrentUserDep) -> DailyTip:
    """Conseil du jour personnalise (selection conditionnee par les signaux
    financiers de l'utilisateur sur 30j, deterministe sur user + date)."""
    signals = await svc.compute_tip_signals(db, user_id=user.id)
    return svc.get_tip_of_the_day(user.id, signals=signals)


@router.get("/badges", response_model=list[Badge])
async def get_badges(db: DbDep, user: CurrentUserDep) -> list[Badge]:
    """Etat des 8 badges Phase 1 (CDC F19)."""
    return await svc.compute_badges(db, user_id=user.id)


@router.get("/next-action", response_model=NextAction)
async def get_next_action(db: DbDep, user: CurrentUserDep) -> NextAction:
    """Une action concrete recommandee pour le user, calculee a la volee."""
    return await coaching_svc.compute_next_action(db, user_id=user.id)


@router.get("/forecast", response_model=EndOfMonthForecast)
async def get_forecast(db: DbDep, user: CurrentUserDep) -> EndOfMonthForecast:
    """Prevision de fin de mois (extrapolation lineaire des depenses)."""
    return await coaching_svc.compute_forecast(db, user_id=user.id)
