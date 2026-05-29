"""Tests unitaires de normalisation E.164."""
import pytest

from app.core.phone import InvalidPhoneError, normalize_to_e164


def test_local_ci_number_normalized():
    assert normalize_to_e164("0712345678") == "+2250712345678"


def test_already_e164_passes_through():
    assert normalize_to_e164("+2250712345678") == "+2250712345678"


def test_with_spaces_normalized():
    assert normalize_to_e164("07 12 34 56 78") == "+2250712345678"


def test_invalid_raises():
    with pytest.raises(InvalidPhoneError):
        normalize_to_e164("123")
