"""Tests de la selection du push provider + LoggingPushProvider.

Le FcmPushProvider n'est pas teste en HTTP reel (il faudrait un service
account valide). On se contente de verifier le fallback et le log provider.
"""
import pytest

from app.config import Settings
from app.services.push_provider import (
    LoggingPushProvider,
    PushMessage,
    get_push_provider,
)


def _settings(fcm_json: str = "") -> Settings:
    return Settings(
        database_url="postgresql+asyncpg://u:p@h/db",
        redis_url="redis://h:6379",
        jwt_secret="x" * 32,
        fcm_service_account_json=fcm_json,
    )  # type: ignore[call-arg]


def test_get_push_provider_defaults_to_logging():
    provider = get_push_provider(_settings())
    assert isinstance(provider, LoggingPushProvider)
    assert provider.name == "log"


def test_get_push_provider_falls_back_on_invalid_json():
    provider = get_push_provider(_settings(fcm_json="not a json"))
    assert isinstance(provider, LoggingPushProvider)


def test_get_push_provider_falls_back_on_missing_keys():
    provider = get_push_provider(
        _settings(fcm_json='{"project_id": "x"}')
    )
    assert isinstance(provider, LoggingPushProvider)


async def test_logging_provider_send_returns_all_sent():
    provider = LoggingPushProvider()
    msg = PushMessage(title="Hi", body="hello", data={"k": "v"})
    result = await provider.send(tokens=["t1", "t2", "t3"], message=msg)
    assert result.sent == 3
    assert result.failed == 0
    assert result.invalid_tokens == []


async def test_logging_provider_send_empty_tokens():
    provider = LoggingPushProvider()
    result = await provider.send(
        tokens=[], message=PushMessage(title="x", body="y")
    )
    assert result.sent == 0
    assert result.failed == 0


@pytest.mark.parametrize(
    "raw",
    ["", "   ", "\n"],
)
def test_get_push_provider_blank_str_uses_logging(raw: str):
    provider = get_push_provider(_settings(fcm_json=raw))
    assert isinstance(provider, LoggingPushProvider)
