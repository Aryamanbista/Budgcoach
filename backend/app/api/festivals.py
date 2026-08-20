from datetime import date, timedelta

from fastapi import APIRouter, Query
from pydantic import BaseModel

from app.services.festival_calendar_service import get_festival_snapshot


router = APIRouter()


class FestivalEventResponse(BaseModel):
    date: date
    name: str
    festival_type: str
    is_major: bool


class FestivalCalendarResponse(BaseModel):
    start_date: date
    end_date: date
    source: str
    is_stale: bool
    events: list[FestivalEventResponse]


@router.get("/", response_model=FestivalCalendarResponse)
async def list_festivals(
    start_date: date | None = Query(None),
    end_date: date | None = None,
):
    start_date = start_date or date.today()
    end_date = end_date or (start_date + timedelta(days=120))
    if end_date < start_date:
        end_date = start_date
    snapshot = await get_festival_snapshot()
    events = [
        FestivalEventResponse(
            date=event.date,
            name=event.name,
            festival_type=event.festival_type,
            is_major=event.is_major,
        )
        for event in snapshot.events
        if start_date <= event.date <= end_date
    ]
    return FestivalCalendarResponse(
        start_date=start_date,
        end_date=end_date,
        source=snapshot.source,
        is_stale=snapshot.is_stale,
        events=events,
    )
