"""Tests du mode demo client (AUTH_DEMO_MODE=true).

Le mode demo doit :
  - retourner DEMO_CODE sans toucher a Redis ni au provider SMS
  - accepter n'importe quel code 4-6 chiffres
  - refuser les codes non-numeriques
  - exposer demo_mode=True sur le service
"""
import pytest

from app.services.otp import DEMO_CODE, OtpInvalid, OtpService


class _BoomRedis:
    """Redis factice : leve si on l'appelle. Garantit qu'on bypass Redis."""

    async def set(self, *a, **kw):
        raise AssertionError("Redis ne doit jamais etre appele en demo")

    async def get(self, *a, **kw):
        raise AssertionError("Redis ne doit jamais etre appele en demo")

    async def delete(self, *a, **kw):
        raise AssertionError("Redis ne doit jamais etre appele en demo")

    async def ttl(self, *a, **kw):
        raise AssertionError("Redis ne doit jamais etre appele en demo")


class _BoomSms:
    """SMS factice : leve si on l'appelle. Garantit qu'on n'envoie pas de SMS."""

    async def send(self, *a, **kw):
        raise AssertionError("SMS ne doit jamais etre envoye en demo")


def _service() -> OtpService:
    return OtpService(
        redis_client=_BoomRedis(),  # type: ignore[arg-type]
        sms_provider=_BoomSms(),  # type: ignore[arg-type]
        debug_expose=False,
        demo_mode=True,
    )


async def test_demo_issue_returns_demo_code_without_redis_or_sms():
    svc = _service()
    result = await svc.issue(phone_e164="+2250712345678")
    assert result.debug_code == DEMO_CODE
    assert result.expires_in_seconds > 0


@pytest.mark.parametrize("code", ["0000", "1234", "000000", "999999"])
async def test_demo_verify_accepts_any_digit_code(code: str):
    svc = _service()
    await svc.verify(phone_e164="+2250712345678", code=code)


@pytest.mark.parametrize("code", ["abcd", "12ab", ""])
async def test_demo_verify_rejects_non_digit(code: str):
    svc = _service()
    with pytest.raises(OtpInvalid):
        await svc.verify(phone_e164="+2250712345678", code=code)


def test_demo_mode_property_exposes_flag():
    assert _service().demo_mode is True
