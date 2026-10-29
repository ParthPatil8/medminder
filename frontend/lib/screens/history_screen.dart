import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/app_state.dart';
import '../utils/validators.dart';
import '../widgets/common.dart';
import '../widgets/dose_tile.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  int _days = 7;
  int? _medicineId;
  Future<HistoryResult>? _future;
  int _ver = -1;

  Future<HistoryResult> _fetch() {
    final s = context.read<AppState>();
    final to = DateTime.parse(s.today);
    final from = to.subtract(Duration(days: _days - 1));
    return s.api.history(ymd(from), ymd(to), medicineId: _medicineId);
  }

  void _load() => setState(() => _future = _fetch());

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final meds = st.medicines;
    if (st.version != _ver) {
      _ver = st.version;
      _future = _fetch();
    }
    return Scaffold(
      appBar: AppBar(title: const Text('History'), actions: [
        IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
      ]),
      body: PageBody(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(spacing: 6, children: [
                  for (final d in const [7, 14, 30])
                    ChoiceChip(
                      label: Text('Last $d days'),
                      selected: _days == d,
                      onSelected: (_) {
                        _days = d;
                        _load();
                      },
                    ),
                ]),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  ChoiceChip(
                    label: const Text('All medicines'),
                    selected: _medicineId == null,
                    onSelected: (_) {
                      _medicineId = null;
                      _load();
                    },
                  ),
                  for (final m in meds) ...[
                    const SizedBox(width: 6),
                    ChoiceChip(
                      label: Text(m.name),
                      selected: _medicineId == m.id,
                      onSelected: (_) {
                        _medicineId = m.id;
                        _load();
                      },
                    ),
                  ],
                ]),
              ),
            ]),
          ),
          Expanded(
            child: FutureBuilder<HistoryResult>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) return const LoadingView();
                if (snap.hasError) {
                  return ErrorView(message: snap.error.toString(), onRetry: _load);
                }
                final r = snap.data!;
                final a = r.adherence;
                final doses = r.doses.reversed.toList();
                return ListView(padding: const EdgeInsets.all(16), children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(
                          a.percentage == null ? 'No data yet' : '${a.percentage}% adherence',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        Text('${a.taken} taken · ${a.skipped} skipped · ${a.missed} missed'),
                        const SizedBox(height: 6),
                        Text(
                          'Adherence = taken ÷ (taken + skipped + missed). Upcoming doses are not counted.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ]),
                    ),
                  ),
                  if (doses.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: EmptyView(
                          icon: Icons.history,
                          title: 'No dose history yet',
                          message: 'Doses you record will appear here.'),
                    ),
                  for (var i = 0; i < doses.length; i++) ...[
                    if (i == 0 || doses[i].date != doses[i - 1].date)
                      Padding(
                        padding: const EdgeInsets.only(top: 12, bottom: 4),
                        child: Text(
                          DateFormat('EEEE, d MMM').format(DateTime.parse(doses[i].date)),
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                    DoseTile(dose: doses[i], showActions: false),
                  ],
                ]);
              },
            ),
          ),
        ]),
      ),
    );
  }
}
