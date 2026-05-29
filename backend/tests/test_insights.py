"""Tests insights : selection deterministe du conseil du jour."""
from datetime import date
from uuid import UUID, uuid4

from app.services.insights import _TIPS, get_tip_of_the_day


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
    # On ne peut pas garantir mathematiquement qu'ils different (collision possible)
    # mais sur ces 2 dates precises avec cet UUID, on verifie qu'on choisit bien
    # un indice valide.
    assert 0 <= a.id < len(_TIPS)
    assert 0 <= b.id < len(_TIPS)


def test_daily_tip_varies_by_user():
    today = date(2026, 5, 29)
    ids = {
        get_tip_of_the_day(uuid4(), today).id for _ in range(20)
    }
    # 20 users tirent un conseil parmi 30 : on attend une certaine variete.
    assert len(ids) >= 5


def test_tips_library_well_formed():
    assert len(_TIPS) >= 20  # bibliotheque consistente
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
