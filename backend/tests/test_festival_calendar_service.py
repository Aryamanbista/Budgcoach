from datetime import date

from app.services.festival_calendar_service import parse_ics_events


def test_parse_nepal_festival_calendar_unfolds_and_classifies_events():
    raw = """BEGIN:VCALENDAR
BEGIN:VEVENT
DTSTART;VALUE=DATE:20261019
SUMMARY:Astami (Dashain)
END:VEVENT
BEGIN:VEVENT
DTSTART;VALUE=DATE:20261109
SUMMARY:Laxmi Puja (Ti
 har)
END:VEVENT
END:VCALENDAR
"""

    events = parse_ics_events(raw)

    assert [event.date for event in events] == [date(2026, 10, 19), date(2026, 11, 9)]
    assert events[0].festival_type == "dashain"
    assert events[0].is_major is True
    assert events[1].name == "Laxmi Puja (Tihar)"
    assert events[1].festival_type == "tihar"
