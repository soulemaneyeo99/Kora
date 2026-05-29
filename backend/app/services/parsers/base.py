"""Interface commune des parsers de notifications."""
from dataclasses import dataclass
from datetime import datetime
from typing import Protocol, runtime_checkable

from app.domain.enums import TxKind, TxSource


class ParseError(Exception):
    """Le parser reconnait le format mais une donnee est invalide (montant ko, etc.)."""


@dataclass(frozen=True)
class ParsedNotification:
    """Resultat structure d'un parser. Pret a etre transforme en Transaction."""

    amount_xof: int
    kind: TxKind
    counterparty: str | None  # deja anonymise (hash du numero source)
    description: str
    occurred_at: datetime
    source: TxSource  # NOTIFICATION ou SMS
    # Cle d'idempotence : (source_ref) = "{parser_name}:{parser_version}:{external_id}"
    source_ref: str


@runtime_checkable
class NotificationParser(Protocol):
    """Contrat d'un parser."""

    name: str
    version: str

    def can_handle(self, *, package_source: str, parser_hint: str | None) -> bool:
        """Retourne True si ce parser peut tenter d'extraire la notif."""

    def parse(
        self,
        *,
        title: str | None,
        text: str,
        captured_at: datetime,
        external_id: str | None,
    ) -> ParsedNotification | None:
        """Retourne None si rien d'interessant (ex: notif promo) ; ParsedNotification sinon ;
        leve ParseError si reconnu mais corrompu.
        """
