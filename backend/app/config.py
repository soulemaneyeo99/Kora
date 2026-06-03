"""Configuration centralisee via pydantic-settings.

Toute valeur ici provient de l'environnement (.env en dev, vars container en prod).
Aucun secret hardcode. Aucun fallback dangereux.
"""
from functools import lru_cache
from typing import Literal

from pydantic import Field, ValidationInfo, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )

    environment: Literal["development", "staging", "production"] = "development"
    debug_otp: bool = False

    # Mode demo client : accepte n'importe quel code OTP 4-6 chiffres, code
    # toujours "000000". Skip Redis et SMS provider. Activer en demo via
    # AUTH_DEMO_MODE=true ; couper avant prod publique.
    auth_demo_mode: bool = False

    database_url: str = Field(..., description="URL asyncpg Postgres")
    redis_url: str = Field(..., description="URL Redis (OTP + throttling)")

    jwt_secret: str = Field(..., min_length=32)
    jwt_algorithm: str = "HS256"
    jwt_ttl_hours: int = 168  # 7 jours

    at_api_key: str = ""
    at_username: str = "sandbox"
    at_sender_id: str = "KORA"

    default_phone_region: str = "CI"

    cors_origins: str = ""

    # ---- Commission KORA --------------------------------------------------
    commission_rate: float = 0.005  # 0,5%

    # ---- Push notifications (vide = LoggingPushProvider en dev) ----------
    # JSON brut du service account Firebase (champ "client_email", "private_key",
    # "project_id"). Si vide -> notifs juste loggees, pas envoyees. Permet de
    # deployer KORA sans Firebase puis brancher quand pret.
    fcm_service_account_json: str = ""

    # ---- Seed demo automatique au demarrage ------------------------------
    # KORA_AUTO_SEED=true -> seed le compte demo "Awa Kone" au boot si pas
    # deja seede (idempotent : skip si le user existe avec >= 10 transactions).
    # Pratique pour les plans Render free (pas de shell). A activer une fois,
    # puis on peut laisser ou retirer la var (no-op apres seed).
    kora_auto_seed: bool = False

    # ---- CinetPay (vide = LoggingPaymentProvider en dev) -------------------
    cinetpay_api_key: str = ""
    cinetpay_site_id: str = ""
    cinetpay_secret_key: str = ""
    cinetpay_base_url: str = "https://api-checkout.cinetpay.com/v2"
    cinetpay_notify_url: str = "http://localhost:8001/api/v1/payments/webhook/cinetpay"
    cinetpay_return_url: str = "http://localhost:3000/payment/done"

    @field_validator("debug_otp", mode="after")
    @classmethod
    def _no_debug_in_prod(cls, v: bool, info: ValidationInfo) -> bool:
        if v and info.data.get("environment") == "production":
            raise ValueError("debug_otp=True interdit en environnement production")
        return v

    @field_validator("database_url", mode="after")
    @classmethod
    def _normalize_database_url(cls, v: str) -> str:
        """Render Postgres injecte postgres:// mais SQLAlchemy async veut postgresql+asyncpg://.
        On normalise pour pouvoir injecter telle quelle l'URL Render."""
        if v.startswith("postgres://"):
            v = "postgresql+asyncpg://" + v[len("postgres://"):]
        elif v.startswith("postgresql://") and "+asyncpg" not in v.split("://", 1)[0]:
            v = "postgresql+asyncpg://" + v[len("postgresql://"):]
        # asyncpg ne comprend pas ?sslmode=require (param libpq). On le retire :
        # asyncpg detecte la necessite TLS via l'URL/serveur.
        if "?sslmode=" in v:
            v = v.split("?sslmode=")[0]
        return v

    @property
    def cors_origins_list(self) -> list[str]:
        if not self.cors_origins:
            return []
        return [o.strip() for o in self.cors_origins.split(",") if o.strip()]

    @property
    def at_is_configured(self) -> bool:
        return bool(self.at_api_key)

    @property
    def cinetpay_is_configured(self) -> bool:
        return bool(self.cinetpay_api_key and self.cinetpay_site_id)


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    return Settings()  # type: ignore[call-arg]
