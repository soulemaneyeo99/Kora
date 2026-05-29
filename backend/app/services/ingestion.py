"""Service d'ingestion de notifications : orchestre parser + creation de transaction.

Flux :
1. Selectionner un parser via le registre (package_source / hint).
2. Parser le texte -> ParsedNotification ou None (skip) ou ParseError.
3. Persister en Transaction avec source_ref pour idempotence.
4. Retourner une decision claire pour audit cote mobile.
"""
import logging
from uuid import UUID

from sqlalchemy.ext.asyncio import AsyncSession

from app.domain.transaction import Transaction
from app.schemas.ingestion import IngestResult, NotificationIngestIn, ParseDecision
from app.schemas.transaction import TransactionCreate
from app.services import transaction as tx_svc
from app.services.parsers import ParseError, ParserRegistry

logger = logging.getLogger(__name__)


class IngestionService:
    def __init__(self, registry: ParserRegistry) -> None:
        self._registry = registry

    async def ingest(
        self,
        *,
        db: AsyncSession,
        user_id: UUID,
        payload: NotificationIngestIn,
    ) -> IngestResult:
        parser = self._registry.find(
            package_source=payload.package_source, parser_hint=payload.parser_hint
        )
        if parser is None:
            return IngestResult(
                decision=ParseDecision(
                    success=False,
                    reason=f"Aucun parser pour la source {payload.package_source!r}",
                ),
                parser_name="none",
                parser_version="-",
            )

        try:
            parsed = parser.parse(
                title=payload.raw_title,
                text=payload.raw_text,
                captured_at=payload.captured_at,
                external_id=payload.external_id,
            )
        except ParseError as e:
            logger.info("ParseError %s/%s : %s", parser.name, parser.version, e)
            return IngestResult(
                decision=ParseDecision(success=False, reason=str(e)),
                parser_name=parser.name,
                parser_version=parser.version,
            )

        if parsed is None:
            return IngestResult(
                decision=ParseDecision(
                    success=False, reason="Notification non pertinente"
                ),
                parser_name=parser.name,
                parser_version=parser.version,
            )

        # Dedup : si une transaction avec ce source_ref existe deja, on la renvoie.
        existing: Transaction | None = await tx_svc.find_by_source_ref(
            db=db, user_id=user_id, source_ref=parsed.source_ref
        )
        if existing is not None:
            return IngestResult(
                decision=ParseDecision(
                    success=True, transaction_id=existing.id, reason="deja ingere"
                ),
                parser_name=parser.name,
                parser_version=parser.version,
                duplicate=True,
            )

        tx_in = TransactionCreate(
            amount_xof=parsed.amount_xof,
            kind=parsed.kind,
            occurred_at=parsed.occurred_at,
            description=parsed.description,
            counterparty=parsed.counterparty,
            source=parsed.source,
            source_ref=parsed.source_ref,
            category_id=None,  # categorisation manuelle pour l'instant
        )
        tx = await tx_svc.create_for_user(db=db, user_id=user_id, payload=tx_in)

        return IngestResult(
            decision=ParseDecision(success=True, transaction_id=tx.id),
            parser_name=parser.name,
            parser_version=parser.version,
            duplicate=False,
        )
