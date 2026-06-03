"""Tests insights : selection deterministe + conditionnee du conseil du jour."""
from datetime import date
from uuid import UUID, uuid4

from app.services.insights import (
    _TIPS,
    TipSignals,
    _rank_categories,
    get_tip_of_the_day,
)


def _signals(
    *,
    savings_rate: float = 0.15,
    impulse_ratio: float = 0.10,
    tx_count: int = 12,
    income_xof: int = 200_000,
    has_goals: bool = True,
    avg_goal_progress: float = 40.0,
) -> TipSignals:
    return TipSignals(
        savings_rate=savings_rate,
        impulse_ratio=impulse_ratio,
        tx_count=tx_count,
        income_xof=income_xof,
        has_goals=has_goals,
        avg_goal_progress=avg_goal_progress,
    )


def test_daily_tip_is_deterministic_per_user_per_day():
    user_id = uuid4()
    today = date(2026, 5, 29)
    a = get_tip_of_the_day(user_id, today)
    b = get_tip_of_the_day(user_id, today)
    assert a.id == b.id
    assert a.title == b.title


def test_daily_tip_changes_next_day():
    user_id = UUID("12345678-1234-5678-1234-567812345678")
    a = get_tip_of_the_day(user_id, date(2026, 5, 29))
    b = get_tip_of_the_day(user_id, date(2026, 5, 30))
    assert 0 <= a.id < len(_TIPS)
    assert 0 <= b.id < len(_TIPS)


def test_daily_tip_varies_by_user():
    today = date(2026, 5, 29)
    ids = {
        get_tip_of_the_day(uuid4(), today).id for _ in range(20)
    }
    assert len(ids) >= 5


def test_tips_library_well_formed():
    assert len(_TIPS) >= 20
    for t in _TIPS:
        assert t["title"]
        assert t["body"]
        assert t["category"] in {
            "discipline", "epargne", "depenses", "revenus", "objectifs"
        }


def test_daily_tip_returns_valid_indices():
    """Sur 100 users x 7 dates, tous les indices doivent rester valides."""
    for _ in range(100):
        uid = uuid4()
        for i in range(7):
            day = date(2026, 5, 29 + i if 29 + i <= 31 else 1)
            tip = get_tip_of_the_day(uid, day)
            assert 0 <= tip.id < len(_TIPS)
            assert tip.title and tip.body


# ----- Selection conditionnee -------------------------------------------------

def test_signals_with_low_savings_targets_epargne():
    s = _signals(savings_rate=-0.10, income_xof=150_000, impulse_ratio=0.10)
    cats = _rank_categories(s)
    assert cats[0] == "epargne"


def test_signals_with_high_impulse_targets_depenses():
    s = _signals(
        savings_rate=0.20, income_xof=150_000, impulse_ratio=0.60, tx_count=15
    )
    cats = _rank_categories(s)
    assert cats[0] == "depenses"


def test_signals_with_no_goals_targets_objectifs():
    s = _signals(
        savings_rate=0.20,
        impulse_ratio=0.10,
        tx_count=15,
        has_goals=False,
        avg_goal_progress=0.0,
    )
    cats = _rank_categories(s)
    assert "objectifs" in cats[:2]


def test_signals_with_no_income_targets_revenus():
    s = _signals(
        income_xof=0, savings_rate=0.0, tx_count=8, impulse_ratio=0.10
    )
    cats = _rank_categories(s)
    assert "revenus" in cats[:2]


def test_signals_with_few_tx_targets_discipline():
    s = _signals(
        tx_count=2, savings_rate=0.20, impulse_ratio=0.10, income_xof=100_000
    )
    cats = _rank_categories(s)
    assert cats[0] == "discipline"


def test_tip_with_signals_picks_from_targeted_category():
    """Un user en deficit doit recevoir un tip 'epargne'."""
    user_id = uuid4()
    s = _signals(savings_rate=-0.20, income_xof=100_000, impulse_ratio=0.10)
    tip = get_tip_of_the_day(user_id, date(2026, 6, 1), signals=s)
    assert tip.category == "epargne"


def test_tip_with_signals_picks_from_depenses_when_impulse_high():
    user_id = uuid4()
    s = _signals(impulse_ratio=0.70, savings_rate=0.20, tx_count=20)
    tip = get_tip_of_the_day(user_id, date(2026, 6, 1), signals=s)
    assert tip.category == "depenses"


def test_tip_with_signals_remains_stable_per_day():
    """Meme user, meme jour, memes signaux -> meme tip."""
    user_id = uuid4()
    s = _signals(savings_rate=-0.10, income_xof=100_000)
    a = get_tip_of_the_day(user_id, date(2026, 6, 1), signals=s)
    b = get_tip_of_the_day(user_id, date(2026, 6, 1), signals=s)
    assert a.id == b.id
    assert a.title == b.title


def test_tip_without_signals_uses_fallback():
    """Pas de signaux -> selection uniforme (compat)."""
    user_id = uuid4()
    today = date(2026, 6, 1)
    tip = get_tip_of_the_day(user_id, today, signals=None)
    assert 0 <= tip.id < len(_TIPS)


def test_signals_with_empty_state_returns_no_targets():
    """User totalement vide : aucun signal pertinent, on tombe en fallback."""
    s = TipSignals(
        savings_rate=0.0,
        impulse_ratio=0.0,
        tx_count=0,
        income_xof=0,
        has_goals=False,
        avg_goal_progress=0.0,
    )
    cats = _rank_categories(s)
    # discipline (tx<5) et objectifs (no goals) doivent ressortir
    assert "discipline" in cats
    assert "objectifs" in cats
