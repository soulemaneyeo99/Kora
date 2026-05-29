"""Tests parsers de notifications mobile money."""
from datetime import datetime, timezone

import pytest

from app.domain.enums import TxKind
from app.services.parsers import (
    MtnMomoParser,
    OrangeMoneyParser,
    WaveParser,
    get_default_registry,
)


@pytest.fixture
def now():
    return datetime(2026, 5, 28, 12, 0, tzinfo=timezone.utc)


# ---- routage du registre ---------------------------------------------------


def test_registry_routes_mtn_to_mtn_parser():
    reg = get_default_registry()
    parser = reg.find(package_source="com.mtn.momo")
    assert isinstance(parser, MtnMomoParser)


def test_registry_routes_wave_to_wave_parser():
    reg = get_default_registry()
    parser = reg.find(package_source="com.wave.personal")
    assert isinstance(parser, WaveParser)


def test_registry_routes_orange_to_orange_parser():
    reg = get_default_registry()
    parser = reg.find(package_source="com.orange.app")
    assert isinstance(parser, OrangeMoneyParser)


def test_registry_unknown_package_returns_none():
    reg = get_default_registry()
    assert reg.find(package_source="com.exotic.bank") is None


def test_registry_om_substring_does_not_match_orange_by_accident():
    """'om' ne doit pas matcher 'com.*' (regression bug T3)."""
    reg = get_default_registry()
    parser = reg.find(package_source="com.exotic.bank")
    assert parser is None


def test_registry_parser_hint_wins_over_package():
    reg = get_default_registry()
    parser = reg.find(package_source="com.exotic.bank", parser_hint="mtn_momo")
    assert isinstance(parser, MtnMomoParser)


# ---- MTN MoMo --------------------------------------------------------------


def test_mtn_parses_received(now):
    parsed = MtnMomoParser().parse(
        title="MTN MoMo",
        text="Vous avez recu 5,000 FCFA de +225 07 12 34 56 78.",
        captured_at=now,
        external_id="ext-1",
    )
    assert parsed is not None
    assert parsed.amount_xof == 5000
    assert parsed.kind == TxKind.INCOME
    assert parsed.counterparty is not None
    assert parsed.counterparty.startswith("hash:")
    assert parsed.source_ref == "mtn_momo:v1:ext-1"


def test_mtn_parses_payment_extracts_merchant(now):
    parsed = MtnMomoParser().parse(
        title=None,
        text="Paiement de 1 500 FCFA chez MAQUIS DU CARREFOUR confirme.",
        captured_at=now,
        external_id="ext-2",
    )
    assert parsed is not None
    assert parsed.kind == TxKind.EXPENSE
    assert parsed.amount_xof == 1500
    assert parsed.counterparty == "MAQUIS DU CARREFOUR"


def test_mtn_ignores_promo(now):
    parsed = MtnMomoParser().parse(
        title=None,
        text="Offre speciale : 100 Mo gratuits pour 1000 FCFA. *123#",
        captured_at=now,
        external_id=None,
    )
    assert parsed is None


def test_mtn_fallback_source_ref_when_no_external_id(now):
    parsed = MtnMomoParser().parse(
        title=None,
        text="Vous avez recu 2 000 FCFA de +225 0123456789",
        captured_at=now,
        external_id=None,
    )
    assert parsed is not None
    assert parsed.source_ref.startswith("mtn_momo:v1:fallback:")


# ---- Wave ------------------------------------------------------------------


def test_wave_parses_received(now):
    parsed = WaveParser().parse(
        title=None,
        text="Vous avez recu 10 000 FCFA de YEO SOULEYMANE.",
        captured_at=now,
        external_id="wave-1",
    )
    assert parsed is not None
    assert parsed.amount_xof == 10000
    assert parsed.kind == TxKind.INCOME


def test_wave_parses_payment(now):
    parsed = WaveParser().parse(
        title=None,
        text="Confirme: paiement de 1 000 FCFA chez SHELL.",
        captured_at=now,
        external_id="wave-2",
    )
    assert parsed is not None
    assert parsed.amount_xof == 1000
    assert parsed.kind == TxKind.EXPENSE


# ---- Orange Money ----------------------------------------------------------


def test_orange_parses_received(now):
    parsed = OrangeMoneyParser().parse(
        title="Orange Money",
        text="OM Recu 25000 FCFA de 0707070707 le 27/05/2026",
        captured_at=now,
        external_id="om-1",
    )
    assert parsed is not None
    assert parsed.amount_xof == 25000
    assert parsed.kind == TxKind.INCOME


def test_orange_parses_paid(now):
    parsed = OrangeMoneyParser().parse(
        title=None,
        text="Vous avez paye 1500 FCFA a SHELL le 27/05/2026",
        captured_at=now,
        external_id="om-2",
    )
    assert parsed is not None
    assert parsed.kind == TxKind.EXPENSE
    assert parsed.amount_xof == 1500
