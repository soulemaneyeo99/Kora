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
    settings = get_settings()
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

    # Seed compte demo "Awa Kone" si demande via env (KORA_AUTO_SEED=true).
    # Idempotent : skip si deja en place. Pratique pour les plans Render
    # free (pas d'acces shell pour lancer le script manuellement).
    if settings.kora_auto_seed:
        try:
            from scripts.seed_demo import seed_demo

            result = await seed_demo(force=False)
            logger.info("Seed demo: %s", result)
        except Exception:
            logger.exception("Echec du seed demo Awa Kone")

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
