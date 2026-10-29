from datetime import datetime, timezone

from .extensions import db


def utcnow() -> datetime:
    return datetime.now(timezone.utc).replace(tzinfo=None)


class Medicine(db.Model):
    __tablename__ = "medicines"
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), nullable=False)
    dosage = db.Column(db.String(100), nullable=False)
    notes = db.Column(db.Text, default="", nullable=False)
    instructions = db.Column(db.String(200), default="", nullable=False)
    start_date = db.Column(db.Date, nullable=False)
    end_date = db.Column(db.Date)
    days_of_week = db.Column(db.JSON)  # None = every day; else [0..6], 0=Mon
    times = db.Column(db.JSON, nullable=False)  # ["08:00", ...]
    paused = db.Column(db.Boolean, default=False, nullable=False)
    is_demo = db.Column(db.Boolean, default=False, nullable=False, index=True)
    deleted_at = db.Column(db.DateTime, index=True)  # soft delete
    created_at = db.Column(db.DateTime, default=utcnow, nullable=False)

    def apply(self, clean: dict) -> None:
        self.name, self.dosage = clean["name"], clean["dosage"]
        self.notes, self.instructions = clean["notes"], clean["instructions"]
        self.start_date = datetime.fromisoformat(clean["start_date"]).date()
        self.end_date = (datetime.fromisoformat(clean["end_date"]).date()
                         if clean["end_date"] else None)
        self.days_of_week, self.times = clean["days_of_week"], clean["times"]

    def gen_dict(self) -> dict:
        return {"id": self.id, "start_date": self.start_date.isoformat(),
                "end_date": self.end_date.isoformat() if self.end_date else None,
                "days_of_week": self.days_of_week, "times": self.times,
                "paused": self.paused}

    def to_dict(self) -> dict:
        return {"id": self.id, "name": self.name, "dosage": self.dosage,
                "notes": self.notes, "instructions": self.instructions,
                "start_date": self.start_date.isoformat(),
                "end_date": self.end_date.isoformat() if self.end_date else None,
                "days_of_week": self.days_of_week, "times": self.times,
                "paused": self.paused, "is_demo": self.is_demo}


class DoseEvent(db.Model):
    """A recorded outcome (taken/skipped). Scheduled doses are generated on
    demand with stable ids; only outcomes are stored, so refreshing can never
    create duplicates. dose_key is unique."""
    __tablename__ = "dose_events"
    id = db.Column(db.Integer, primary_key=True)
    dose_key = db.Column(db.String(64), unique=True, nullable=False)
    medicine_id = db.Column(db.Integer, db.ForeignKey("medicines.id"),
                            nullable=False, index=True)
    scheduled_date = db.Column(db.Date, nullable=False, index=True)
    scheduled_time = db.Column(db.String(5), nullable=False)
    outcome = db.Column(db.String(10), nullable=False)
    recorded_at = db.Column(db.DateTime, default=utcnow, nullable=False)  # UTC
