import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import '../models/models.dart';
import '../services/api_client.dart';
import '../services/notification_service.dart';
import '../utils/validators.dart';

class AppState extends ChangeNotifier {
  AppState({ApiClient? api, NotificationService? notifier})
      : api = api ?? ApiClient(kDefaultApiUrl),
        notifier = notifier ?? NotificationService();

  ApiClient api;
  final NotificationService notifier;
  SharedPreferences? _prefs;

  int version = 0; // bumps whenever server data is reloaded
  bool initialized = false, onboarded = false, loading = false, connected = false;
  bool remindersEnabled = true, notificationsAllowed = false;
  String baseUrl = kDefaultApiUrl, timezone = 'Asia/Kolkata';
  String? error, serverToday;
  ThemeMode themeMode = ThemeMode.system;
  List<Medicine> medicines = [];
  List<Dose> todayDoses = [];

  String get today => serverToday ?? ymd(DateTime.now());
  List<Medicine> get activeMedicines => medicines.where((m) => !m.paused).toList();

  Future<void> init() async {
    final p = _prefs = await SharedPreferences.getInstance();
    baseUrl = p.getString('api_url') ?? kDefaultApiUrl;
    api = ApiClient(baseUrl);
    onboarded = p.getBool('onboarded') ?? false;
    remindersEnabled = p.getBool('reminders') ?? true;
    final t = p.getInt('theme') ?? 0;
    themeMode = ThemeMode.values[t.clamp(0, ThemeMode.values.length - 1).toInt()];
    initialized = true;
    notifyListeners();
    await refresh();
  }

  Future<void> completeOnboarding() async {
    onboarded = true;
    await _prefs?.setBool('onboarded', true);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode m) async {
    themeMode = m;
    await _prefs?.setInt('theme', m.index);
    notifyListeners();
  }

  Future<void> setBaseUrl(String url) async {
    baseUrl = url.trim();
    api = ApiClient(baseUrl);
    await _prefs?.setString('api_url', baseUrl);
  }

  /// Reloads everything from the server. Never throws; sets [error] instead.
  Future<void> refresh() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final h = await api.health();
      connected = true;
      timezone = h['timezone'] as String;
      serverToday = (h['time'] as String).substring(0, 10);
      await notifier.init(timezone);
      medicines = await api.listMedicines();
      todayDoses = await api.dosesForDay(serverToday!);
      await rescheduleReminders();
    } on ApiException catch (e) {
      connected = false;
      error = e.message;
    } catch (e) {
      connected = false;
      error = 'Unexpected problem talking to the server: $e';
    } finally {
      loading = false;
      version++;
      notifyListeners();
    }
  }

  Future<void> refreshToday() async {
    todayDoses = await api.dosesForDay(today);
    version++;
    notifyListeners();
  }

  Future<void> rescheduleReminders() async {
    if (!notifier.supported) return;
    try {
      await notifier.cancelAll();
      notificationsAllowed = await notifier.permissionGranted();
      if (!remindersEnabled || !notificationsAllowed) return;
      await notifier.scheduleAll(activeMedicines, today);
    } catch (e) {
      debugPrint('Reminder scheduling failed: $e');
    }
  }

  Future<void> setReminders(bool on) async {
    remindersEnabled = on;
    await _prefs?.setBool('reminders', on);
    if (on) notificationsAllowed = await notifier.requestPermission();
    await rescheduleReminders();
    notifyListeners();
  }

  Future<void> requestNotificationPermission() async {
    notificationsAllowed = await notifier.requestPermission();
    await rescheduleReminders();
    notifyListeners();
  }

  // Mutations throw ApiException so the calling screen can show the error
  // and keep the user's input.
  Future<void> saveMedicine(Map<String, dynamic> payload, {int? id}) async {
    if (id == null) {
      await api.createMedicine(payload);
    } else {
      await api.updateMedicine(id, payload);
    }
    await refresh();
  }

  Future<void> deleteMedicine(int id) async {
    await api.deleteMedicine(id);
    await refresh();
  }

  Future<void> setPaused(int id, bool paused) async {
    await api.setPaused(id, paused);
    await refresh();
  }

  Future<void> recordDose(Dose d, String outcome) async {
    await api.record(d.id, outcome);
    await refreshToday();
  }

  Future<void> undoDose(Dose d) async {
    await api.undo(d.id);
    await refreshToday();
  }

  Future<void> loadDemo() async {
    await api.loadDemo();
    await refresh();
  }

  Future<void> clearDemo() async {
    await api.clearDemo();
    await refresh();
  }
}
