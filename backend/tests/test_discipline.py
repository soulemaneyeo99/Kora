"""Tests utilitaires score de discipline (logique pure, sans DB)."""
import pytest

from app.services.discipline import _bucket, _grade


@pytest.mark.parametrize(
    "score,expected_grade",
    [
        (100, "A"),
        (85, "A"),
        (84, "B"),
        (70, "B"),
        (69, "C"),
        (55, "C"),
        (54, "D"),
        (40, "D"),
        (39, "E"),
        (0, "E"),
    ],
)
def test_grade_boundaries(score, expected_grade):
    assert _grade(score) == expected_grade


def test_bucket_picks_highest_matching_threshold():
    thresholds = [(0.30, 25), (0.15, 18), (0.05, 12), (0.0001, 6)]
    assert _bucket(0.50, thresholds) == 25
    assert _bucket(0.30, thresholds) == 25
    assert _bucket(0.20, thresholds) == 18
    assert _bucket(0.10, thresholds) == 12
    assert _bucket(0.01, thresholds) == 6
    assert _bucket(0.0, thresholds) == 0
    assert _bucket(-0.50, thresholds) == 0
