"""Endpoint d'ingestion de notifications mobile money.

POST /transactions/ingest
Idempotent via source_ref ; retourne 200 si parse ok (meme dedup) ou 422 si rien
de pertinent. Pas d'erreur 5xx sur un parse rate : on log + retourne success=false
pour que le mobile puisse decider d'afficher un fallback manuel.
"""
from fastapi import APIRouter, HTTPException, status

from app.deps import CurrentUserDep, DbDep, IngestionServiceDep
from app.schemas.ingestion import IngestResult, NotificationIngestIn

router = APIRouter()


@router.post(
    "/ingest", response_model=IngestResult, status_code=status.HTTP_200_OK
)
async def ingest_notification(
    payload: NotificationIngestIn,
    db: DbDep,
    user: CurrentUserDep,
    service: IngestionServiceDep,
) -> IngestResult:
    if not payload.raw_text.strip():
        raise HTTPException(
            status.HTTP_400_BAD_REQUEST, "raw_text vide"
        )
    return await service.ingest(db=db, user_id=user.id, payload=payload)
