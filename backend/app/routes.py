from datetime import date, datetime, timedelta
from zoneinfo import ZoneInfo

from flask import Blueprint, current_app, jsonify, request
from sqlalchemy.exc import IntegrityError

from .extensions import db
from .models import DoseEvent, Medicine, utcnow
from .services import schedule as s
from .services.demo import clear_demo, load_demo
from .services.doses import doses_in_range, public

bp = Blueprint("api", __name__)


class ApiError(Exception):
    def __init__(self, code, message, status, fields=None):
        self.code, self.message, self.status, self.fields = code, message, status, fields


def err(code, message, status, fields=None):
    body = {"code": code, "message": message}
    if fields:
        body["fields"] = fields
    return jsonify({"error": body}), status


def register_errors(app):
    @app.errorhandler(ApiError)
    def _api(e):
        return err(e.code, e.message, e.status, e.fields)

    @app.errorhandler(s.ValidationError)
    def _val(e):
        return err("validation_error", str(e), 422, getattr(e, "errors", None))

    @app.errorhandler(404)
    def _404(_):
        return err("not_found", "Resource not found.", 404)

    @app.errorhandler(405)
    def _405(_):
        return err("method_not_allowed", "Method not allowed.", 405)

    @app.errorhandler(Exception)
    def _500(e):
        db.session.rollback()
        current_app.logger.exception(e)
        return err("server_error", "Unexpected server error.", 500)


# ---- helpers -------------------------------------------------------------
def tz():
    return current_app.config["TIMEZONE"]


def now():
    f = current_app.config.get("NOW")  # injectable clock for tests
    return f() if f else datetime.now(ZoneInfo(tz()))


def body():
    data = request.get_json(silent=True)
    if not isinstance(data, dict):
        raise ApiError("invalid_json", "Request body must be a JSON object.", 400)
    return data


def parse_date(value, name):
    try:
        return date.fromisoformat(value)
    except (TypeError, ValueError):
        raise ApiError("validation_error", f"'{name}' must be YYYY-MM-DD.", 422,
                       {name: "Use YYYY-MM-DD."})


def get_med(mid):
    m = db.session.get(Medicine, mid)
    if m is None or m.deleted_at is not None:
        raise ApiError("not_found", "Medicine not found.", 404)
    return m


def range_args():
    to = parse_date(request.args.get("to", now().date().isoformat()), "to")
    frm = parse_date(request.args.get("from", (to - timedelta(days=6)).isoformat()), "from")
    mid = request.args.get("medicine_id", type=int)
    return frm, to, mid


# ---- endpoints -----------------------------------------------------------
@bp.get("/health")
def health():
    db.session.execute(db.text("SELECT 1"))
    return jsonify({"status": "ok", "time": now().isoformat(), "timezone": tz()})


@bp.get("/medicines")
def list_medicines():
    ms = Medicine.query.filter(Medicine.deleted_at.is_(None)).order_by(Medicine.name)
    return jsonify([m.to_dict() for m in ms])


@bp.post("/medicines")
def create_medicine():
    m = Medicine()
    m.apply(s.validate_medicine(body()))
    db.session.add(m)
    db.session.commit()
    return jsonify(m.to_dict()), 201


@bp.get("/medicines/<int:mid>")
def get_medicine(mid):
    m, n = get_med(mid), now()
    today = n.date()
    upcoming = [r for r in doses_in_range(today, today + timedelta(days=6), tz(), n, mid)
                if r["status"] in (s.UPCOMING, s.DUE)]
    recent = [r for r in doses_in_range(today - timedelta(days=6), today, tz(), n, mid)
              if r["status"] not in (s.UPCOMING, s.DUE)]
    return jsonify({**m.to_dict(), "upcoming": public(upcoming)[:10],
                    "recent": public(recent)[-10:]})


@bp.put("/medicines/<int:mid>")
def update_medicine(mid):
    m = get_med(mid)
    m.apply(s.validate_medicine(body()))  # recorded events are never touched
    db.session.commit()
    return jsonify(m.to_dict())


@bp.delete("/medicines/<int:mid>")
def delete_medicine(mid):
    m = get_med(mid)
    m.deleted_at = utcnow()  # soft delete: history is preserved
    db.session.commit()
    return "", 204


@bp.post("/medicines/<int:mid>/pause")
def pause(mid):
    m = get_med(mid)
    m.paused = True
    db.session.commit()
    return jsonify(m.to_dict())


@bp.post("/medicines/<int:mid>/resume")
def resume(mid):
    m = get_med(mid)
    m.paused = False
    db.session.commit()
    return jsonify(m.to_dict())


@bp.get("/doses")
def doses_for_day():
    day = parse_date(request.args.get("date", now().date().isoformat()), "date")
    return jsonify(public(doses_in_range(day, day, tz(), now())))


def _find_dose(key):
    parts = (key or "").split("|")
    try:
        mid, day = int(parts[0]), date.fromisoformat(parts[1])
        if len(parts) != 3 or len(parts[2]) != 5:
            raise ValueError
    except (ValueError, IndexError):
        raise ApiError("validation_error", "Invalid dose_id.", 422, {"dose_id": "Invalid."})
    return mid, day, parts[2]


@bp.post("/doses/record")
def record_dose():
    data = body()
    key, outcome = data.get("dose_id"), data.get("outcome")
    if outcome not in (s.TAKEN, s.SKIPPED):
        raise ApiError("validation_error", "outcome must be 'taken' or 'skipped'.", 422,
                       {"outcome": "Use 'taken' or 'skipped'."})
    mid, day, hhmm = _find_dose(key)
    n = now()
    if day > n.date():
        raise ApiError("future_dose", "Doses on future dates cannot be recorded yet.", 422)
    m = get_med(mid)
    if m.paused:
        raise ApiError("paused", "Resume this medicine to record doses.", 409)
    if key not in {d["id"] for d in s.generate_doses(m.gen_dict(), day, day, tz())}:
        raise ApiError("not_scheduled", "No such scheduled dose.", 404)
    ev = DoseEvent.query.filter_by(dose_key=key).first()
    try:
        action = s.can_record(ev.outcome if ev else None, outcome)
    except ValueError as e:
        raise ApiError("invalid_transition", str(e), 409)
    if action == "apply":
        db.session.add(DoseEvent(dose_key=key, medicine_id=mid, scheduled_date=day,
                                 scheduled_time=hhmm, outcome=outcome))
        try:
            db.session.commit()
        except IntegrityError:  # concurrent duplicate request: treat as no-op
            db.session.rollback()
    row = [r for r in doses_in_range(day, day, tz(), n, mid) if r["id"] == key][0]
    return jsonify(public([row])[0])


@bp.post("/doses/undo")
def undo_dose():
    key = body().get("dose_id")
    _find_dose(key)
    ev = DoseEvent.query.filter_by(dose_key=key).first()
    if ev is None:
        raise ApiError("not_found", "No recorded outcome for this dose.", 404)
    db.session.delete(ev)
    db.session.commit()
    return jsonify({"dose_id": key, "outcome": None})


@bp.get("/history")
def history():
    frm, to, mid = range_args()
    rows = [r for r in doses_in_range(frm, to, tz(), now(), mid)
            if r["status"] != s.UPCOMING]
    return jsonify({"doses": public(rows), "adherence": _adherence(rows)})


@bp.get("/adherence")
def adherence():
    frm, to, mid = range_args()
    rows = doses_in_range(frm, to, tz(), now(), mid)
    by_day = {}
    for r in rows:
        by_day.setdefault(r["_dt"].date().isoformat(), []).append(r)
    return jsonify({"overall": _adherence(rows),
                    "by_day": {d: _adherence(v) for d, v in sorted(by_day.items())},
                    "definition": "taken / (taken + skipped + missed); "
                                  "upcoming and due doses are excluded."})


def _adherence(rows):
    return s.adherence([{"scheduled_at": r["_dt"], "outcome": r["outcome"]} for r in rows], now())


@bp.post("/demo/load")
def demo_load():
    load_demo(tz(), now())
    db.session.commit()
    return jsonify({"loaded": True}), 201


@bp.delete("/demo")
def demo_clear():
    n = clear_demo()
    db.session.commit()
    return jsonify({"removed_medicines": n})
