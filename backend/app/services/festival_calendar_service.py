import asyncio
import os
from dataclasses import dataclass
from datetime import date, datetime, timedelta, timezone
from typing import Iterable

import httpx


DEFAULT_CALENDAR_URL = (
    "https://calendar.google.com/calendar/ical/"
    "en.np%23holiday%40group.v.calendar.google.com/public/basic.ics"
)
CALENDAR_URL = os.getenv("NEPAL_HOLIDAY_ICS_URL", DEFAULT_CALENDAR_URL)
CACHE_TTL = timedelta(hours=12)


@dataclass(frozen=True)
class FestivalEvent:
    date: date
    name: str
    festival_type: str
    is_major: bool


@dataclass(frozen=True)
class FestivalSnapshot:
    events: tuple[FestivalEvent, ...]
    fetched_at: datetime | None
    source: str
    is_stale: bool


_snapshot = FestivalSnapshot((), None, CALENDAR_URL, True)
_refresh_lock = asyncio.Lock()


def _unfold_ics_lines(raw: str) -> Iterable[str]:
    current = ""
    for line in raw.replace("\r\n", "\n").split("\n"):
        if line.startswith((" ", "\t")):
            current += line[1:]
        else:
            if current:
                yield current
            current = line
    if current:
        yield current


def _festival_type(name: str) -> tuple[str, bool]:
    normalized = name.lower()
    groups = {
        "dashain": ("dashain", True),
        "tihar": ("tihar", True),
        "chhat": ("chhath", True),
        "chhath": ("chhath", True),
        "holi": ("holi", True),
        "teej": ("teej", True),
        "new year": ("new_year", True),
        "losar": ("losar", False),
        "janai purnima": ("janai_purnima", False),
        "buddha jayanti": ("buddha_jayanti", False),
        "eid": ("eid", False),
        "edul": ("eid", False),
        "christmas": ("christmas", False),
    }
    for keyword, result in groups.items():
        if keyword in normalized:
            return result
    return "holiday", False


def parse_ics_events(raw: str) -> tuple[FestivalEvent, ...]:
    events: list[FestivalEvent] = []
    event_date: date | None = None
    summary: str | None = None
    in_event = False

    for line in _unfold_ics_lines(raw):
        if line == "BEGIN:VEVENT":
            in_event = True
            event_date = None
            summary = None
        elif line == "END:VEVENT":
            if in_event and event_date and summary:
                clean_summary = (
                    summary.replace("\\,", ",")
                    .replace("\\n", " ")
                    .replace("\\;", ";")
                    .strip()
                )
                festival_type, is_major = _festival_type(clean_summary)
                events.append(
                    FestivalEvent(
                        date=event_date,
                        name=clean_summary,
                        festival_type=festival_type,
                        is_major=is_major,
                    )
                )
            in_event = False
        elif in_event and line.startswith("DTSTART"):
            try:
                event_date = datetime.strptime(line.split(":", 1)[1][:8], "%Y%m%d").date()
            except (IndexError, ValueError):
                event_date = None
        elif in_event and line.startswith("SUMMARY:"):
            summary = line.split(":", 1)[1]

    return tuple(sorted(events, key=lambda item: (item.date, item.name)))


async def get_festival_snapshot(*, force_refresh: bool = False) -> FestivalSnapshot:
    global _snapshot
    now = datetime.now(timezone.utc)
    if (
        not force_refresh
        and _snapshot.fetched_at is not None
        and now - _snapshot.fetched_at < CACHE_TTL
    ):
        return _snapshot

    async with _refresh_lock:
        now = datetime.now(timezone.utc)
        if (
            not force_refresh
            and _snapshot.fetched_at is not None
            and now - _snapshot.fetched_at < CACHE_TTL
        ):
            return _snapshot
        try:
            async with httpx.AsyncClient(timeout=5.0, follow_redirects=True) as client:
                response = await client.get(CALENDAR_URL)
                response.raise_for_status()
            events = parse_ics_events(response.text)
            if not events:
                raise ValueError("The Nepal holiday calendar contained no events.")
            _snapshot = FestivalSnapshot(events, now, CALENDAR_URL, False)
        except (httpx.HTTPError, ValueError):
            _snapshot = FestivalSnapshot(
                _snapshot.events,
                _snapshot.fetched_at,
                CALENDAR_URL,
                True,
            )
        return _snapshot


async def get_festival_events(
    start_date: date,
    end_date: date,
) -> tuple[FestivalEvent, ...]:
    snapshot = await get_festival_snapshot()
    return tuple(
        event for event in snapshot.events if start_date <= event.date <= end_date
    )
