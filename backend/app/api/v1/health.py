"""Endpoints de sante (liveness + readiness)."""
from fastapi import APIRouter
from sqlalchemy import text

from app.deps import DbDep, RedisDep

router = APIRouter()


@router.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok"}


@router.get("/health/ready")
async def readiness(db: DbDep, redis_client: RedisDep) -> dict[str, str]:
    """Verifie que DB + Redis repondent. A utiliser par l'orchestrateur (k8s/Render/etc)."""
    await db.execute(text("SELECT 1"))
    await redis_client.ping()
    return {"status": "ready"}
