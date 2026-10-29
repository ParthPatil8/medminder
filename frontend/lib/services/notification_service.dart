import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/models.dart';

/// Real Android local notifications (flutter_local_notifications).
/// Not supported on Flutter Web: every method is a safe no-op there.
///
/// Notification ids are deterministic, so rescheduling replaces rather than
/// duplicates: daily = medId*1000 + timeIndex; weekly = medId*1000 +
/// (weekday+1)*100 + timeIndex. Inexact (idle-allowed) alarms are used, so no
/// exact-alarm permission is needed; delivery may be a few minutes late.
class NotificationService {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> init(String timezoneName) async {
    if (!supported || _ready) return;
    tzdata.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation(timezoneName));
    } catch (_) {
      // Unknown zone name: keep the package default.
    }
    await _plugin.initialize(
      const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
    );
    _ready = true;
  }

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  Future<bool> permissionGranted() async {
    if (!supported || !_ready) return false;
    return await _android?.areNotificationsEnabled() ?? false;
  }

  Future<bool> requestPermission() async {
    if (!supported || !_ready) return false;
    return await _android?.requestNotificationsPermission() ?? false;
  }

  Future<void> cancelAll() async {
    if (supported && _ready) await _plugin.cancelAll();
  }

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'dose_reminders',
      'Dose reminders',
      channelDescription: 'Reminders for your scheduled medicine doses',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  Future<void> showTest() async {
    if (!supported || !_ready) return;
    await _plugin.show(999999, 'MedMinder test reminder',
        'Reminders are working on this device.', _details);
  }

  Future<void> scheduleAll(List<Medicine> meds, String today) async {
    if (!supported || !_ready) return;
    final now = tz.TZDateTime.now(tz.local);
    for (final m in meds) {
      if (m.paused) continue;
      final end = m.endDate;
      if (end != null && end.compareTo(today) < 0) continue;
      final start = DateTime.parse(m.startDate);
      for (var i = 0; i < m.times.length && i < 99; i++) {
        final p = m.times[i].split(':');
        final h = int.parse(p[0]), min = int.parse(p[1]);
        final days = m.daysOfWeek;
        if (days == null) {
          await _schedule(m.id * 1000 + i, m, m.times[i],
              _next(now, start, h, min, null), DateTimeComponents.time);
        } else {
          for (final d in days) {
            await _schedule(m.id * 1000 + (d + 1) * 100 + i, m, m.times[i],
                _next(now, start, h, min, d + 1), DateTimeComponents.dayOfWeekAndTime);
          }
        }
      }
    }
  }

  Future<void> _schedule(int id, Medicine m, String time, tz.TZDateTime when,
      DateTimeComponents repeat) {
    final extra = m.instructions.isEmpty ? '' : ' · ${m.instructions}';
    return _plugin.zonedSchedule(
      id,
      'Time for ${m.name}',
      '${m.dosage} · $time$extra',
      when,
      _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: repeat,
    );
  }

  // First occurrence of h:min (optionally on a given Dart weekday, Mon=1)
  // that is not before now and not before the medicine's start date.
  tz.TZDateTime _next(tz.TZDateTime now, DateTime start, int h, int min, int? weekday) {
    var d = tz.TZDateTime(tz.local, now.year, now.month, now.day, h, min);
    final s0 = tz.TZDateTime(tz.local, start.year, start.month, start.day, h, min);
    if (s0.isAfter(d)) d = s0;
    while (d.isBefore(now) || (weekday != null && d.weekday != weekday)) {
      d = tz.TZDateTime(tz.local, d.year, d.month, d.day + 1, h, min);
    }
    return d;
  }
}
