import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/app_state.dart';
import '../services/api_client.dart';
import 'common.dart';

/// Runs a dose action ('taken', 'skipped' or 'undo') with confirmation and
/// error reporting. [reload] refreshes the calling screen afterwards.
Future<void> doseAction(BuildContext context, Dose d, String action,
    {Future<void> Function()? reload}) async {
  final state = context.read<AppState>();
  if (action == 'undo') {
    final ok = await confirmDialog(context, 'Undo this record?',
        '${d.medicineName} at ${d.time} will go back to its scheduled status.',
        confirmLabel: 'Undo');
    if (!ok) return;
  } else if (action == 'skipped') {
    if (!context.mounted) return;
    final ok = await confirmDialog(
        context, 'Mark as skipped?', '${d.medicineName} at ${d.time} will be recorded as skipped.',
        confirmLabel: 'Skip');
    if (!ok) return;
  }
  if (!context.mounted) return;
  try {
    if (action == 'undo') {
      await state.undoDose(d);
    } else {
      await state.recordDose(d, action);
    }
    if (reload != null) await reload();
  } on ApiException catch (e) {
    if (context.mounted) snack(context, e.message);
  }
}

class DoseTile extends StatelessWidget {
  const DoseTile({super.key, required this.dose, this.reload, this.showActions = true});
  final Dose dose;
  final Future<void> Function()? reload;
  final bool showActions;

  @override
  Widget build(BuildContext context) {
    final recorded = dose.recordedAt == null
        ? null
        : DateFormat('HH:mm').format(DateTime.parse(dose.recordedAt!).toLocal());
    final done = dose.status == 'taken' || dose.status == 'skipped';
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(dose.time, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(dose.medicineName, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(doseSubtitle(dose), style: Theme.of(context).textTheme.bodySmall),
                if (recorded != null)
                  Text('Recorded at $recorded', style: Theme.of(context).textTheme.bodySmall),
              ]),
            ),
            StatusChip(dose.status),
          ]),
          if (showActions)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(spacing: 8, children: [
                if (!done) ...[
                  FilledButton.tonalIcon(
                    onPressed: () => doseAction(context, dose, 'taken', reload: reload),
                    icon: const Icon(Icons.check),
                    label: const Text('Taken'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => doseAction(context, dose, 'skipped', reload: reload),
                    icon: const Icon(Icons.skip_next),
                    label: const Text('Skip'),
                  ),
                ] else
                  TextButton.icon(
                    onPressed: () => doseAction(context, dose, 'undo', reload: reload),
                    icon: const Icon(Icons.undo),
                    label: const Text('Undo'),
                  ),
              ]),
            ),
        ]),
      ),
    );
  }
}
