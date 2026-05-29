"""Parser Wave.

Formats observes :
- "Vous avez recu 5 000 FCFA de YEO SOULEYMANE."
- "Vous avez envoye 2 500 FCFA a +2250707070707."
- "Confirme: paiement de 1 000 FCFA chez SHELL."
"""
from datetime import datetime

from app.domain.enums import TxKind, TxSource
from app.services.parsers._common import (
    anonymize_phone,
    extract_amount_xof,
    find_phone,
    normalize,
)
from app.services.parsers.base import (
    NotificationParser,
    ParsedNotification,
    ParseError,
)

_INCOME_KEYWORDS = ("vous avez recu", "wave recu", "credit de", "depot de")
_EXPENSE_KEYWORDS = (
    "vous avez envoye",
    "paiement de",
    "transfert de",
    "envoye a",
    "retrait de",
)
_PACKAGE_HINTS = ("wave",)


class WaveParser(NotificationParser):
    name = "wave"
    version = "v1"

    def can_handle(self, *, package_source: str, parser_hint: str | None) -> bool:
        if parser_hint == self.name:
            return True
        ps = package_source.lower()
        return any(h in ps for h in _PACKAGE_HINTS)

    def parse(
        self,
        *,
        title: str | None,
        text: str,
        captured_at: datetime,
        external_id: str | None,
    ) -> ParsedNotification | None:
        combined = f"{title or ''}\n{text}"
        norm = normalize(combined)

        if any(k in norm for k in _INCOME_KEYWORDS):
            kind = TxKind.INCOME
        elif any(k in norm for k in _EXPENSE_KEYWORDS):
            kind = TxKind.EXPENSE
        else:
            return None

        amount = extract_amount_xof(combined)
        if amount is None or amount <= 0:
            raise ParseError("Montant absent ou invalide (Wave)")

        counterparty = anonymize_phone(find_phone(combined))

        return ParsedNotification(
            amount_xof=amount,
            kind=kind,
            counterparty=counterparty,
            description=f"Wave {'recu' if kind == TxKind.INCOME else 'envoye'} {amount} XOF",
            occurred_at=captured_at,
            source=TxSource.NOTIFICATION,
            source_ref=self._build_source_ref(external_id, captured_at, amount),
        )

    def _build_source_ref(
        self, external_id: str | None, captured_at: datetime, amount: int
    ) -> str:
        if external_id:
            return f"{self.name}:{self.version}:{external_id}"
        stamp = captured_at.replace(microsecond=0).isoformat()
        return f"{self.name}:{self.version}:fallback:{stamp}:{amount}"
