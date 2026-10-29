from datetime import timedelta, timezone

from ..extensions import db
from ..models import DoseEvent, Medicine
from . import schedule as s

# Demonstration records only: real medicine names for realism, but the
# schedules are made up - NOT prescriptions or advice.
DEMO = [
    ("Vitamin D3 (demo)", "1 capsule", ["08:00"], "Demonstration data - not a prescription"),
    ("Metformin (demo)", "1 tablet", ["09:00", "21:00"], "Demonstration data - not a prescription"),
    ("Multivitamin syrup (demo)", "5 ml", ["14:00"], "Demonstration data - not a prescription"),
]


def clear_demo() -> int:
    ids = [m.id for m in Medicine.query.filter_by(is_demo=True)]
    if ids:
        DoseEvent.query.filter(DoseEvent.medicine_id.in_(ids)).delete(
            synchronize_session=False)
        Medicine.query.filter(Medicine.id.in_(ids)).delete(synchronize_session=False)
    return len(ids)


def load_demo(tz, now):
    clear_demo()  # idempotent: reloading never duplicates demo rows
    start = now.date() - timedelta(days=7)
    for name, dosage, times, note in DEMO:
        m = Medicine(is_demo=True)
        m.apply({"name": name, "dosage": dosage, "notes": note, "instructions": "",
                 "start_date": start.isoformat(), "end_date": None,
                 "days_of_week": None, "times": times})
        db.session.add(m)
        db.session.flush()
        past = [d for d in s.generate_doses(m.gen_dict(), start, now.date(), tz)
                if d["scheduled_at"] + timedelta(minutes=s.GRACE_MINUTES) <= now]
        for i, d in enumerate(past):
            if i % 6 == 5:
                continue  # left unrecorded -> shows as missed
            at = d["scheduled_at"]
            db.session.add(DoseEvent(
                dose_key=d["id"], medicine_id=m.id, scheduled_date=at.date(),
                scheduled_time=at.strftime("%H:%M"),
                outcome=s.SKIPPED if i % 6 == 4 else s.TAKEN,
                recorded_at=(at + timedelta(minutes=5)).astimezone(timezone.utc)
                .replace(tzinfo=None)))
