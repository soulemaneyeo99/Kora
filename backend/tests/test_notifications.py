"""Tests du NotificationService : dispatch + desactivation des tokens invalides.

Pas de DB reelle (pas d'infra d'integration encore en place). On utilise
une fake session SQLAlchemy qui capture les SELECT et UPDATE pour verifier
la logique metier sans dependre du dialecte.
"""
from __future__ import annotations

import uuid
from dataclasses import dataclass, field
from typing import Any

import pytest

from app.services.notifications import NotificationService
from app.services.push_provider import PushMessage, PushResult


# ---------------------------------------------------------------------------
# Fake push provider
# ---------------------------------------------------------------------------
@dataclass
class _FakePushProvider:
    name: str = "fake"
    invalid_to_return: list[str] = field(default_factory=list)
    calls: list[tuple[list[str], PushMessage]] = field(default_factory=list)

    async def send(self, *, tokens, message):
        self.calls.append((list(tokens), message))
        return PushResult(
            sent=len(tokens) - len(self.invalid_to_return),
            failed=len(self.invalid_to_return),
            invalid_tokens=list(self.invalid_to_return),
        )


# ---------------------------------------------------------------------------
# Fake AsyncSession minimal : retourne la liste de tokens preprogrammee pour
# le SELECT, et capture les UPDATE pour assertion ulterieure.
# ---------------------------------------------------------------------------
class _ScalarResult:
    def __init__(self, rows: list[Any]) -> None:
        self._rows = rows

    def scalars(self):
        return self

    def all(self):
        return list(self._rows)


@dataclass
class _FakeSession:
    tokens: list[str] = field(default_factory=list)
    updates: list[Any] = field(default_factory=list)
    flush_count: int = 0

    async def execute(self, stmt):
        # On differencie SELECT (renvoie les tokens) de UPDATE (capture).
        from sqlalchemy.sql.selectable import Select
        from sqlalchemy.sql.dml import Update

        if isinstance(stmt, Select):
            return _ScalarResult(list(self.tokens))
        if isinstance(stmt, Update):
            self.updates.append(stmt)
            return _ScalarResult([])
        return _ScalarResult([])

    async def flush(self):
        self.flush_count += 1


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------
async def test_send_to_user_with_no_devices_skips_provider():
    session = _FakeSession(tokens=[])
    fake = _FakePushProvider()
    svc = NotificationService(push_provider=fake)

    result = await svc.send_to_user(
        session,  # type: ignore[arg-type]
        user_id=uuid.uuid4(),
        message=PushMessage(title="x", body="y"),
    )

    assert result.sent == 0
    assert result.failed == 0
    assert fake.calls == [], "Aucun appel push si pas de devices"


async def test_send_to_user_dispatches_to_all_active_tokens():
    session = _FakeSession(tokens=["t1", "t2", "t3"])
    fake = _FakePushProvider()
    svc = NotificationService(push_provider=fake)

    await svc.send_to_user(
        session,  # type: ignore[arg-type]
        user_id=uuid.uuid4(),
        message=PushMessage(title="Hi", body="hello", data={"k": "v"}),
    )

    assert len(fake.calls) == 1
    sent_tokens, msg = fake.calls[0]
    assert sent_tokens == ["t1", "t2", "t3"]
    assert msg.title == "Hi"
    assert msg.body == "hello"
    assert msg.data == {"k": "v"}


async def test_invalid_tokens_trigger_update_call():
    session = _FakeSession(tokens=["good", "dead"])
    fake = _FakePushProvider(invalid_to_return=["dead"])
    svc = NotificationService(push_provider=fake)

    result = await svc.send_to_user(
        session,  # type: ignore[arg-type]
        user_id=uuid.uuid4(),
        message=PushMessage(title="x", body="y"),
    )

    assert result.invalid_tokens == ["dead"]
    assert len(session.updates) == 1, "1 UPDATE pour desactiver le token mort"
    assert session.flush_count == 1


async def test_no_update_when_all_tokens_valid():
    session = _FakeSession(tokens=["t1", "t2"])
    fake = _FakePushProvider(invalid_to_return=[])
    svc = NotificationService(push_provider=fake)

    await svc.send_to_user(
        session,  # type: ignore[arg-type]
        user_id=uuid.uuid4(),
        message=PushMessage(title="x", body="y"),
    )

    assert session.updates == []
    assert session.flush_count == 0


def test_provider_name_property_passthrough():
    svc = NotificationService(push_provider=_FakePushProvider(name="custom"))
    assert svc.provider_name == "custom"


def test_push_message_is_frozen():
    msg = PushMessage(title="A", body="B")
    with pytest.raises(Exception):
        msg.title = "C"  # type: ignore[misc]
