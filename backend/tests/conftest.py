"""Fixtures partagees.

Note : ces tests sont des smoke tests purs (pas de DB/Redis reels).
Les tests d'integration arrivent en tranche 2 (override DB + fakeredis).
"""
from collections.abc import AsyncGenerator

import pytest_asyncio
from httpx import ASGITransport, AsyncClient

from app.main import create_app


@pytest_asyncio.fixture
async def client() -> AsyncGenerator[AsyncClient, None]:
    app = create_app()
    async with AsyncClient(
        transport=ASGITransport(app=app),
        base_url="http://test",
    ) as ac:
        yield ac
