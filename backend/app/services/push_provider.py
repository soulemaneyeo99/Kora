"""Fournisseur de push notifications.

Selection automatique via `get_push_provider(settings)` :
  - FCM_SERVICE_ACCOUNT_JSON defini -> FcmPushProvider (FCM HTTP v1)
  - sinon                            -> LoggingPushProvider (log only, dev)

L'envoi est best-effort : on log les erreurs mais on ne fait pas exploser
l'appelant. Une notif ratee ne doit jamais casser le flux principal.
"""
from __future__ import annotations

import json
import logging
import time
from dataclasses import dataclass
from typing import Protocol

import httpx
from jose import jwt

from app.config import Settings

logger = logging.getLogger(__name__)


@dataclass(frozen=True)
class PushMessage:
    """Message push universel : title + body + data optionnel."""

    title: str
    body: str
    data: dict[str, str] | None = None


@dataclass
class PushResult:
    sent: int
    failed: int
    invalid_tokens: list[str]  # tokens a desactiver (404/410 cote provider)


class PushProvider(Protocol):
    name: str

    async def send(
        self,
        *,
        tokens: list[str],
        message: PushMessage,
    ) -> PushResult: ...


class LoggingPushProvider:
    """Provider de dev : log la notif au lieu de l'envoyer.

    Toujours considere comme succes. Permet de developper localement sans
    Firebase et d'avoir une trace dans Render logs en prod si FCM pas branche.
    """

    name = "log"

    async def send(
        self, *, tokens: list[str], message: PushMessage
    ) -> PushResult:
        for tok in tokens:
            logger.warning(
                "[PUSH-MOCK] -> %s... : %s | %s",
                tok[:12],
                message.title,
                message.body,
            )
        return PushResult(sent=len(tokens), failed=0, invalid_tokens=[])


class FcmPushProvider:
    """Provider Firebase Cloud Messaging via HTTP v1 API.

    Active si Settings.fcm_service_account_json est defini (JSON brut du
    service account, ou chemin vers le fichier).

    Auth : OAuth2 service account JWT -> access_token. Refresh quand expiry < 5 min.
    """

    name = "fcm"
    TOKEN_URL = "https://oauth2.googleapis.com/token"
    SCOPE = "https://www.googleapis.com/auth/firebase.messaging"

    def __init__(self, *, service_account: dict[str, str]) -> None:
        self._client_email = service_account["client_email"]
        self._private_key = service_account["private_key"]
        self._project_id = service_account["project_id"]
        self._send_url = (
            f"https://fcm.googleapis.com/v1/projects/{self._project_id}/messages:send"
        )
        self._cached_token: str | None = None
        self._cached_token_exp: float = 0.0

    async def _get_access_token(self) -> str:
        now = time.time()
        # 300s de marge avant l'expiration reelle.
        if self._cached_token and self._cached_token_exp - now > 300:
            return self._cached_token

        # JWT signe pour OAuth2 service account.
        claims = {
            "iss": self._client_email,
            "scope": self.SCOPE,
            "aud": self.TOKEN_URL,
            "iat": int(now),
            "exp": int(now) + 3600,
        }
        assertion = jwt.encode(claims, self._private_key, algorithm="RS256")
        async with httpx.AsyncClient(timeout=10.0) as client:
            resp = await client.post(
                self.TOKEN_URL,
                data={
                    "grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer",
                    "assertion": assertion,
                },
            )
        resp.raise_for_status()
        payload = resp.json()
        self._cached_token = str(payload["access_token"])
        self._cached_token_exp = now + int(payload.get("expires_in", 3600))
        return self._cached_token

    async def send(
        self, *, tokens: list[str], message: PushMessage
    ) -> PushResult:
        if not tokens:
            return PushResult(sent=0, failed=0, invalid_tokens=[])

        access_token = await self._get_access_token()
        sent = 0
        failed = 0
        invalid: list[str] = []

        async with httpx.AsyncClient(timeout=10.0) as client:
            for tok in tokens:
                body: dict[str, object] = {
                    "message": {
                        "token": tok,
                        "notification": {
                            "title": message.title,
                            "body": message.body,
                        },
                    }
                }
                if message.data:
                    body["message"]["data"] = message.data  # type: ignore[index]
                try:
                    resp = await client.post(
                        self._send_url,
                        headers={
                            "Authorization": f"Bearer {access_token}",
                            "Content-Type": "application/json; charset=utf-8",
                        },
                        json=body,
                    )
                    if resp.status_code == 200:
                        sent += 1
                    elif resp.status_code in (404, 410):
                        # Token invalide cote FCM -> a desactiver cote DB.
                        invalid.append(tok)
                        failed += 1
                    else:
                        logger.warning(
                            "FCM send echec %s : %s", resp.status_code, resp.text[:200]
                        )
                        failed += 1
                except httpx.HTTPError as e:
                    logger.warning("FCM send exception : %s", e)
                    failed += 1

        return PushResult(sent=sent, failed=failed, invalid_tokens=invalid)


def get_push_provider(settings: Settings) -> PushProvider:
    raw = settings.fcm_service_account_json.strip()
    if not raw:
        return LoggingPushProvider()
    try:
        sa = json.loads(raw)
        return FcmPushProvider(service_account=sa)
    except (json.JSONDecodeError, KeyError) as e:
        logger.error(
            "FCM_SERVICE_ACCOUNT_JSON invalide (%s), fallback log provider", e
        )
        return LoggingPushProvider()
