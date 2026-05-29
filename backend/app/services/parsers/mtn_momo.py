"""Parser MTN Mobile Money (Cote d'Ivoire).

Formats reconnus (textes typiques) :
- "Vous avez recu 5,000 FCFA de +225 07 12 34 56 78. Nouveau solde: 12,500 FCFA."
- "Transfert de 10,000 FCFA vers MOUSSA YEO effectue. Reste: 2,300 FCFA."
- "Paiement de 1,500 FCFA chez MAQUIS DU CARREFOUR confirme."

Les formats reels varient dans le temps : ce parser est versionne pour pouvoir
reparser l'historique apres correction.
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

_INCOME_KEYWORDS = ("vous avez recu", "credite de", "depot de", "credit de")
_EXPENSE_KEYWORDS = (
    "transfert de",
    "paiement de",
    "envoi de",
    "achat de",
    "retrait de",
    "debit de",
)
_PACKAGE_HINTS = ("mtn", "momo", "mobile money")


class MtnMomoParser(NotificationParser):
    name = "mtn_momo"
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

        kind = self._classify_kind(norm)
        if kind is None:
            return None

        amount = extract_amount_xof(combined)
        if amount is None:
            raise ParseError("Montant introuvable dans le texte MTN MoMo")
        if amount <= 0:
            raise ParseError(f"Montant invalide : {amount}")

        counterparty = anonymize_phone(find_phone(combined))
        if counterparty is None and kind == TxKind.EXPENSE:
            # Beneficiaire nomme (commercant) : on garde le nom brut comme contrepartie
            # apres troncature, sans hash (ce n'est pas un numero perso).
            counterparty = self._extract_merchant(text)

        source_ref = self._build_source_ref(external_id, captured_at, amount)

        return ParsedNotification(
            amount_xof=amount,
            kind=kind,
            counterparty=counterparty,
            description=self._build_description(kind, amount),
            occurred_at=captured_at,
            source=TxSource.NOTIFICATION,
            source_ref=source_ref,
        )

    def _classify_kind(self, normalized: str) -> TxKind | None:
        if any(k in normalized for k in _INCOME_KEYWORDS):
            return TxKind.INCOME
        if any(k in normalized for k in _EXPENSE_KEYWORDS):
            return TxKind.EXPENSE
        return None

    def _extract_merchant(self, text: str) -> str | None:
        # Heuristique : apres "chez" ou "vers", couper au premier verbe / ponctuation.
        stop_words = (" confirme", " effectue", " reussi", " ok", " valide")
        for prefix in (" chez ", " vers ", " a "):
            idx = text.lower().find(prefix)
            if idx >= 0:
                tail = text[idx + len(prefix) :].strip()
                tail = tail.split(".")[0].split(",")[0]
                lowered = tail.lower()
                for sw in stop_words:
                    cut = lowered.find(sw)
                    if cut > 0:
                        tail = tail[:cut]
                        break
                tail = tail.strip()
                return tail[:30] or None
        return None

    def _build_description(self, kind: TxKind, amount: int) -> str:
        if kind == TxKind.INCOME:
            return f"MTN MoMo recu {amount} XOF"
        return f"MTN MoMo envoye {amount} XOF"

    def _build_source_ref(
        self, external_id: str | None, captured_at: datetime, amount: int
    ) -> str:
        if external_id:
            return f"{self.name}:{self.version}:{external_id}"
        # Fallback : hash deterministe pour dedup faible.
        stamp = captured_at.replace(microsecond=0).isoformat()
        return f"{self.name}:{self.version}:fallback:{stamp}:{amount}"
