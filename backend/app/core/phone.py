"""Validation et normalisation de numeros vers E.164.

Accepte les formats locaux CI (07 12 34 56 78, 0712345678) et internationaux.
"""
import phonenumbers
from phonenumbers import NumberParseException

from app.config import get_settings


class InvalidPhoneError(ValueError):
    pass


def normalize_to_e164(raw: str) -> str:
    settings = get_settings()
    try:
        parsed = phonenumbers.parse(raw, settings.default_phone_region)
    except NumberParseException as e:
        raise InvalidPhoneError(f"Numero illisible : {raw}") from e

    if not phonenumbers.is_valid_number(parsed):
        raise InvalidPhoneError(f"Numero invalide : {raw}")

    return phonenumbers.format_number(parsed, phonenumbers.PhoneNumberFormat.E164)
