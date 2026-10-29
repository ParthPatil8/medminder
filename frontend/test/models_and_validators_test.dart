import 'package:flutter_test/flutter_test.dart';
import 'package:medminder/models/models.dart';
import 'package:medminder/utils/validators.dart';

void main() {
  group('Medicine', () {
    test('parses daily schedule', () {
      final m = Medicine.fromJson({
        'id': 1, 'name': 'Vitamin D', 'dosage': '1 capsule', 'start_date': '2026-10-01',
        'times': ['08:00', '20:00'], 'days_of_week': null, 'paused': false,
      });
      expect(m.scheduleLabel, 'Every day · 08:00, 20:00');
      expect(m.endDate, isNull);
    });

    test('parses selected days', () {
      final m = Medicine.fromJson({
        'id': 2, 'name': 'X', 'dosage': '5 ml', 'start_date': '2026-10-01',
        'times': ['09:00'], 'days_of_week': [0, 4], 'paused': true,
      });
      expect(m.scheduleLabel, 'Mon, Fri · 09:00');
      expect(m.paused, isTrue);
    });
  });

  group('Dose', () {
    final d = Dose.fromJson({
      'id': '1|2026-10-28|08:00', 'medicine_id': 1, 'medicine_name': 'Vitamin D',
      'dosage': '1 capsule', 'instructions': '',
      'scheduled_at': '2026-10-28T08:00:00+05:30', 'status': 'upcoming',
    });
    test('reads wall-clock date and time from the server text', () {
      expect(d.date, '2026-10-28');
      expect(d.time, '08:00');
    });
    test('upcoming is pending, taken is not', () {
      expect(d.isPending, isTrue);
    });
  });

  test('Adherence keeps null percentage when there is no data', () {
    final a = Adherence.fromJson(
        {'taken': 0, 'skipped': 0, 'missed': 0, 'denominator': 0, 'percentage': null});
    expect(a.percentage, isNull);
  });

  group('validators', () {
    test('required', () {
      expect(validateRequired('  ', 'Name'), isNotNull);
      expect(validateRequired('Vit D', 'Name'), isNull);
    });
    test('times and days', () {
      expect(validateTimes([]), isNotNull);
      expect(validateTimes(['08:00']), isNull);
      expect(validateDays(true, {}), isNotNull);
      expect(validateDays(false, {}), isNull);
    });
    test('date range', () {
      expect(validateDateRange(DateTime(2026, 10, 5), DateTime(2026, 10, 1)), isNotNull);
      expect(validateDateRange(DateTime(2026, 10, 5), null), isNull);
    });
    test('formatting', () {
      expect(ymd(DateTime(2026, 3, 4)), '2026-03-04');
      expect(hhmm(8, 5), '08:05');
    });
  });
}
