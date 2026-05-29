"""Provider de paiement : interface + implementations CinetPay et logging.

Le provider est responsable de :
1. Initier un paiement (renvoyer une URL de checkout + un provider_ref).
2. Valider une notification webhook (signature, statut).

KORA n'est jamais depositaire : le provider gere la conservation des fonds.
"""
import hashlib
import hmac
import logging
import secrets
from dataclasses import dataclass
from typing import Protocol, runtime_checkable

import httpx

from app.config import Settings

logger = logging.getLogger(__name__)


@dataclass(frozen=True)
class InitResult:
    provider_ref: str
    checkout_url: str | None


class PaymentProviderError(Exception):
    pass


@runtime_checkable
class PaymentProvider(Protocol):
    name: str

    async def initiate(
        self, *, amount_xof: int, internal_ref: str, description: str
    ) -> InitResult: ...

    def verify_webhook_signature(
        self, *, payload: dict, signature: str | None
    ) -> bool: ...


class LoggingPaymentProvider(PaymentProvider):
    """Stub dev : ne facture jamais. Renvoie un ref aleatoire + URL factice."""

    name = "logging"

    async def initiate(
        self, *, amount_xof: int, internal_ref: str, description: str
    ) -> InitResult:
        ref = f"log-{secrets.token_hex(6)}"
        logger.warning(
            "[DEV] Paiement simule: ref=%s amount=%s XOF (%s)",
            ref,
            amount_xof,
            description,
        )
        return InitResult(provider_ref=ref, checkout_url=None)

    def verify_webhook_signature(
        self, *, payload: dict, signature: str | None
    ) -> bool:
        # En dev, on accepte tout. Ne JAMAIS faire ca en prod.
        return True


class CinetPayProvider(PaymentProvider):
    """Provider CinetPay (sandbox / prod selon settings).

    NOTE : Le contrat exact (endpoints, parametres) est a confirmer dans la
    documentation CinetPay au moment de l'integration. Cette implementation
    suit le format publie : POST https://api-checkout.cinetpay.com/v2/payment
    payload JSON avec apikey + site_id + transaction_id + amount + currency.
    """

    name = "cinetpay"

    def __init__(self, settings: Settings) -> None:
        self._api_key = settings.cinetpay_api_key
        self._site_id = settings.cinetpay_site_id
        self._secret_key = settings.cinetpay_secret_key
        self._base_url = settings.cinetpay_base_url
        self._currency = "XOF"
        self._notify_url = settings.cinetpay_notify_url
        self._return_url = settings.cinetpay_return_url

    async def initiate(
        self, *, amount_xof: int, internal_ref: str, description: str
    ) -> InitResult:
        if not self._api_key or not self._site_id:
            raise PaymentProviderError(
                "CinetPay non configure (CINETPAY_API_KEY / SITE_ID manquants)"
            )
        payload = {
            "apikey": self._api_key,
            "site_id": self._site_id,
            "transaction_id": internal_ref,
            "amount": amount_xof,
            "currency": self._currency,
            "description": description[:200],
            "notify_url": self._notify_url,
            "return_url": self._return_url,
            "channels": "ALL",
            "metadata": internal_ref,
        }
        async with httpx.AsyncClient(timeout=15.0) as client:
            try:
                resp = await client.post(
                    f"{self._base_url}/payment", json=payload
                )
            except httpx.HTTPError as e:
                raise PaymentProviderError(
                    f"Erreur reseau vers CinetPay : {e}"
                ) from e
        if resp.status_code >= 400:
            raise PaymentProviderError(
                f"CinetPay HTTP {resp.status_code} : {resp.text[:200]}"
            )
        data = resp.json()
        # Format attendu (sandbox): { "code": "201", "data": { "payment_url": "...", "payment_token": "..." } }
        if data.get("code") not in ("201", "00"):
            raise PaymentProviderError(
                f"CinetPay refuse : code={data.get('code')} msg={data.get('message')}"
            )
        checkout_url = data.get("data", {}).get("payment_url")
        if not checkout_url:
            raise PaymentProviderError("CinetPay : payment_url absent de la reponse")
        return InitResult(provider_ref=internal_ref, checkout_url=checkout_url)

    def verify_webhook_signature(
        self, *, payload: dict, signature: str | None
    ) -> bool:
        if not signature or not self._secret_key:
            return False
        # CinetPay : signature HMAC-SHA256 sur la concatenation des champs cles.
        # Format reel a verifier dans la doc officielle ; ici on calcule un HMAC
        # standard sur le payload trie pour servir de squelette.
        canonical = "&".join(
            f"{k}={payload[k]}" for k in sorted(payload) if k != "signature"
        )
        expected = hmac.new(
            self._secret_key.encode("utf-8"),
            canonical.encode("utf-8"),
            hashlib.sha256,
        ).hexdigest()
        return hmac.compare_digest(expected, signature)


def get_payment_provider(settings: Settings) -> PaymentProvider:
    if settings.cinetpay_api_key and settings.cinetpay_site_id:
        return CinetPayProvider(settings)
    return LoggingPaymentProvider()
