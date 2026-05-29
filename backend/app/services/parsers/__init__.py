"""Parsers de notifications mobile money.

Chaque parser implemente le Protocol `NotificationParser`. Le registre selectionne
le parser en fonction du `package_source` ou d'un `parser_hint` explicite.

Versionnement : un parser garde son `version` (ex: "v1") pour pouvoir reprocesser
l'historique apres correction d'une regex.
"""
from app.services.parsers.base import (
    NotificationParser,
    ParsedNotification,
    ParseError,
)
from app.services.parsers.mtn_momo import MtnMomoParser
from app.services.parsers.orange_money import OrangeMoneyParser
from app.services.parsers.registry import ParserRegistry, get_default_registry
from app.services.parsers.wave import WaveParser

__all__ = [
    "MtnMomoParser",
    "NotificationParser",
    "OrangeMoneyParser",
    "ParseError",
    "ParsedNotification",
    "ParserRegistry",
    "WaveParser",
    "get_default_registry",
]
