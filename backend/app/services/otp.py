"""Service OTP : emission, verification, throttling.

Stockage Redis :
  otp:<phone>          -> JSON {hash, attempts, issued_at}   TTL = OTP_TTL_SECONDS
  otp:throttle:<phone> -> sentinel "1"                       TTL = THROTTLE_SECONDS

Securite :
  - OTP 6 chiffres genere via `secrets.randbelow` (non biaise)
  - Hash bcrypt en Redis (jamais en clair)
  - Max MAX_ATTEMPTS echecs -> OTP invalide
  - Throttle 1 requete / 60s par phone (anti-bombing SMS)
"""
from __future__ import annotations

import json
import logging
import secrets
from dataclasses import dataclass
from datetime import datetime, timezone

import redis.asyncio as redis

from app.core.security import hash_otp, verify_otp
from app.services.sms_provider import SmsProvider

logger = logging.getLogger(__name__)

OTP_TTL_SECONDS = 300  # 5 min
THROTTLE_SECONDS = 60
MAX_ATTEMPTS = 3
CODE_LENGTH = 6

# Code retourne en mode demo client. Affiche "000000" et accepte tout code
# 4-6 chiffres. Permet une demo sans SMS ni Redis.
DEMO_CODE = "000000"


class OtpError(Exception):
    """Erreur metier OTP."""


class OtpThrottled(OtpError):
    pass


class OtpNotFound(OtpError):
    pass


class OtpInvalid(OtpError):
    pass


class OtpExhausted(OtpError):
    pass


@dataclass
class OtpIssueResult:
    expires_in_seconds: int
    debug_code: str | None


def _otp_key(phone: str) -> str:
    return f"otp:{phone}"


def _throttle_key(phone: str) -> str:
    return f"otp:throttle:{phone}"


def _generate_code() -> str:
    """6 chiffres, zeros initiaux possibles, non biaise."""
    return f"{secrets.randbelow(10**CODE_LENGTH):0{CODE_LENGTH}d}"


class OtpService:
    def __init__(
        self,
        *,
        redis_client: redis.Redis,
        sms_provider: SmsProvider,
        debug_expose: bool = False,
        demo_mode: bool = False,
    ) -> None:
        self._redis = redis_client
        self._sms = sms_provider
        self._debug = debug_expose
        self._demo_mode = demo_mode

    @property
    def demo_mode(self) -> bool:
        return self._demo_mode

    async def issue(self, *, phone_e164: str) -> OtpIssueResult:
        if self._demo_mode:
            # Demo client : pas de Redis, pas de SMS, code public fixe.
            return OtpIssueResult(
                expires_in_seconds=OTP_TTL_SECONDS,
                debug_code=DEMO_CODE,
            )

        # Throttle SETNX : echoue si une demande recente existe deja
        was_set = await self._redis.set(
            _throttle_key(phone_e164), "1", nx=True, ex=THROTTLE_SECONDS
        )
        if not was_set:
            raise OtpThrottled("Patientez avant de redemander un code")

        code = _generate_code()
        payload = {
            "hash": hash_otp(code),
            "attempts": 0,
            "issued_at": datetime.now(timezone.utc).isoformat(),
        }
        await self._redis.set(
            _otp_key(phone_e164), json.dumps(payload), ex=OTP_TTL_SECONDS
        )

        body = f"KORA : votre code de connexion est {code}. Ne le partagez avec personne."
        await self._sms.send(to_e164=phone_e164, body=body)

        return OtpIssueResult(
            expires_in_seconds=OTP_TTL_SECONDS,
            debug_code=code if self._debug else None,
        )

    async def verify(self, *, phone_e164: str, code: str) -> None:
        """Verifie l'OTP. Consomme la cle si OK. Leve OtpError sinon."""
        if self._demo_mode:
            # Tout code 4-6 chiffres passe. Le format est deja borne par le
            # schema Pydantic (OTPVerifyIn : min_length=4, max_length=8).
            if not code.isdigit():
                raise OtpInvalid("Code incorrect")
            return

        key = _otp_key(phone_e164)
        raw = await self._redis.get(key)
        if raw is None:
            raise OtpNotFound("Code expire ou inconnu")

        record = json.loads(raw)

        if record["attempts"] >= MAX_ATTEMPTS:
            await self._redis.delete(key)
            raise OtpExhausted("Trop de tentatives, redemandez un code")

        if not verify_otp(code, record["hash"]):
            record["attempts"] += 1
            ttl = await self._redis.ttl(key)
            await self._redis.set(key, json.dumps(record), ex=max(ttl, 1))
            raise OtpInvalid("Code incorrect")

        await self._redis.delete(key)
