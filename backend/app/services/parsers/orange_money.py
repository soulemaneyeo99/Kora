"""Parser Orange Money (Cote d'Ivoire).

Formats observes (sandbox + retours utilisateurs) :
- "OM Recu 25000 FCFA de 0707070707 le 27/05/2026"
- "Vous avez paye 1500 FCFA a SHELL le 27/05/2026"
- "Transfert de 10000 FCFA effectue vers 0809090909"
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

_INCOME_KEYWORDS = ("recu", "credite")
_EXPENSE_KEYWORDS = ("paye", "transfert", "envoi", "retrait", "achat", "debit")


class OrangeMoneyParser(NotificationParser):
    name = "orange_money"
    version = "v1"

    def can_handle(self, *, package_source: str, parser_hint: str | None) -> bool:
        if parser_hint == self.name:
            return True
        ps = package_source.lower()
        if "orange" in ps or "orangemoney" in ps:
            return True
        # On accepte "om" comme segment complet, ex : "com.foo.om" mais pas "com.foo"
        segments = ps.split(".")
        return "om" in segments

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

        # Filtre rapide : si pas de FCFA et pas de mots-cles tx, on ignore
        if not any(k in norm for k in _INCOME_KEYWORDS + _EXPENSE_KEYWORDS):
            return None

        if any(k in norm for k in _INCOME_KEYWORDS) and "recu" in norm:
            kind = TxKind.INCOME
        elif any(k in norm for k in _EXPENSE_KEYWORDS):
            kind = TxKind.EXPENSE
        else:
            return None

        amount = extract_amount_xof(combined)
        if amount is None or amount <= 0:
            raise ParseError("Montant absent ou invalide (Orange Money)")

        counterparty = anonymize_phone(find_phone(combined))

        return ParsedNotification(
            amount_xof=amount,
            kind=kind,
            counterparty=counterparty,
            description=f"Orange Money {'recu' if kind == TxKind.INCOME else 'envoye'} {amount} XOF",
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
