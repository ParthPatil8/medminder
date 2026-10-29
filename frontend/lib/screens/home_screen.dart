import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../services/api_client.dart';
import '../widgets/common.dart';
import '../widgets/dose_tile.dart';
import 'history_screen.dart';
import 'medicine_form_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  String _greeting() {
    final h = DateTime.now().hour;
    return h < 12 ? 'Good morning' : (h < 18 ? 'Good afternoon' : 'Good evening');
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('MedMinder'),
        actions: [IconButton(onPressed: s.refresh, icon: const Icon(Icons.refresh))],
      ),
      body: PageBody(child: _content(context, s)),
    );
  }

  Widget _content(BuildContext context, AppState s) {
    if (!s.connected && s.loading) return const LoadingView();
    if (!s.connected) {
      return ErrorView(message: s.error ?? 'Not connected to the server.', onRetry: s.refresh);
    }
    if (s.medicines.isEmpty) {
      return EmptyView(
        icon: Icons.medication_outlined,
        title: 'No medicines yet',
        message: 'Add your first medicine, or load demonstration data to explore the app.',
        actions: [
          FilledButton.icon(
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const MedicineFormScreen())),
            icon: const Icon(Icons.add),
            label: const Text('Add medicine'),
          ),
          OutlinedButton.icon(
            onPressed: () async {
              try {
                await s.loadDemo();
              } on ApiException catch (e) {
                if (context.mounted) snack(context, e.message);
              }
            },
            icon: const Icon(Icons.science_outlined),
            label: const Text('Load demo data'),
          ),
        ],
      );
    }
    final doses = s.todayDoses;
    final taken = doses.where((d) => d.status == 'taken').length;
    final pending = doses.where((d) => d.isPending).toList();
    final next = pending.isEmpty ? null : pending.first;
    final date = DateFormat('EEEE, d MMMM y').format(DateTime.parse(s.today));
    return RefreshIndicator(
      onRefresh: s.refresh,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        Text(_greeting(), style: Theme.of(context).textTheme.headlineSmall),
        Text(date),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              AdherenceRing(done: taken, total: doses.length),
              const SizedBox(width: 20),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text("Today's doses", style: Theme.of(context).textTheme.titleMedium),
                  Text('$taken of ${doses.length} taken'),
                  Text('${s.activeMedicines.length} medicines scheduled'),
                ]),
              ),
            ]),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.alarm),
            title: const Text('Next dose'),
            subtitle: Text(next == null
                ? 'Nothing left to take today'
                : '${next.medicineName} · ${next.dosage} at ${next.time}'),
          ),
        ),
        Row(children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const MedicineFormScreen())),
              icon: const Icon(Icons.add),
              label: const Text('Add medicine'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const HistoryScreen())),
              icon: const Icon(Icons.history),
              label: const Text('View history'),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        Text('Scheduled today', style: Theme.of(context).textTheme.titleMedium),
        if (doses.isEmpty) const Padding(padding: EdgeInsets.all(12), child: Text('No doses scheduled today.')),
        for (final d in doses) DoseTile(dose: d),
      ]),
    );
  }
}
