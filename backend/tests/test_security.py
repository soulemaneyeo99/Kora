"""Tests unitaires : hash OTP + JWT round-trip."""
from uuid import uuid4

from app.core.security import (
    create_access_token,
    decode_access_token,
    hash_otp,
    verify_otp,
)


def test_otp_hash_verify_ok():
    hashed = hash_otp("123456")
    assert verify_otp("123456", hashed) is True
    assert verify_otp("000000", hashed) is False


def test_jwt_roundtrip():
    user_id = uuid4()
    token, _ = create_access_token(user_id)
    decoded = decode_access_token(token)
    assert decoded == user_id
