"""Registre des parsers : selection en fonction du package source / hint."""
from app.services.parsers.base import NotificationParser
from app.services.parsers.mtn_momo import MtnMomoParser
from app.services.parsers.orange_money import OrangeMoneyParser
from app.services.parsers.wave import WaveParser


class ParserRegistry:
    def __init__(self, parsers: list[NotificationParser]):
        self._parsers = parsers

    def find(
        self, *, package_source: str, parser_hint: str | None = None
    ) -> NotificationParser | None:
        # Si hint explicite, prendre le 1er qui declare ce nom.
        if parser_hint:
            for p in self._parsers:
                if p.name == parser_hint:
                    return p

        for p in self._parsers:
            if p.can_handle(package_source=package_source, parser_hint=parser_hint):
                return p
        return None


def get_default_registry() -> ParserRegistry:
    return ParserRegistry(
        parsers=[
            MtnMomoParser(),
            OrangeMoneyParser(),
            WaveParser(),
        ]
    )
