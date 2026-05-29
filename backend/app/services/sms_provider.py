"""Fournisseur SMS : Africa's Talking en prod, mock loggue en dev.

Selection automatique via `get_sms_provider(settings)` :
  - AT_API_KEY non vide  -> AfricasTalkingSmsProvider
  - sinon                -> LoggingSmsProvider (affiche l'OTP dans les logs)
"""
from __future__ import annotations

import logging
from typing import Protocol

import httpx

from app.config import Settings

logger = logging.getLogger(__name__)


class SmsProvider(Protocol):
    async def send(self, *, to_e164: str, body: str) -> None: ...


class LoggingSmsProvider:
    """Provider de dev : log l'OTP au lieu de l'envoyer."""

    async def send(self, *, to_e164: str, body: str) -> None:
        logger.warning("[SMS-MOCK] -> %s : %s", to_e164, body)


class AfricasTalkingSmsProvider:
    """Provider de prod via API REST Africa's Talking.

    Doc : https://developers.africastalking.com/docs/sms/sending/restapi
    """

    SANDBOX_URL = "https://api.sandbox.africastalking.com/version1/messaging"
    LIVE_URL = "https://api.africastalking.com/version1/messaging"

    def __init__(self, *, api_key: str, username: str, sender_id: str | None = None) -> None:
        self._api_key = api_key
        self._username = username
        self._sender_id = sender_id
        self._url = self.SANDBOX_URL if username == "sandbox" else self.LIVE_URL

    async def send(self, *, to_e164: str, body: str) -> None:
        data = {"username": self._username, "to": to_e164, "message": body}
        if self._sender_id:
            data["from"] = self._sender_id

        async with httpx.AsyncClient(timeout=10.0) as client:
            resp = await client.post(
                self._url,
                data=data,
                headers={
                    "apiKey": self._api_key,
                    "Content-Type": "application/x-www-form-urlencoded",
                    "Accept": "application/json",
                },
            )
        if resp.status_code >= 400:
            logger.error("Africa's Talking SMS echec %s : %s", resp.status_code, resp.text)
            raise RuntimeError(f"SMS provider error: {resp.status_code}")


def get_sms_provider(settings: Settings) -> SmsProvider:
    if settings.at_is_configured:
        return AfricasTalkingSmsProvider(
            api_key=settings.at_api_key,
            username=settings.at_username,
            sender_id=settings.at_sender_id or None,
        )
    return LoggingSmsProvider()
