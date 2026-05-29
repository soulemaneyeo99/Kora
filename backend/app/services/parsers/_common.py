"""Utilitaires partages des parsers."""
import hashlib
import re
import unicodedata

# Pattern montant : "10 000", "10.000", "10,000", suivi de FCFA/XOF/CFA/F
_AMOUNT_PATTERN = re.compile(
    r"(\d{1,3}(?:[\s.,]\d{3})*|\d+)(?:[.,](\d{1,2}))?\s*(?:FCFA|XOF|CFA|F\b)",
    re.IGNORECASE,
)

# Pattern numero CI : +225 suivi de 8 a 10 chiffres, ou 0X XXX XXX XX
_PHONE_PATTERN = re.compile(r"(?:\+225|00225|225)?[\s\-.]?0?[\d\s\-.]{8,15}")


def normalize(text: str) -> str:
    """Lowercase + strip accents pour matcher des regex insensibles."""
    text = unicodedata.normalize("NFKD", text)
    text = "".join(c for c in text if not unicodedata.combining(c))
    return text.lower().strip()


def extract_amount_xof(text: str) -> int | None:
    """Extrait le premier montant en FCFA. Retourne en entier de XOF.

    Note : XOF n'a pas de centimes. Si le texte contient ',00' apres le montant,
    on l'ignore (probablement du formatage local).
    """
    match = _AMOUNT_PATTERN.search(text)
    if not match:
        return None
    raw = match.group(1)
    digits = re.sub(r"[\s.,]", "", raw)
    if not digits.isdigit():
        return None
    return int(digits)


def anonymize_phone(raw: str | None) -> str | None:
    """Hash SHA-256 tronque d'un numero. Conformement a la contrainte de privacy :
    on ne stocke pas les numeros tiers en clair.
    """
    if not raw:
        return None
    digits = re.sub(r"\D", "", raw)
    if len(digits) < 6:
        return None
    h = hashlib.sha256(digits.encode("utf-8")).hexdigest()
    return f"hash:{h[:16]}"


def find_phone(text: str) -> str | None:
    match = _PHONE_PATTERN.search(text)
    if not match:
        return None
    candidate = match.group(0)
    # Au moins 8 chiffres pour eviter de matcher un montant
    if len(re.sub(r"\D", "", candidate)) < 8:
        return None
    return candidate
