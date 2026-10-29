from datetime import datetime, time
from zoneinfo import ZoneInfo

from ..models import DoseEvent, Medicine
from . import schedule as s


def _row(med, dt, key, ev, now):
    return {
        "_dt": dt, "id": key, "medicine_id": med.id,
        "medicine_name": med.name, "dosage": med.dosage,
        "instructions": med.instructions, "scheduled_at": dt.isoformat(),
        "outcome": ev.outcome if ev else None,
        "status": s.dose_status(dt, ev.outcome if ev else None, now),
        "recorded_at": ev.recorded_at.isoformat() + "Z" if ev else None,
    }


def public(rows):
    return [{k: v for k, v in r.items() if k != "_dt"} for r in rows]


def doses_in_range(start, end, tz, now, medicine_id=None):
    """Generated doses for active medicines + any recorded events in range
    (so history survives edits, pauses and deletes). Sorted by time."""
    if end < start or (end - start).days >= s.MAX_DAYS:
        raise s.ValidationError(f"Date range must be 1-{s.MAX_DAYS} days.")
    q = Medicine.query.filter(Medicine.deleted_at.is_(None),
                              Medicine.paused.is_(False))
    if medicine_id:
        q = q.filter(Medicine.id == medicine_id)
    meds = {m.id: m for m in q}
    gen = {}
    for m in meds.values():
        for d in s.generate_doses(m.gen_dict(), start, end, tz):
            gen[d["id"]] = d
    eq = DoseEvent.query.filter(DoseEvent.scheduled_date.between(start, end))
    if medicine_id:
        eq = eq.filter(DoseEvent.medicine_id == medicine_id)
    events = {e.dose_key: e for e in eq}
    rows = [_row(meds[d["medicine_id"]], d["scheduled_at"], k, events.get(k), now)
            for k, d in gen.items()]
    orphan = [e for k, e in events.items() if k not in gen]
    if orphan:
        owners = {m.id: m for m in Medicine.query.filter(
            Medicine.id.in_({e.medicine_id for e in orphan}))}
        zone = ZoneInfo(tz)
        for e in orphan:
            h, mi = map(int, e.scheduled_time.split(":"))
            dt = datetime.combine(e.scheduled_date, time(h, mi), tzinfo=zone)
            rows.append(_row(owners[e.medicine_id], dt, e.dose_key, e, now))
    rows.sort(key=lambda r: (r["_dt"], r["medicine_id"]))
    return rows
