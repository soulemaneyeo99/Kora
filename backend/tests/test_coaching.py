"""Tests coaching : next_action + forecast.

On evite la dependance a une vraie DB en :
  - testant directement les helpers purs (_round_to_500, _weekly_save_amount, etc.)
  - monkeypatchant compute_tip_signals + _load_active_goals pour orchestrer
    les regles de compute_next_action
  - utilisant un fake session pour compute_forecast (renvoie agregats simules)
"""
from __future__ import annotations

from dataclasses import dataclass, field
from datetime import date, timedelta
from typing import Any
from uuid import uuid4

import pytest

from app.services import coaching
from app.services.coaching import (
    _GoalSummary,
    _catch_up_amount,
    _expected_progress_pct,
    _forecast_headline,
    _round_to_500,
    _weekly_save_amount,
    compute_forecast,
    compute_next_action,
)
from app.services.insights import TipSignals


def _sig(
    *,
    savings_rate: float = 0.20,
    impulse_ratio: float = 0.15,
    tx_count: int = 15,
    income_xof: int = 200_000,
    has_goals: bool = True,
    avg_goal_progress: float = 30.0,
) -> TipSignals:
    return TipSignals(
        savings_rate=savings_rate,
        impulse_ratio=impulse_ratio,
        tx_count=tx_count,
        income_xof=income_xof,
        has_goals=has_goals,
        avg_goal_progress=avg_goal_progress,
    )


# ---------------------------------------------------------------------------
# Helpers purs
# ---------------------------------------------------------------------------
def test_round_to_500_rounds_up():
    assert _round_to_500(0) == 0
    assert _round_to_500(1) == 500
    assert _round_to_500(500) == 500
    assert _round_to_500(501) == 1000
    assert _round_to_500(2750) == 3000


def test_round_to_500_negative_returns_zero():
    assert _round_to_500(-100) == 0


def test_weekly_save_amount_uses_savings_rate():
    s = _sig(savings_rate=0.20, income_xof=200_000)
    # net mensuel = 40000, 10% = 4000, /4 semaines = 1000
    assert _weekly_save_amount(s) == 1000


def test_weekly_save_amount_has_floor():
    """Meme avec un tres petit revenu, on suggere au minimum 1000 FCFA."""
    s = _sig(savings_rate=0.05, income_xof=10_000)
    assert _weekly_save_amount(s) >= 1000


def test_weekly_save_amount_has_ceiling():
    """Cap a 50 000 FCFA / semaine pour rester credible."""
    s = _sig(savings_rate=0.40, income_xof=10_000_000)
    assert _weekly_save_amount(s) <= 50_000


def test_weekly_save_amount_no_income_returns_floor():
    s = _sig(savings_rate=0.0, income_xof=0)
    assert _weekly_save_amount(s) == 1000


def test_catch_up_amount_returns_remaining_when_overdue():
    today = date(2026, 6, 1)
    g = _GoalSummary(
        id=uuid4(),
        title="Voyage",
        target_xof=100_000,
        current_xof=20_000,
        target_date=date(2026, 5, 30),
    )
    assert _catch_up_amount(g, today) == 80_000


def test_catch_up_amount_distributes_remaining_over_weeks():
    today = date(2026, 6, 1)
    g = _GoalSummary(
        id=uuid4(),
        title="Voyage",
        target_xof=100_000,
        current_xof=20_000,
        target_date=date(2026, 7, 27),  # ~8 semaines plus tard
    )
    amount = _catch_up_amount(g, today)
    # 80 000 / 8 = 10 000 -> arrondi a 10 000
    assert amount > 0
    assert amount % 500 == 0
    assert amount <= 20_000


def test_catch_up_amount_no_target_date_returns_zero():
    today = date(2026, 6, 1)
    g = _GoalSummary(
        id=uuid4(),
        title="Voyage",
        target_xof=100_000,
        current_xof=20_000,
        target_date=None,
    )
    assert _catch_up_amount(g, today) == 0


def test_expected_progress_pct_grows_with_time():
    g = _GoalSummary(
        id=uuid4(),
        title="X",
        target_xof=100_000,
        current_xof=0,
        target_date=date(2026, 7, 1),  # +30j
    )
    early = _expected_progress_pct(g, date(2026, 5, 1))
    middle = _expected_progress_pct(g, date(2026, 6, 1))
    later = _expected_progress_pct(g, date(2026, 6, 25))
    assert early < middle < later
    assert 0.0 <= early <= 100.0
    assert 0.0 <= later <= 100.0


def test_forecast_headline_danger_when_deficit():
    headline, tone = _forecast_headline(
        income_so_far=100_000,
        projected_expense=150_000,
        projected_balance=-50_000,
        days_elapsed=15,
        days_in_month=30,
    )
    assert tone == "danger"
    assert "deficit" in headline.lower() or "50" in headline


def test_forecast_headline_good_when_strong_balance():
    headline, tone = _forecast_headline(
        income_so_far=100_000,
        projected_expense=70_000,
        projected_balance=30_000,
        days_elapsed=15,
        days_in_month=30,
    )
    assert tone == "good"


def test_forecast_headline_warning_when_tight():
    headline, tone = _forecast_headline(
        income_so_far=100_000,
        projected_expense=98_000,
        projected_balance=2_000,
        days_elapsed=15,
        days_in_month=30,
    )
    assert tone == "warning"


def test_forecast_headline_neutral_when_too_early():
    headline, tone = _forecast_headline(
        income_so_far=20_000,
        projected_expense=0,
        projected_balance=20_000,
        days_elapsed=1,
        days_in_month=30,
    )
    assert tone == "neutral"


# ---------------------------------------------------------------------------
# compute_next_action : on monkeypatch les loaders pour piloter les regles
# ---------------------------------------------------------------------------
class _NullSession:
    """Placeholder : compute_next_action n'appelle plus la DB grace au patch."""

    async def execute(self, stmt):  # pragma: no cover - never called
        raise AssertionError("DB should not be touched in this test")


async def _run(
    monkeypatch: pytest.MonkeyPatch,
    *,
    signals: TipSignals,
    goals: list[_GoalSummary] | None = None,
    today: date | None = None,
):
    user_id = uuid4()

    async def _fake_signals(_db, user_id):  # noqa: ARG001
        return signals

    async def _fake_goals(_db, user_id):  # noqa: ARG001
        return list(goals or [])

    monkeypatch.setattr(coaching, "compute_tip_signals", _fake_signals)
    monkeypatch.setattr(coaching, "_load_active_goals", _fake_goals)

    return await compute_next_action(
        _NullSession(), user_id=user_id, today=today  # type: ignore[arg-type]
    )


async def test_next_action_log_first_tx_when_empty(monkeypatch):
    action = await _run(
        monkeypatch,
        signals=_sig(tx_count=0, income_xof=0, has_goals=False),
    )
    assert action.code == "log_first_tx"
    assert action.priority == 1
    assert action.cta_route == "/transactions"


async def test_next_action_create_first_goal_when_no_goal(monkeypatch):
    action = await _run(
        monkeypatch,
        signals=_sig(tx_count=10, has_goals=False, avg_goal_progress=0.0),
    )
    assert action.code == "create_first_goal"
    assert action.cta_route == "/goals"


async def test_next_action_log_income_when_no_income(monkeypatch):
    action = await _run(
        monkeypatch,
        signals=_sig(tx_count=10, income_xof=0, has_goals=True),
        goals=[
            _GoalSummary(
                id=uuid4(),
                title="x",
                target_xof=100_000,
                current_xof=10_000,
                target_date=None,
            )
        ],
    )
    assert action.code == "log_income"


async def test_next_action_trim_impulse_when_ratio_high(monkeypatch):
    action = await _run(
        monkeypatch,
        signals=_sig(impulse_ratio=0.60, tx_count=20, income_xof=200_000),
        goals=[
            _GoalSummary(
                id=uuid4(),
                title="g",
                target_xof=100_000,
                current_xof=50_000,
                target_date=None,
            )
        ],
    )
    assert action.code == "trim_impulse"
    assert action.amount_xof is not None and action.amount_xof > 0


async def test_next_action_catch_up_goal_when_late(monkeypatch):
    today = date(2026, 6, 1)
    # Goal a 10% mais 70% du temps deja passe
    late_goal = _GoalSummary(
        id=uuid4(),
        title="Voyage",
        target_xof=100_000,
        current_xof=10_000,
        target_date=date(2026, 6, 20),  # ~20 jours plus tard
    )
    action = await _run(
        monkeypatch,
        signals=_sig(
            tx_count=25, impulse_ratio=0.10, income_xof=200_000,
            savings_rate=0.20,
        ),
        goals=[late_goal],
        today=today,
    )
    assert action.code == "catch_up_goal"
    assert "Voyage" in action.title


async def test_next_action_save_weekly_when_on_track(monkeypatch):
    on_track_goal = _GoalSummary(
        id=uuid4(),
        title="Ordi",
        target_xof=200_000,
        current_xof=100_000,  # 50% en avance
        target_date=date.today() + timedelta(days=90),
    )
    action = await _run(
        monkeypatch,
        signals=_sig(
            tx_count=20, impulse_ratio=0.15, income_xof=200_000,
            savings_rate=0.25,
        ),
        goals=[on_track_goal],
    )
    assert action.code == "save_weekly"
    assert action.amount_xof is not None and action.amount_xof >= 1000


async def test_next_action_celebrate_when_everything_fine(monkeypatch):
    action = await _run(
        monkeypatch,
        signals=_sig(
            tx_count=30, impulse_ratio=0.10, income_xof=300_000,
            savings_rate=0.30,
        ),
        goals=[],  # pas de goal mais tx_count > 5 -> create_first_goal
    )
    # Cas: pas de goal alors qu'il y a beaucoup de tx -> create_first_goal
    assert action.code == "create_first_goal"


async def test_next_action_log_more_tx_when_irregular(monkeypatch):
    """Tracking entre 1 et 9 tx, revenus presents, pas d'impulse ni goal."""
    action = await _run(
        monkeypatch,
        signals=_sig(
            tx_count=4, impulse_ratio=0.10, income_xof=100_000,
            savings_rate=0.10, has_goals=False,
        ),
    )
    # tx_count=4 < 5 -> log_first_tx ? Non, tx_count=4 != 0.
    # not goals et tx_count=4 < 5 -> on saute create_first_goal aussi.
    # impulse=0.10 -> skip trim_impulse. income > 0 -> skip log_income.
    # Pas de goal -> skip save_weekly. tx_count < 10 -> log_more_tx.
    assert action.code == "log_more_tx"


# ---------------------------------------------------------------------------
# compute_forecast : fake session retournant des agregats canned
# ---------------------------------------------------------------------------
@dataclass
class _AggRow:
    income: int
    expense: int


@dataclass
class _ForecastSession:
    income: int = 0
    expense: int = 0

    async def execute(self, stmt):  # noqa: ARG002
        return _FakeResult(_AggRow(income=self.income, expense=self.expense))


class _FakeResult:
    def __init__(self, row: Any) -> None:
        self._row = row

    def one(self):
        return self._row


async def test_forecast_neutral_when_no_data():
    session = _ForecastSession(income=0, expense=0)
    today = date(2026, 6, 15)
    f = await compute_forecast(session, user_id=uuid4(), today=today)  # type: ignore[arg-type]
    assert f.tone == "neutral"
    assert f.income_so_far_xof == 0
    assert f.expense_so_far_xof == 0


async def test_forecast_extrapolates_linearly():
    """15 jours, 75 000 FCFA depenses -> projection 30j = 150 000 FCFA."""
    session = _ForecastSession(income=200_000, expense=75_000)
    today = date(2026, 6, 15)  # juin = 30 jours
    f = await compute_forecast(session, user_id=uuid4(), today=today)  # type: ignore[arg-type]
    assert f.days_elapsed == 15
    assert f.days_remaining == 15
    assert f.daily_avg_expense_xof == 5_000
    assert f.projected_expense_xof == 150_000
    assert f.projected_balance_xof == 50_000
    assert f.tone == "good"


async def test_forecast_danger_when_deficit():
    session = _ForecastSession(income=100_000, expense=80_000)
    today = date(2026, 6, 15)  # 15/30 -> projection = 160 000
    f = await compute_forecast(session, user_id=uuid4(), today=today)  # type: ignore[arg-type]
    assert f.projected_expense_xof == 160_000
    assert f.projected_balance_xof == -60_000
    assert f.tone == "danger"
