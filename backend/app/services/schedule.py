"""MedMinder scheduling core (stdlib only, framework independent).

Rules implemented here (and mirrored in docs):
* Times are wall-clock times in the user's IANA timezone.
* A dose has a stable id: "<medicine_id>|<YYYY-MM-DD>|<HH:MM>", so regenerating
  a schedule never creates duplicates and outcomes can be attached idempotently.
* Status: taken / skipped (recorded outcomes) > missed (no outcome and
  scheduled time + grace has passed) > due (inside grace window) > upcoming.
* Adherence = taken / (taken + skipped + missed). Upcoming/due doses are
  excluded, so future doses are never counted as missed.
* Generation is capped (MAX_DAYS) to avoid unbounded dose creation.
"""
from __future__ import annotations

import re
from datetime import date, datetime, time, timedelta
from zoneinfo import ZoneInfo

MAX_DAYS = 60
GRACE_MINUTES = 60
_TIME_RE = re.compile(r"^([01]\d|2[0-3]):([0-5]\d)$")

TAKEN, SKIPPED, MISSED, DUE, UPCOMING = "taken", "skipped", "missed", "due", "upcoming"


class ValidationError(ValueError):
    pass


def validate_medicine(data: dict) -> dict:
    """Return a cleaned copy of a medicine payload or raise ValidationError."""
    errors = {}
    name = (data.get("name") or "").strip()
    dosage = (data.get("dosage") or "").strip()
    if not name:
        errors["name"] = "Name is required."
    elif len(name) > 100:
        errors["name"] = "Name must be 100 characters or fewer."
    if not dosage:
        errors["dosage"] = "Dosage is required (e.g. '1 tablet')."

    times = data.get("times") or []
    if not times:
        errors["times"] = "At least one reminder time is required."
    elif not all(isinstance(t, str) and _TIME_RE.match(t) for t in times):
        errors["times"] = "Times must be in 24-hour HH:MM format."
    elif len(set(times)) != len(times):
        errors["times"] = "Duplicate reminder times are not allowed."

    days = data.get("days_of_week")
    if days is not None and (
        not days or not all(isinstance(d, int) and 0 <= d <= 6 for d in days)
    ):
        errors["days_of_week"] = "Use integers 0 (Mon) to 6 (Sun), or omit for daily."

    start = end = None
    try:
        start = date.fromisoformat(data.get("start_date", ""))
    except (TypeError, ValueError):
        errors["start_date"] = "Start date must be YYYY-MM-DD."
    if data.get("end_date"):
        try:
            end = date.fromisoformat(data["end_date"])
        except (TypeError, ValueError):
            errors["end_date"] = "End date must be YYYY-MM-DD."
    if start and end and end < start:
        errors["end_date"] = "End date cannot be before start date."

    if errors:
        e = ValidationError("Validation failed")
        e.errors = errors
        raise e
    return {
        "name": name, "dosage": dosage, "notes": (data.get("notes") or "").strip(),
        "instructions": (data.get("instructions") or "").strip(),
        "start_date": start.isoformat(), "end_date": end.isoformat() if end else None,
        "days_of_week": sorted(set(days)) if days is not None else None,
        "times": sorted(times),
    }


def dose_id(medicine_id, day: date, hhmm: str) -> str:
    return f"{medicine_id}|{day.isoformat()}|{hhmm}"


def generate_doses(med: dict, start: date, end: date, tz: str = "UTC") -> list[dict]:
    """Doses for an active medicine between start and end (inclusive).

    `med` needs: id, start_date, end_date, days_of_week, times, paused.
    Paused medicines generate nothing (history is kept elsewhere).
    """
    if med.get("paused") or end < start:
        return []
    end = min(end, start + timedelta(days=MAX_DAYS - 1))
    zone = ZoneInfo(tz)
    m_start = date.fromisoformat(med["start_date"])
    m_end = date.fromisoformat(med["end_date"]) if med.get("end_date") else None
    out = []
    day = max(start, m_start)
    while day <= end:
        if (m_end is None or day <= m_end) and (
            med.get("days_of_week") is None or day.weekday() in med["days_of_week"]
        ):
            for hhmm in sorted(med["times"]):
                h, m = map(int, hhmm.split(":"))
                # Non-existent local times (DST gap) are shifted forward by the
                # zone rules; ambiguous ones use the first occurrence (fold=0).
                sched = datetime.combine(day, time(h, m), tzinfo=zone)
                out.append({"id": dose_id(med["id"], day, hhmm),
                            "medicine_id": med["id"], "scheduled_at": sched})
        day += timedelta(days=1)
    return out


def dose_status(scheduled_at: datetime, outcome: str | None, now: datetime,
                grace_minutes: int = GRACE_MINUTES) -> str:
    if outcome in (TAKEN, SKIPPED):
        return outcome
    if outcome is not None:
        raise ValueError(f"Unknown outcome: {outcome}")
    if now < scheduled_at:
        return UPCOMING
    if now < scheduled_at + timedelta(minutes=grace_minutes):
        return DUE
    return MISSED


def can_record(current: str | None, new: str) -> str:
    """Idempotent transition rule. Returns 'apply', 'noop' or raises.

    Recording the same outcome twice is a no-op (no duplicate completion);
    switching taken<->skipped requires an explicit correction (undo first).
    """
    if new not in (TAKEN, SKIPPED):
        raise ValueError("Outcome must be 'taken' or 'skipped'.")
    if current is None:
        return "apply"
    if current == new:
        return "noop"
    raise ValueError("Dose already recorded; undo it before changing the outcome.")


def adherence(doses: list[dict], now: datetime) -> dict:
    """doses: [{'scheduled_at': dt, 'outcome': str|None}, ...]"""
    c = {TAKEN: 0, SKIPPED: 0, MISSED: 0}
    for d in doses:
        s = dose_status(d["scheduled_at"], d.get("outcome"), now)
        if s in c:
            c[s] += 1
    denom = sum(c.values())
    return {**c, "denominator": denom,
            "percentage": round(100 * c[TAKEN] / denom, 1) if denom else None}
