import hashlib
import logging
import os
from datetime import datetime, time, timezone
from decimal import Decimal
from difflib import SequenceMatcher
from pathlib import Path
from typing import Optional
from uuid import UUID

import httpx
from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.auth import get_current_user
from app.core.database import get_db
from app.models.account import Account
from app.models.category import Category
from app.models.import_batch import ImportBatch
from app.models.transaction import Transaction
from app.models.user import User
from app.schemas.upload import (
    CommitImportRequest,
    CommitImportResponse,
    HistoryCoverageResponse,
    ParsedTransactionPreview,
    UploadResponse,
)
from app.services.document_router import process_document
from app.services.import_service import (
    build_transaction_fingerprint,
    classify_duplicate,
    normalize_description,
)
from app.services.parser_service import reconcile_balances
from app.services.history_coverage_service import (
    HistoryCoverage,
    get_history_coverage,
)
from app.services.file_validation_service import (
    InvalidStatementFile,
    validate_statement_file,
)

logger = logging.getLogger(__name__)
router = APIRouter()

MAX_UPLOAD_BYTES = 20 * 1024 * 1024
MAX_PARSED_ROWS = 5000
SUPPORTED_EXTENSIONS = {"pdf", "xlsx", "xls", "csv", "jpg", "jpeg", "png"}
PARSER_VERSION = "1.0"
ML_ENGINE_URL = os.getenv("ML_ENGINE_URL", "http://localhost:8001")
CATEGORY_TIMEOUT_SECONDS = float(os.getenv("CATEGORY_TIMEOUT_SECONDS", "5"))
KNOWN_CATEGORIES = {
    "Food & Dining",
    "Transport",
    "Shopping",
    "Entertainment",
    "Health",
    "Utilities",
    "Education",
    "Savings",
    "Income",
    "Festival",
    "Transfer",
    "Other",
}


async def get_category_suggestions(descriptions: list[str]) -> list[tuple[str, float]]:
    if not descriptions:
        return []
    try:
        async with httpx.AsyncClient(timeout=CATEGORY_TIMEOUT_SECONDS) as client:
            predictions = []
            for start in range(0, len(descriptions), 500):
                response = await client.post(
                    f"{ML_ENGINE_URL}/api/v1/predict-categories",
                    json={"raw_texts": descriptions[start:start + 500]},
                )
                response.raise_for_status()
                predictions.extend(response.json())
        suggestions = []
        for prediction in predictions:
            category = str(prediction.get("category", "Other"))
            if category not in KNOWN_CATEGORIES:
                category = "Other"
            confidence = min(1.0, max(0.0, float(prediction.get("confidence", 0))))
            suggestions.append((category, confidence))
        if len(suggestions) == len(descriptions):
            return suggestions
    except (httpx.HTTPError, TypeError, ValueError):
        logger.info("Category service unavailable; import review will use Other.")
    return [("Other", 0.0) for _ in descriptions]


def parse_date(value: Optional[str]) -> Optional[datetime]:
    if not value:
        return None
    formats = (
        "%Y-%m-%d %H:%M:%S",
        "%Y/%m/%d %H:%M:%S",
        "%Y-%m-%dT%H:%M:%S",
        "%Y-%m-%d",
        "%Y/%m/%d",
        "%d/%m/%Y",
        "%m/%d/%Y",
        "%d-%m-%Y",
        "%d-%m-%y",
        "%d/%m/%y",
        "%d %b %Y",
        "%d %B %Y",
    )
    for date_format in formats:
        try:
            return datetime.strptime(value.strip(), date_format)
        except ValueError:
            continue
    return None


def response_from_batch(batch: ImportBatch, *, file_reused: bool) -> UploadResponse:
    previews = [
        ParsedTransactionPreview.model_validate(item)
        for item in (batch.parsed_payload or [])
    ]
    return UploadResponse(
        batch_id=batch.id,
        account_id=batch.account_id,
        status=batch.status,
        file_reused=file_reused,
        transactions=previews,
        total_parsed=batch.total_parsed,
        new_count=batch.new_count,
        exact_duplicates=batch.exact_duplicate_count,
        possible_duplicates=batch.possible_duplicate_count,
        validation_errors=batch.validation_error_count,
        coverage_start_date=batch.coverage_start_date,
        coverage_end_date=batch.coverage_end_date,
        coverage_days=batch.coverage_days,
    )


def coverage_response(coverage: HistoryCoverage) -> HistoryCoverageResponse:
    return HistoryCoverageResponse(
        status=coverage.status,
        start_date=coverage.start_date,
        end_date=coverage.end_date,
        covered_days=coverage.covered_days,
        required_days=coverage.required_days,
        readiness_percentage=coverage.readiness_percentage,
        minimum_met=coverage.minimum_met,
        missing_days=coverage.missing_days,
        is_fresh=coverage.is_fresh,
        message=coverage.message,
    )


@router.get("/history-coverage", response_model=HistoryCoverageResponse)
async def history_coverage(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    coverage = await get_history_coverage(db, user_id=current_user.id)
    return coverage_response(coverage)


async def require_account(
    db: AsyncSession,
    *,
    account_id: UUID,
    user_id: UUID,
) -> Account:
    result = await db.execute(
        select(Account).where(
            Account.id == account_id,
            Account.user_id == user_id,
        )
    )
    account = result.scalars().first()
    if not account:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Account not found or access denied.",
        )
    return account


@router.post("/upload-statement", response_model=UploadResponse)
async def upload_statement(
    file: UploadFile = File(...),
    account_id: UUID = Form(...),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    await require_account(db, account_id=account_id, user_id=current_user.id)
    filename = Path(file.filename or "statement").name
    extension = filename.rsplit(".", 1)[-1].lower() if "." in filename else ""
    if extension not in SUPPORTED_EXTENSIONS:
        raise HTTPException(
            status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
            detail="Supported files are PDF, XLSX, XLS, CSV, JPG, JPEG, and PNG.",
        )

    try:
        file_bytes = await file.read(MAX_UPLOAD_BYTES + 1)
    finally:
        await file.close()

    if not file_bytes:
        raise HTTPException(status_code=400, detail="The uploaded file is empty.")
    if len(file_bytes) > MAX_UPLOAD_BYTES:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail="The maximum statement size is 20 MB.",
        )

    try:
        validate_statement_file(file_bytes, filename)
    except InvalidStatementFile as error:
        raise HTTPException(
            status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
            detail=str(error),
        ) from error

    file_hash = hashlib.sha256(file_bytes).hexdigest()
    existing_result = await db.execute(
        select(ImportBatch).where(
            ImportBatch.user_id == current_user.id,
            ImportBatch.account_id == account_id,
            ImportBatch.file_hash == file_hash,
        )
    )
    existing = existing_result.scalars().first()
    if existing:
        return response_from_batch(existing, file_reused=True)

    try:
        extracted_rows = await process_document(file_bytes, filename)
    except Exception as error:
        logger.exception("Document processing failed for %s", filename)
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"Failed to process the document: {error}",
        ) from error

    if not extracted_rows:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="No transaction rows could be extracted from this document.",
        )
    if len(extracted_rows) > MAX_PARSED_ROWS:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"A statement can contain at most {MAX_PARSED_ROWS} transaction rows.",
        )

    reconciliation_failures = set(reconcile_balances(extracted_rows))
    category_suggestions = await get_category_suggestions(
        [(row.description or row.raw_text or "").strip() for row in extracted_rows]
    )
    previews: list[ParsedTransactionPreview] = []
    seen_fingerprints: set[str] = set()
    seen_rows: list[tuple[datetime, Decimal, str, str]] = []

    for index, row in enumerate(extracted_rows):
        parsed_datetime = parse_date(row.date)
        description = (row.description or row.raw_text or "").strip()
        credit = Decimal(str(row.credit or 0))
        debit = Decimal(str(row.debit or 0))
        transaction_type = "credit" if credit > 0 else "debit"
        amount = credit if credit > 0 else debit
        messages: list[str] = []

        if parsed_datetime is None:
            messages.append("Date could not be parsed.")
        if amount <= 0:
            messages.append("A positive transaction amount is required.")
        if credit > 0 and debit > 0:
            messages.append("Both debit and credit values were detected.")
        if not description:
            messages.append("Description is missing.")
        if row.confidence < 0.75:
            messages.append("Low extraction confidence; please review this row.")
        if index in reconciliation_failures or index - 1 in reconciliation_failures:
            messages.append("Running balance could not be reconciled near this row.")

        fingerprint = None
        duplicate_status = "invalid" if any(
            message
            in {
                "Date could not be parsed.",
                "A positive transaction amount is required.",
                "Both debit and credit values were detected.",
                "Description is missing.",
            }
            for message in messages
        ) else "new"
        duplicate_of = None

        if duplicate_status != "invalid" and parsed_datetime is not None:
            fingerprint = build_transaction_fingerprint(
                account_id,
                parsed_datetime.date(),
                amount,
                transaction_type,
                description,
            )
            if fingerprint in seen_fingerprints:
                duplicate_status = "exact"
                messages.append("This transaction is repeated inside the uploaded file.")
            else:
                normalized_description = normalize_description(description)
                for seen_date, seen_amount, seen_type, seen_description in seen_rows:
                    if (
                        seen_date.date() == parsed_datetime.date()
                        and seen_amount == amount
                        and seen_type == transaction_type
                        and SequenceMatcher(
                            None,
                            normalized_description,
                            seen_description,
                        ).ratio()
                        >= 0.72
                    ):
                        duplicate_status = "possible"
                        messages.append(
                            "A similar transaction appears elsewhere in this file."
                        )
                        break
                if duplicate_status == "new":
                    duplicate_status, duplicate_of = await classify_duplicate(
                        db,
                        user_id=current_user.id,
                        account_id=account_id,
                        transaction_date=parsed_datetime.date(),
                        amount=amount,
                        transaction_type=transaction_type,
                        description=description,
                        fingerprint=fingerprint,
                    )
                if duplicate_status == "exact":
                    messages.append("This transaction was imported previously.")
                elif duplicate_status == "possible":
                    if not any("similar transaction" in item for item in messages):
                        messages.append(
                            "A similar transaction exists; confirm before importing."
                        )
            seen_fingerprints.add(fingerprint)
            seen_rows.append(
                (
                    parsed_datetime,
                    amount,
                    transaction_type,
                    normalize_description(description),
                )
            )

        previews.append(
            ParsedTransactionPreview(
                row_index=index,
                date=parsed_datetime.date() if parsed_datetime else None,
                type=transaction_type,
                amount=amount,
                clean_text=description,
                running_balance=(
                    Decimal(str(row.balance)) if row.balance is not None else None
                ),
                confidence=row.confidence,
                fingerprint=fingerprint,
                duplicate_status=duplicate_status,
                duplicate_of=duplicate_of,
                validation_messages=messages,
                suggested_category=category_suggestions[index][0],
                category_confidence=category_suggestions[index][1],
            )
        )

    coverage_dates = [item.date for item in previews if item.date is not None]
    coverage_start = min(coverage_dates) if coverage_dates else None
    coverage_end = max(coverage_dates) if coverage_dates else None
    batch = ImportBatch(
        user_id=current_user.id,
        account_id=account_id,
        file_hash=file_hash,
        original_filename=filename,
        parser_version=PARSER_VERSION,
        status="previewed",
        total_parsed=len(previews),
        new_count=sum(item.duplicate_status == "new" for item in previews),
        exact_duplicate_count=sum(
            item.duplicate_status == "exact" for item in previews
        ),
        possible_duplicate_count=sum(
            item.duplicate_status == "possible" for item in previews
        ),
        validation_error_count=sum(
            item.duplicate_status == "invalid" for item in previews
        ),
        parsed_payload=[
            item.model_dump(mode="json")
            for item in previews
        ],
        coverage_start_date=coverage_start,
        coverage_end_date=coverage_end,
        coverage_days=(
            (coverage_end - coverage_start).days + 1
            if coverage_start is not None and coverage_end is not None
            else 0
        ),
        coverage_verified=False,
    )
    db.add(batch)
    await db.commit()
    await db.refresh(batch)
    return response_from_batch(batch, file_reused=False)


@router.post(
    "/import-batches/{batch_id}/commit",
    response_model=CommitImportResponse,
)
async def commit_import_batch(
    batch_id: UUID,
    payload: CommitImportRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(ImportBatch)
        .where(
            ImportBatch.id == batch_id,
            ImportBatch.user_id == current_user.id,
        )
        .with_for_update()
    )
    batch = result.scalars().first()
    if not batch:
        raise HTTPException(status_code=404, detail="Import batch not found.")

    if batch.status == "completed":
        coverage = await get_history_coverage(db, user_id=current_user.id)
        return CommitImportResponse(
            batch_id=batch.id,
            status=batch.status,
            imported_count=batch.imported_count,
            duplicates_skipped=batch.skipped_count,
            excluded_count=max(
                0,
                batch.total_parsed - batch.imported_count - batch.skipped_count,
            ),
            history_coverage=coverage_response(coverage),
        )
    if batch.status != "previewed":
        raise HTTPException(
            status_code=409,
            detail=f"Import batch cannot be committed from status '{batch.status}'.",
        )

    account = await require_account(
        db,
        account_id=batch.account_id,
        user_id=current_user.id,
    )
    stored_rows = {
        int(item["row_index"]): item
        for item in (batch.parsed_payload or [])
    }
    requested_indices = [item.row_index for item in payload.rows]
    if len(requested_indices) != len(set(requested_indices)):
        raise HTTPException(status_code=400, detail="Duplicate row decisions supplied.")
    if any(index not in stored_rows for index in requested_indices):
        raise HTTPException(
            status_code=400,
            detail="One or more rows do not belong to this import batch.",
        )

    coverage_dates = [
        decision.date
        for decision in payload.rows
        if decision.date is not None
        and stored_rows[decision.row_index]["duplicate_status"] != "invalid"
    ]

    category_cache: dict[str, Optional[UUID]] = {}
    imported_count = 0
    duplicates_skipped = 0
    excluded_count = batch.total_parsed - len(payload.rows)
    net_balance_change = Decimal("0")

    for decision in payload.rows:
        stored = stored_rows[decision.row_index]
        if not decision.include:
            excluded_count += 1
            continue
        if stored["duplicate_status"] == "invalid":
            excluded_count += 1
            continue

        fingerprint = build_transaction_fingerprint(
            batch.account_id,
            decision.date,
            decision.amount,
            decision.type,
            decision.clean_text,
        )
        duplicate_status, _ = await classify_duplicate(
            db,
            user_id=current_user.id,
            account_id=batch.account_id,
            transaction_date=decision.date,
            amount=decision.amount,
            transaction_type=decision.type,
            description=decision.clean_text,
            fingerprint=fingerprint,
        )
        if duplicate_status == "exact":
            duplicates_skipped += 1
            continue

        category_id = None
        if decision.category_name:
            key = decision.category_name.strip().lower()
            if key not in category_cache:
                category_result = await db.execute(
                    select(Category).where(
                        Category.name.ilike(decision.category_name.strip())
                    )
                )
                category = category_result.scalars().first()
                category_cache[key] = category.id if category else None
            category_id = category_cache[key]

        confidence = float(stored.get("confidence", 1))
        transaction = Transaction(
            user_id=current_user.id,
            account_id=batch.account_id,
            category_id=category_id,
            amount=decision.amount,
            type=decision.type,
            date=decision.date,
            transaction_date=datetime.combine(decision.date, time.min),
            raw_text=stored.get("clean_text"),
            clean_text=decision.clean_text,
            transaction_text=decision.clean_text,
            is_manual_entry=False,
            ml_confidence_score=confidence,
            fingerprint=fingerprint,
            import_batch_id=batch.id,
            source_row_index=decision.row_index,
        )
        db.add(transaction)
        imported_count += 1
        if decision.type == "debit":
            net_balance_change -= decision.amount
        else:
            net_balance_change += decision.amount

    account.balance += net_balance_change
    batch.status = "completed"
    batch.imported_count = imported_count
    batch.skipped_count = duplicates_skipped
    batch.completed_at = datetime.now(timezone.utc)
    if coverage_dates:
        batch.coverage_start_date = min(coverage_dates)
        batch.coverage_end_date = max(coverage_dates)
        batch.coverage_days = (
            batch.coverage_end_date - batch.coverage_start_date
        ).days + 1
        batch.coverage_verified = True
    await db.commit()

    coverage = await get_history_coverage(db, user_id=current_user.id)

    return CommitImportResponse(
        batch_id=batch.id,
        status=batch.status,
        imported_count=imported_count,
        duplicates_skipped=duplicates_skipped,
        excluded_count=excluded_count,
        history_coverage=coverage_response(coverage),
    )
