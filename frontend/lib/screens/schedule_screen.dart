import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/app_state.dart';
import '../utils/validators.dart';
import '../widgets/common.dart';
import '../widgets/dose_tile.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});
  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  late DateTime _day;
  Future<List<Dose>>? _future;
  int _ver = -1;

  @override
  void initState() {
    super.initState();
    _day = DateTime.parse(context.read<AppState>().today);
  }

  Future<void> _load() async {
    setState(() => _future = context.read<AppState>().api.dosesForDay(ymd(_day)));
  }

  void _shift(int days) {
    _day = _day.add(Duration(days: days));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final v = context.watch<AppState>().version;
    if (v != _ver) {
      _ver = v;
      _future = context.read<AppState>().api.dosesForDay(ymd(_day));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Daily schedule'), actions: [
        IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
      ]),
      body: PageBody(
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            IconButton(onPressed: () => _shift(-1), icon: const Icon(Icons.chevron_left)),
            TextButton(
              onPressed: () async {
                final p = await showDatePicker(
                    context: context,
                    initialDate: _day,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100));
                if (p != null) {
                  _day = p;
                  _load();
                }
              },
              child: Text(DateFormat('EEE, d MMM y').format(_day)),
            ),
            IconButton(onPressed: () => _shift(1), icon: const Icon(Icons.chevron_right)),
          ]),
          Expanded(
            child: FutureBuilder<List<Dose>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) return const LoadingView();
                if (snap.hasError) {
                  return ErrorView(message: snap.error.toString(), onRetry: _load);
                }
                final doses = snap.data ?? [];
                if (doses.isEmpty) {
                  return const EmptyView(
                      icon: Icons.event_available, title: 'No doses scheduled for this day');
                }
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [for (final d in doses) DoseTile(dose: d, reload: _load)],
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}
