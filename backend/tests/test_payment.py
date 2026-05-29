"""Tests calcul commission."""
from app.services.payment import compute_commission_amount


def test_commission_round_up():
    # 80000 * 0.005 = 400.0 (exact)
    assert compute_commission_amount(80000, 0.005) == 400


def test_commission_round_up_with_fraction():
    # 33333 * 0.005 = 166.665 -> arrondi superieur = 167
    assert compute_commission_amount(33333, 0.005) == 167


def test_commission_zero_target():
    assert compute_commission_amount(0, 0.005) == 0


def test_commission_zero_rate():
    assert compute_commission_amount(100000, 0) == 0


def test_commission_smallest_target():
    # 1 XOF * 0.005 = 0.005 -> ceil = 1
    assert compute_commission_amount(1, 0.005) == 1


def test_commission_realistic_100k_goal():
    assert compute_commission_amount(100000, 0.005) == 500
