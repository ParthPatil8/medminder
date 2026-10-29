from datetime import datetime
from zoneinfo import ZoneInfo

import pytest

from app import create_app

NOW = datetime(2026, 10, 28, 12, 0, tzinfo=ZoneInfo("Asia/Kolkata"))
MED = {"name": "Vitamin D", "dosage": "1 capsule", "times": ["08:00", "20:00"],
       "start_date": "2026-10-20"}
K_AM, K_PM = "{}|2026-10-28|08:00", "{}|2026-10-28|20:00"


def make_app(path):
    return create_app({"SQLALCHEMY_DATABASE_URI": f"sqlite:///{path}",
                       "TESTING": True, "NOW": lambda: NOW})


@pytest.fixture
def db_path(tmp_path):
    return tmp_path / "t.db"


@pytest.fixture
def client(db_path):
    return make_app(db_path).test_client()


def add(client, **kw):
    r = client.post("/api/medicines", json={**MED, **kw})
    assert r.status_code == 201, r.get_json()
    return r.get_json()["id"]


def record(client, key, outcome):
    return client.post("/api/doses/record", json={"dose_id": key, "outcome": outcome})


def test_health(client):
    assert client.get("/api/health").get_json()["status"] == "ok"


def test_validation_error_shape(client):
    r = client.post("/api/medicines", json={**MED, "name": ""})
    assert r.status_code == 422
    assert "name" in r.get_json()["error"]["fields"]


def test_invalid_json(client):
    assert client.post("/api/medicines", data="nope").status_code == 400


def test_crud_and_soft_delete(client):
    mid = add(client)
    assert client.get(f"/api/medicines/{mid}").status_code == 200
    r = client.put(f"/api/medicines/{mid}", json={**MED, "name": "Vit D3"})
    assert r.get_json()["name"] == "Vit D3"
    assert client.delete(f"/api/medicines/{mid}").status_code == 204
    assert client.get(f"/api/medicines/{mid}").status_code == 404
    assert client.get("/api/medicines").get_json() == []


def test_daily_statuses_use_clock(client):
    add(client)
    rows = client.get("/api/doses?date=2026-10-28").get_json()
    assert [r["status"] for r in rows] == ["missed", "upcoming"]


def test_record_is_idempotent_and_conflicts(client):
    key = K_AM.format(add(client))
    first = record(client, key, "taken").get_json()
    second = record(client, key, "taken").get_json()
    assert first["recorded_at"] == second["recorded_at"]
    assert first["status"] == "taken"
    assert record(client, key, "skipped").status_code == 409
    client.post("/api/doses/undo", json={"dose_id": key})
    assert record(client, key, "skipped").get_json()["status"] == "skipped"


def test_future_and_unscheduled_rejected(client):
    mid = add(client)
    assert record(client, f"{mid}|2026-10-29|08:00", "taken").status_code == 422
    assert record(client, f"{mid}|2026-10-28|10:00", "taken").status_code == 404
    assert record(client, K_AM.format(mid), "maybe").status_code == 422


def test_pause_and_delete_preserve_history(client):
    mid = add(client)
    record(client, K_AM.format(mid), "taken")
    client.post(f"/api/medicines/{mid}/pause")
    rows = client.get("/api/doses?date=2026-10-28").get_json()
    assert [r["status"] for r in rows] == ["taken"]  # recorded dose stays; 20:00 is gone
    hist = client.get("/api/history?from=2026-10-28&to=2026-10-28").get_json()
    assert [d["status"] for d in hist["doses"]] == ["taken"]
    client.delete(f"/api/medicines/{mid}")
    hist = client.get("/api/history?from=2026-10-28&to=2026-10-28").get_json()
    assert len(hist["doses"]) == 1


def test_adherence_excludes_future(client):
    mid = add(client)
    record(client, K_AM.format(mid), "taken")
    a = client.get("/api/adherence?from=2026-10-28&to=2026-10-28").get_json()["overall"]
    assert (a["taken"], a["missed"], a["denominator"], a["percentage"]) == (1, 0, 1, 100.0)


def test_demo_load_and_clear_keep_real_data(client):
    real = add(client, name="My real record")
    assert client.post("/api/demo/load").status_code == 201
    assert client.post("/api/demo/load").status_code == 201  # no duplicates
    assert len(client.get("/api/medicines").get_json()) == 4
    assert client.get("/api/history").get_json()["doses"]
    assert client.delete("/api/demo").get_json()["removed_medicines"] == 3
    meds = client.get("/api/medicines").get_json()
    assert [m["id"] for m in meds] == [real]


def test_data_persists_across_restart(db_path):
    c1 = make_app(db_path).test_client()
    mid = add(c1)
    record(c1, K_AM.format(mid), "taken")
    c2 = make_app(db_path).test_client()  # "restart"
    assert c2.get("/api/medicines").get_json()[0]["id"] == mid
    assert c2.get("/api/doses?date=2026-10-28").get_json()[0]["status"] == "taken"
