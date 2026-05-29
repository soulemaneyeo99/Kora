"""Schemas pour l'ingestion de notifications mobile money / SMS."""
from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class NotificationIngestIn(BaseModel):
    """Payload envoye par l'app mobile pour une notification capturee.

    Contraintes :
    - `package_source` permet de selecter le bon parser (com.mtn.momo, etc.)
    - `external_id` (notif id Android, ou hash) sert a la dedup cote serveur.
    - `raw_text` est purge apres 7 jours (cron a venir).
    """

    package_source: str = Field(..., min_length=1, max_length=80)
    external_id: str | None = Field(default=None, max_length=120)
    raw_title: str | None = Field(default=None, max_length=300)
    raw_text: str = Field(..., min_length=1, max_length=2000)
    captured_at: datetime
    parser_hint: str | None = Field(
        default=None,
        max_length=50,
        description="Indice manuel: 'mtn_momo' / 'wave' / 'orange_money'. Optionnel.",
    )


class ParseDecision(BaseModel):
    """Resultat d'un parser : reussi, ignore (pas une tx), ou echec."""

    success: bool
    reason: str | None = None
    transaction_id: UUID | None = None


class IngestResult(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    decision: ParseDecision
    parser_name: str
    parser_version: str
    duplicate: bool = False
