import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../providers/app_state.dart';
import '../services/api_client.dart';
import '../widgets/common.dart';

const _privacyText =
    'MedMinder stores the medicines and dose records you enter on the server '
    'you connect to (a SQLite file when run locally, or a PostgreSQL database '
    'if deployed). On this device it stores only your server address, theme '
    'and reminder preference. Reminders are scheduled locally on the device. '
    'There are no accounts, analytics or advertising.\n\n'
    'Demo mode has no login: anyone who can reach the server address can read '
    'and change its data, so do not enter real personal health information on '
    'a public demo server.\n\n'
    'MedMinder is a reminder and record-keeping tool. It does not diagnose, '
    'prescribe or recommend treatment, and a missed dose is never a prompt to '
    'take extra medicine. Follow your clinician\'s instructions.';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _url;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _url = TextEditingController(text: context.read<AppState>().baseUrl);
  }

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action, String okMessage) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) snack(context, okMessage);
    } on ApiException catch (e) {
      if (mounted) snack(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: PageBody(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Text('Server connection', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Row(children: [
            Icon(s.connected ? Icons.check_circle : Icons.error,
                color: s.connected ? statusColors['taken'] : cs.error),
            const SizedBox(width: 8),
            Expanded(
              child: Text(s.connected
                  ? 'Connected · server timezone ${s.timezone}'
                  : (s.error ?? 'Not connected')),
            ),
          ]),
          const SizedBox(height: 8),
          TextField(
            controller: _url,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'API address',
              hintText: 'http://192.168.1.10:5000',
              helperText: 'Phone + local backend: use your computer\'s Wi-Fi IP address.',
            ),
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            FilledButton.icon(
              onPressed: _busy
                  ? null
                  : () async {
                      await s.setBaseUrl(_url.text);
                      await s.refresh();
                      if (context.mounted) {
                        snack(context, s.connected ? 'Connected.' : (s.error ?? 'Not connected.'));
                      }
                    },
              icon: const Icon(Icons.wifi_tethering),
              label: const Text('Save & test'),
            ),
            TextButton(
              onPressed: () => setState(() => _url.text = kDefaultApiUrl),
              child: const Text('Reset to default'),
            ),
          ]),
          const Divider(height: 32),
          Text('Reminders', style: Theme.of(context).textTheme.titleMedium),
          if (!s.notifier.supported)
            const Card(
              child: ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('Reminders are available in the Android app'),
                subtitle: Text(
                    'Browsers cannot deliver scheduled background notifications. '
                    'All other features work on the web.'),
              ),
            )
          else ...[
            SwitchListTile(
              title: const Text('Dose reminders'),
              subtitle: Text(s.notificationsAllowed
                  ? 'Notification permission granted'
                  : 'Notification permission not granted'),
              value: s.remindersEnabled,
              onChanged: (v) => s.setReminders(v),
            ),
            if (!s.notificationsAllowed)
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton(
                  onPressed: s.requestNotificationPermission,
                  child: const Text('Allow notifications'),
                ),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: s.notifier.showTest,
                icon: const Icon(Icons.notifications_active_outlined),
                label: const Text('Send test notification'),
              ),
            ),
            Text(
              'Reminders may arrive a few minutes late because Android batches '
              'alarms to save battery. If they stop arriving, turn off battery '
              'optimisation for MedMinder in Android settings. Reminders are '
              'restored after a reboot.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const Divider(height: 32),
          Text('Appearance', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(value: ThemeMode.system, label: Text('System')),
              ButtonSegment(value: ThemeMode.light, label: Text('Light')),
              ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
            ],
            selected: {s.themeMode},
            onSelectionChanged: (v) => s.setThemeMode(v.first),
          ),
          const Divider(height: 32),
          Text('Demonstration data', style: Theme.of(context).textTheme.titleMedium),
          const Text(
              'Adds clearly labelled fictional medicines and a week of sample history. '
              'These are not prescriptions. Clearing removes only demo records.'),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            FilledButton.tonalIcon(
              onPressed: _busy || !s.connected
                  ? null
                  : () => _run(s.loadDemo, 'Demo data loaded.'),
              icon: const Icon(Icons.science_outlined),
              label: const Text('Load / reset demo data'),
            ),
            OutlinedButton.icon(
              onPressed: _busy || !s.connected
                  ? null
                  : () async {
                      final ok = await confirmDialog(context, 'Clear demo data?',
                          'Only demo medicines and their records are removed. Your own data is kept.',
                          confirmLabel: 'Clear');
                      if (ok) await _run(s.clearDemo, 'Demo data cleared.');
                    },
              icon: const Icon(Icons.delete_sweep_outlined),
              label: const Text('Clear demo data'),
            ),
          ]),
          const Divider(height: 32),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy notice'),
            onTap: () => showDialog<void>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Privacy & limitations'),
                content: const SingleChildScrollView(child: Text(_privacyText)),
                actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
              ),
            ),
          ),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.info_outline),
            title: Text('MedMinder'),
            subtitle: Text('Version $kAppVersion · MADLab project'),
          ),
        ]),
      ),
    );
  }
}
