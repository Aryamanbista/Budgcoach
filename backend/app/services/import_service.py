import hashlib
import re
import unicodedata
from datetime import date
from decimal import Decimal
from difflib import SequenceMatcher
from typing import Optional
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.transaction import Transaction


def normalize_description(value: str) -> str:
    normalized = unicodedata.normalize("NFKC", value or "").lower()
    normalized = re.sub(r"[^a-z0-9]+", " ", normalized)
    return " ".join(normalized.split())


def build_transaction_fingerprint(
    account_id: UUID,
    transaction_date: date,
    amount: Decimal,
    transaction_type: str,
    description: str,
) -> str:
    canonical_amount = Decimal(amount).quantize(Decimal("0.01"))
    canonical = "|".join(
        (
            str(account_id),
            transaction_date.isoformat(),
            f"{canonical_amount:.2f}",
            transaction_type.strip().lower(),
            normalize_description(description),
        )
    )
    return hashlib.sha256(canonical.encode("utf-8")).hexdigest()


async def classify_duplicate(
    db: AsyncSession,
    *,
    user_id: UUID,
    account_id: UUID,
    transaction_date: date,
    amount: Decimal,
    transaction_type: str,
    description: str,
    fingerprint: str,
) -> tuple[str, Optional[UUID]]:
    exact_result = await db.execute(
        select(Transaction).where(
            Transaction.user_id == user_id,
            Transaction.account_id == account_id,
            Transaction.fingerprint == fingerprint,
        )
    )
    exact = exact_result.scalars().first()
    if exact:
        return "exact", exact.id

    candidates_result = await db.execute(
        select(Transaction).where(
            Transaction.user_id == user_id,
            Transaction.account_id == account_id,
            Transaction.date == transaction_date,
            Transaction.amount == amount,
            Transaction.type == transaction_type,
        )
    )
    normalized = normalize_description(description)
    for candidate in candidates_result.scalars().all():
        candidate_text = normalize_description(
            candidate.clean_text
            or candidate.transaction_text
            or candidate.raw_text
            or ""
        )
        if candidate_text == normalized:
            return "exact", candidate.id
        similarity = SequenceMatcher(None, normalized, candidate_text).ratio()
        if not normalized or not candidate_text or similarity >= 0.72:
            return "possible", candidate.id

    return "new", None
