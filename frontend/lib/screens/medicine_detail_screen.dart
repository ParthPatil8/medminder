import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/app_state.dart';
import '../services/api_client.dart';
import '../widgets/common.dart';
import '../widgets/dose_tile.dart';
import 'medicine_form_screen.dart';

class MedicineDetailScreen extends StatefulWidget {
  const MedicineDetailScreen({super.key, required this.medicineId});
  final int medicineId;
  @override
  State<MedicineDetailScreen> createState() => _MedicineDetailScreenState();
}

class _MedicineDetailScreenState extends State<MedicineDetailScreen> {
  late Future<MedicineDetail> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<AppState>().api.getMedicine(widget.medicineId);
  }

  Future<void> _load() async {
    setState(() => _future = context.read<AppState>().api.getMedicine(widget.medicineId));
  }

  Future<void> _togglePause(Medicine m) async {
    try {
      await context.read<AppState>().setPaused(m.id, !m.paused);
      await _load();
    } on ApiException catch (e) {
      if (mounted) snack(context, e.message);
    }
  }

  Future<void> _delete(Medicine m) async {
    final ok = await confirmDialog(context, 'Delete ${m.name}?',
        'The schedule and reminders will be removed. Your recorded dose history is kept.',
        confirmLabel: 'Delete');
    if (!ok || !mounted) return;
    try {
      await context.read<AppState>().deleteMedicine(m.id);
      if (mounted) Navigator.pop(context);
    } on ApiException catch (e) {
      if (mounted) snack(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Medicine details')),
        body: PageBody(
          child: FutureBuilder<MedicineDetail>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) return const LoadingView();
              if (snap.hasError) {
                return ErrorView(message: snap.error.toString(), onRetry: _load);
              }
              final d = snap.data!;
              final m = d.medicine;
              return ListView(padding: const EdgeInsets.all(16), children: [
                Text(m.name, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 4),
                Row(children: [
                  Chip(label: Text(m.paused ? 'Paused' : 'Active')),
                  if (m.isDemo) ...[const SizedBox(width: 8), const Chip(label: Text('Demo data'))],
                ]),
                Card(
                  child: Column(children: [
                    ListTile(leading: const Icon(Icons.science_outlined), title: const Text('Dosage'), subtitle: Text(m.dosage)),
                    ListTile(leading: const Icon(Icons.schedule), title: const Text('Schedule'), subtitle: Text(m.scheduleLabel)),
                    ListTile(
                        leading: const Icon(Icons.date_range),
                        title: const Text('Dates'),
                        subtitle: Text('From ${m.startDate}${m.endDate == null ? '' : ' to ${m.endDate}'}')),
                    if (m.instructions.isNotEmpty)
                      ListTile(leading: const Icon(Icons.restaurant), title: const Text('Instructions'), subtitle: Text(m.instructions)),
                    if (m.notes.isNotEmpty)
                      ListTile(leading: const Icon(Icons.notes), title: const Text('Notes'), subtitle: Text(m.notes)),
                  ]),
                ),
                Wrap(spacing: 8, children: [
                  FilledButton.tonalIcon(
                    onPressed: () async {
                      final saved = await Navigator.push<bool>(context,
                          MaterialPageRoute(builder: (_) => MedicineFormScreen(medicine: m)));
                      if (saved == true) _load();
                    },
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _togglePause(m),
                    icon: Icon(m.paused ? Icons.play_arrow : Icons.pause),
                    label: Text(m.paused ? 'Resume' : 'Pause'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _delete(m),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete'),
                  ),
                ]),
                const SizedBox(height: 16),
                Text('Upcoming doses', style: Theme.of(context).textTheme.titleMedium),
                if (d.upcoming.isEmpty) const Padding(padding: EdgeInsets.all(8), child: Text('None in the next 7 days.')),
                for (final x in d.upcoming) DoseTile(dose: x, showActions: false),
                const SizedBox(height: 12),
                Text('Recent history', style: Theme.of(context).textTheme.titleMedium),
                if (d.recent.isEmpty) const Padding(padding: EdgeInsets.all(8), child: Text('No recent records.')),
                for (final x in d.recent.reversed) DoseTile(dose: x, showActions: false),
              ]);
            },
          ),
        ),
      );
}
