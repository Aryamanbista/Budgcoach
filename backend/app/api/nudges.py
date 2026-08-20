from datetime import datetime, timedelta, timezone
from typing import List
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.auth import get_current_user
from app.core.database import get_db
from app.models.nudge import Nudge
from app.models.user import User
from app.schemas.nudge import NudgeOut
from app.services.nudge_service import build_personalized_nudges, persist_candidates

router = APIRouter()


@router.get("/", response_model=List[NudgeOut])
async def get_nudges(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Generate and return user-specific active nudges and 30-day history."""
    candidates = await build_personalized_nudges(db, user_id=current_user.id)
    current_rows = await persist_candidates(
        db,
        user_id=current_user.id,
        candidates=candidates,
    )

    current_ids = {row.id for row in current_rows}
    history_since = datetime.now(timezone.utc) - timedelta(days=30)
    history_result = await db.execute(
        select(Nudge).where(
            Nudge.user_id == current_user.id,
            Nudge.dismissed_at.is_not(None),
            Nudge.dismissed_at >= history_since,
        )
    )
    historical_rows = [
        row for row in history_result.scalars().all() if row.id not in current_ids
    ]

    return sorted(
        [*current_rows, *historical_rows],
        key=lambda row: (
            row.dismissed_at is None,
            row.priority,
            row.generated_at,
        ),
        reverse=True,
    )


@router.patch("/{nudge_id}/dismiss", response_model=NudgeOut)
async def dismiss_nudge(
    nudge_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Nudge).where(
            Nudge.id == nudge_id,
            Nudge.user_id == current_user.id,
        )
    )
    nudge = result.scalars().first()
    if nudge is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Nudge not found or access denied.",
        )

    if nudge.dismissed_at is None:
        nudge.dismissed_at = datetime.now(timezone.utc)
        await db.commit()

    return nudge
