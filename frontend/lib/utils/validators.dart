String ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String hhmm(int hour, int minute) =>
    '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

String? validateRequired(String? v, String label) =>
    (v == null || v.trim().isEmpty) ? '$label is required.' : null;

String? validateTimes(List<String> times) =>
    times.isEmpty ? 'Add at least one reminder time.' : null;

String? validateDays(bool selectedDaysMode, Set<int> days) =>
    (selectedDaysMode && days.isEmpty) ? 'Choose at least one day.' : null;

String? validateDateRange(DateTime start, DateTime? end) =>
    (end != null && end.isBefore(start)) ? 'End date cannot be before the start date.' : null;
