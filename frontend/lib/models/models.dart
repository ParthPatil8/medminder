class Medicine {
  const Medicine({
    required this.id,
    required this.name,
    required this.dosage,
    this.notes = '',
    this.instructions = '',
    required this.startDate,
    this.endDate,
    this.daysOfWeek,
    required this.times,
    this.paused = false,
    this.isDemo = false,
  });

  final int id;
  final String name, dosage, notes, instructions, startDate;
  final String? endDate;
  final List<int>? daysOfWeek; // 0 = Mon ... 6 = Sun; null = every day
  final List<String> times;
  final bool paused, isDemo;

  static const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  factory Medicine.fromJson(Map<String, dynamic> j) => Medicine(
        id: j['id'] as int,
        name: j['name'] as String,
        dosage: j['dosage'] as String,
        notes: (j['notes'] ?? '') as String,
        instructions: (j['instructions'] ?? '') as String,
        startDate: j['start_date'] as String,
        endDate: j['end_date'] as String?,
        daysOfWeek: (j['days_of_week'] as List?)?.map((e) => e as int).toList(),
        times: (j['times'] as List).map((e) => e as String).toList(),
        paused: (j['paused'] ?? false) as bool,
        isDemo: (j['is_demo'] ?? false) as bool,
      );

  String get scheduleLabel {
    final days = daysOfWeek;
    final d = days == null ? 'Every day' : days.map((i) => dayNames[i]).join(', ');
    return '$d · ${times.join(', ')}';
  }
}

class Dose {
  const Dose({
    required this.id,
    required this.medicineId,
    required this.medicineName,
    required this.dosage,
    required this.instructions,
    required this.scheduledAt,
    required this.status,
    this.outcome,
    this.recordedAt,
  });

  final String id, medicineName, dosage, instructions, scheduledAt, status;
  final int medicineId;
  final String? outcome, recordedAt;

  factory Dose.fromJson(Map<String, dynamic> j) => Dose(
        id: j['id'] as String,
        medicineId: j['medicine_id'] as int,
        medicineName: j['medicine_name'] as String,
        dosage: j['dosage'] as String,
        instructions: (j['instructions'] ?? '') as String,
        scheduledAt: j['scheduled_at'] as String,
        status: j['status'] as String,
        outcome: j['outcome'] as String?,
        recordedAt: j['recorded_at'] as String?,
      );

  // scheduled_at looks like 2026-10-28T08:00:00+05:30 (wall-clock in the
  // server's timezone). Slicing the text avoids device-timezone surprises.
  String get date => scheduledAt.substring(0, 10);
  String get time => scheduledAt.substring(11, 16);
  bool get isPending => status == 'upcoming' || status == 'due';
}

class Adherence {
  const Adherence({
    required this.taken,
    required this.skipped,
    required this.missed,
    required this.denominator,
    this.percentage,
  });

  final int taken, skipped, missed, denominator;
  final double? percentage;

  factory Adherence.fromJson(Map<String, dynamic> j) => Adherence(
        taken: j['taken'] as int,
        skipped: j['skipped'] as int,
        missed: j['missed'] as int,
        denominator: j['denominator'] as int,
        percentage: (j['percentage'] as num?)?.toDouble(),
      );
}

class MedicineDetail {
  const MedicineDetail(this.medicine, this.upcoming, this.recent);
  final Medicine medicine;
  final List<Dose> upcoming, recent;

  factory MedicineDetail.fromJson(Map<String, dynamic> j) => MedicineDetail(
        Medicine.fromJson(j),
        (j['upcoming'] as List).map((e) => Dose.fromJson(e as Map<String, dynamic>)).toList(),
        (j['recent'] as List).map((e) => Dose.fromJson(e as Map<String, dynamic>)).toList(),
      );
}

class HistoryResult {
  const HistoryResult(this.doses, this.adherence);
  final List<Dose> doses;
  final Adherence adherence;
}
