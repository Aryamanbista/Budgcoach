from dataclasses import dataclass
from datetime import date, timedelta
from typing import Literal
from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.import_batch import ImportBatch
from app.models.transaction import Transaction


CoverageStatus = Literal["verified", "estimated", "none"]
REQUIRED_HISTORY_DAYS = 30
HISTORY_LOOKBACK_DAYS = 90


@dataclass(frozen=True)
class HistoryCoverage:
    status: CoverageStatus
    start_date: date | None
    end_date: date | None
    covered_days: int
    required_days: int
    readiness_percentage: float
    minimum_met: bool
    missing_days: int
    is_fresh: bool
    message: str


def _merge_intervals(intervals: list[tuple[date, date]]) -> list[tuple[date, date]]:
    merged: list[tuple[date, date]] = []
    for start_date, end_date in sorted(intervals):
        if not merged or start_date > merged[-1][1] + timedelta(days=1):
            merged.append((start_date, end_date))
            continue
        previous_start, previous_end = merged[-1]
        merged[-1] = (previous_start, max(previous_end, end_date))
    return merged


def _build_coverage(
    *,
    status: CoverageStatus,
    start_date: date | None,
    end_date: date | None,
    covered_days: int,
    today: date,
) -> HistoryCoverage:
    covered_days = max(0, covered_days)
    missing_days = max(0, REQUIRED_HISTORY_DAYS - covered_days)
    readiness = min(100.0, covered_days / REQUIRED_HISTORY_DAYS * 100)
    is_fresh = end_date is not None and (today - end_date).days <= 3

    if status == "none":
        message = "Upload your latest 30-day statement to build a personal baseline."
    elif covered_days < REQUIRED_HISTORY_DAYS:
        qualifier = "verified" if status == "verified" else "estimated"
        message = (
            f"{covered_days} {qualifier} days available. Add {missing_days} more "
            "consecutive days for the personal AI forecast."
        )
    elif not is_fresh:
        message = (
            "Your 30-day baseline is ready, but recent activity is missing. "
            "Upload a current statement to refresh it."
        )
    else:
        message = "Your verified 30-day personal baseline is ready."

    return HistoryCoverage(
        status=status,
        start_date=start_date,
        end_date=end_date,
        covered_days=covered_days,
        required_days=REQUIRED_HISTORY_DAYS,
        readiness_percentage=round(readiness, 1),
        minimum_met=covered_days >= REQUIRED_HISTORY_DAYS,
        missing_days=missing_days,
        is_fresh=is_fresh,
        message=message,
    )


async def get_history_coverage(
    db: AsyncSession,
    *,
    user_id: UUID,
    today: date | None = None,
) -> HistoryCoverage:
    today = today or date.today()
    cutoff = today - timedelta(days=HISTORY_LOOKBACK_DAYS - 1)
    result = await db.execute(
        select(
            ImportBatch.coverage_start_date,
            ImportBatch.coverage_end_date,
        ).where(
            ImportBatch.user_id == user_id,
            ImportBatch.status == "completed",
            ImportBatch.coverage_verified.is_(True),
            ImportBatch.coverage_start_date.is_not(None),
            ImportBatch.coverage_end_date.is_not(None),
            ImportBatch.coverage_end_date >= cutoff,
        )
    )
    intervals = []
    for start_date, end_date in result.all():
        clipped_start = max(start_date, cutoff)
        clipped_end = min(end_date, today)
        if clipped_start <= clipped_end:
            intervals.append((clipped_start, clipped_end))

    merged = _merge_intervals(intervals)
    if merged:
        # Readiness requires the most recent uninterrupted statement coverage;
        # disjoint older ranges are useful for analysis but cannot fill a gap.
        latest_start, latest_end = merged[-1]
        covered_days = (latest_end - latest_start).days + 1
        return _build_coverage(
            status="verified",
            start_date=latest_start,
            end_date=latest_end,
            covered_days=covered_days,
            today=today,
        )

    legacy_result = await db.execute(
        select(func.min(Transaction.date), func.max(Transaction.date)).where(
            Transaction.user_id == user_id,
            Transaction.date >= cutoff,
            Transaction.date <= today,
        )
    )
    first_date, last_date = legacy_result.one()
    if first_date is None or last_date is None:
        return _build_coverage(
            status="none",
            start_date=None,
            end_date=None,
            covered_days=0,
            today=today,
        )

    return _build_coverage(
        status="estimated",
        start_date=first_date,
        end_date=last_date,
        covered_days=(last_date - first_date).days + 1,
        today=today,
    )
