import sys, unittest
from datetime import date, datetime, timedelta
from pathlib import Path
from zoneinfo import ZoneInfo

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from app.services import schedule as s

MED = {"id": 1, "start_date": "2026-10-01", "end_date": None,
       "days_of_week": None, "times": ["08:00", "20:00"], "paused": False}
UTC = ZoneInfo("UTC")


def valid(**kw):
    d = {"name": "Vitamin D", "dosage": "1 capsule", "times": ["08:00"],
         "start_date": "2026-10-01"}
    d.update(kw)
    return d


class Validation(unittest.TestCase):
    def test_ok(self):
        self.assertEqual(s.validate_medicine(valid())["name"], "Vitamin D")

    def test_errors(self):
        for bad, field in [({"name": " "}, "name"), ({"dosage": ""}, "dosage"),
                           ({"times": []}, "times"), ({"times": ["8:00"]}, "times"),
                           ({"times": ["08:00", "08:00"]}, "times"),
                           ({"days_of_week": [7]}, "days_of_week"),
                           ({"start_date": "bad"}, "start_date"),
                           ({"end_date": "2026-09-01"}, "end_date")]:
            with self.assertRaises(s.ValidationError) as cm:
                s.validate_medicine(valid(**bad))
            self.assertIn(field, cm.exception.errors)


class Generation(unittest.TestCase):
    def test_daily_two_times(self):
        d = s.generate_doses(MED, date(2026, 10, 1), date(2026, 10, 3))
        self.assertEqual(len(d), 6)

    def test_stable_ids_no_duplicates(self):
        a = s.generate_doses(MED, date(2026, 10, 1), date(2026, 10, 7))
        b = s.generate_doses(MED, date(2026, 10, 1), date(2026, 10, 7))
        self.assertEqual([x["id"] for x in a], [x["id"] for x in b])
        self.assertEqual(len({x["id"] for x in a}), len(a))

    def test_selected_days_only(self):
        m = {**MED, "days_of_week": [0]}  # Mondays
        d = s.generate_doses(m, date(2026, 10, 1), date(2026, 10, 31))
        self.assertTrue(all(x["scheduled_at"].weekday() == 0 for x in d))

    def test_respects_start_end_and_pause(self):
        m = {**MED, "start_date": "2026-10-05", "end_date": "2026-10-06"}
        self.assertEqual(len(s.generate_doses(m, date(2026, 10, 1), date(2026, 10, 31))), 4)
        self.assertEqual(s.generate_doses({**MED, "paused": True},
                                          date(2026, 10, 1), date(2026, 10, 3)), [])

    def test_cap(self):
        d = s.generate_doses({**MED, "times": ["08:00"]}, date(2026, 10, 1), date(2030, 1, 1))
        self.assertEqual(len(d), s.MAX_DAYS)

    def test_dst_gap_and_timezone(self):
        # US spring-forward 2026-03-08: 02:30 does not exist in New York.
        m = {**MED, "start_date": "2026-03-01", "times": ["02:30"]}
        d = s.generate_doses(m, date(2026, 3, 8), date(2026, 3, 8), "America/New_York")
        self.assertEqual(len(d), 1)
        self.assertEqual(d[0]["scheduled_at"].tzinfo, ZoneInfo("America/New_York"))
        # India has no DST: offset is constant.
        d = s.generate_doses(MED, date(2026, 10, 1), date(2026, 10, 1), "Asia/Kolkata")
        self.assertEqual(d[0]["scheduled_at"].utcoffset(), timedelta(hours=5, minutes=30))


class Status(unittest.TestCase):
    T = datetime(2026, 10, 1, 8, 0, tzinfo=UTC)

    def test_progression(self):
        self.assertEqual(s.dose_status(self.T, None, self.T - timedelta(minutes=1)), s.UPCOMING)
        self.assertEqual(s.dose_status(self.T, None, self.T + timedelta(minutes=30)), s.DUE)
        self.assertEqual(s.dose_status(self.T, None, self.T + timedelta(minutes=61)), s.MISSED)

    def test_outcome_wins(self):
        late = self.T + timedelta(days=3)
        self.assertEqual(s.dose_status(self.T, "taken", late), s.TAKEN)
        self.assertEqual(s.dose_status(self.T, "skipped", late), s.SKIPPED)

    def test_transitions(self):
        self.assertEqual(s.can_record(None, "taken"), "apply")
        self.assertEqual(s.can_record("taken", "taken"), "noop")  # idempotent
        with self.assertRaises(ValueError):
            s.can_record("taken", "skipped")
        with self.assertRaises(ValueError):
            s.can_record(None, "missed")


class Adherence(unittest.TestCase):
    def test_future_not_missed_and_denominator(self):
        now = datetime(2026, 10, 1, 12, 0, tzinfo=UTC)
        h = lambda hh: datetime(2026, 10, 1, hh, 0, tzinfo=UTC)
        doses = [{"scheduled_at": h(6), "outcome": "taken"},
                 {"scheduled_at": h(7), "outcome": "skipped"},
                 {"scheduled_at": h(8), "outcome": None},       # missed
                 {"scheduled_at": h(11, ) if False else h(12), "outcome": None},  # due
                 {"scheduled_at": h(20), "outcome": None}]      # upcoming
        r = s.adherence(doses, now)
        self.assertEqual((r["taken"], r["skipped"], r["missed"], r["denominator"]), (1, 1, 1, 3))
        self.assertEqual(r["percentage"], 33.3)

    def test_empty_is_none_not_zero(self):
        self.assertIsNone(s.adherence([], datetime.now(UTC))["percentage"])


if __name__ == "__main__":
    unittest.main()
