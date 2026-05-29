"""Point d'entree FastAPI : create_app() + instance `app` pour uvicorn."""
import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.v1.router import api_router
from app.config import get_settings
from app.db import AsyncSessionLocal
from app.services.category import seed_default_categories

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(_app: FastAPI):
    # Seed categories systeme (idempotent).
    async with AsyncSessionLocal() as session:
        try:
            created = await seed_default_categories(session)
            await session.commit()
            if created:
                logger.info("Seed: %d categories systeme creees", created)
        except Exception:
            logger.exception("Echec du seed des categories systeme")
            await session.rollback()
    yield


def create_app() -> FastAPI:
    settings = get_settings()

    app = FastAPI(
        title="KORA Finance API",
        version="0.2.0",
        description="Backend coaching financier — Cote d'Ivoire",
        docs_url="/docs" if settings.environment != "production" else None,
        redoc_url=None,
        lifespan=lifespan,
    )

    if settings.cors_origins_list:
        app.add_middleware(
            CORSMiddleware,
            allow_origins=settings.cors_origins_list,
            allow_credentials=True,
            allow_methods=["*"],
            allow_headers=["*"],
        )

    app.include_router(api_router, prefix="/api/v1")

    return app


app = create_app()
