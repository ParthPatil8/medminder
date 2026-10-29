import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../widgets/common.dart';
import 'medicine_detail_screen.dart';
import 'medicine_form_screen.dart';

class MedicinesScreen extends StatelessWidget {
  const MedicinesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Medicines')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const MedicineFormScreen())),
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
      body: PageBody(
        child: !s.connected
            ? (s.loading
                ? const LoadingView()
                : ErrorView(message: s.error ?? 'Not connected.', onRetry: s.refresh))
            : s.medicines.isEmpty
                ? const EmptyView(
                    icon: Icons.medication_outlined,
                    title: 'No medicines yet',
                    message: 'Tap Add to create your first schedule.')
                : ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 88), children: [
                    for (final m in s.medicines)
                      Card(
                        child: ListTile(
                          leading: Icon(m.paused ? Icons.pause_circle : Icons.medication,
                              color: Theme.of(context).colorScheme.primary),
                          title: Text(m.name),
                          subtitle: Text('${m.dosage}\n${m.scheduleLabel}'),
                          isThreeLine: true,
                          trailing: m.paused
                              ? const Chip(label: Text('Paused'))
                              : (m.isDemo ? const Chip(label: Text('Demo')) : null),
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => MedicineDetailScreen(medicineId: m.id))),
                        ),
                      ),
                  ]),
      ),
    );
  }
}
