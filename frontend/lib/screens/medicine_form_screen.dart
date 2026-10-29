import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/app_state.dart';
import '../services/api_client.dart';
import '../utils/validators.dart';
import '../widgets/common.dart';

class MedicineFormScreen extends StatefulWidget {
  const MedicineFormScreen({super.key, this.medicine});
  final Medicine? medicine;
  @override
  State<MedicineFormScreen> createState() => _MedicineFormScreenState();
}

class _MedicineFormScreenState extends State<MedicineFormScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name, _dosage, _notes, _instructions;
  late DateTime _start;
  DateTime? _end;
  bool _selectedDays = false, _saving = false;
  final Set<int> _days = {};
  final List<String> _times = [];
  Map<String, String> _server = {};
  String? _timesErr, _daysErr, _dateErr;

  @override
  void initState() {
    super.initState();
    final m = widget.medicine;
    _name = TextEditingController(text: m?.name ?? '');
    _dosage = TextEditingController(text: m?.dosage ?? '');
    _notes = TextEditingController(text: m?.notes ?? '');
    _instructions = TextEditingController(text: m?.instructions ?? '');
    _start = DateTime.parse(m?.startDate ?? context.read<AppState>().today);
    _end = m?.endDate == null ? null : DateTime.parse(m!.endDate!);
    if (m != null) {
      _times.addAll(m.times);
      if (m.daysOfWeek != null) {
        _selectedDays = true;
        _days.addAll(m.daysOfWeek!);
      }
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _dosage.dispose();
    _notes.dispose();
    _instructions.dispose();
    super.dispose();
  }

  Future<void> _addTime() async {
    final t = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 8, minute: 0));
    if (t == null) return;
    final v = hhmm(t.hour, t.minute);
    setState(() {
      if (!_times.contains(v)) _times.add(v);
      _times.sort();
      _timesErr = null;
    });
  }

  Future<void> _pickDate(bool isStart) async {
    final p = await showDatePicker(
      context: context,
      initialDate: isStart ? _start : (_end ?? _start),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (p != null) setState(() => isStart ? _start = p : _end = p);
  }

  Future<void> _submit() async {
    setState(() {
      _server = {};
      _timesErr = validateTimes(_times);
      _daysErr = validateDays(_selectedDays, _days);
      _dateErr = validateDateRange(_start, _end);
    });
    final ok = _form.currentState!.validate();
    if (!ok || _timesErr != null || _daysErr != null || _dateErr != null) return;
    setState(() => _saving = true);
    final payload = <String, dynamic>{
      'name': _name.text.trim(),
      'dosage': _dosage.text.trim(),
      'notes': _notes.text.trim(),
      'instructions': _instructions.text.trim(),
      'start_date': ymd(_start),
      'end_date': _end == null ? null : ymd(_end!),
      'days_of_week': _selectedDays ? (_days.toList()..sort()) : null,
      'times': [..._times]..sort(),
    };
    try {
      await context.read<AppState>().saveMedicine(payload, id: widget.medicine?.id);
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      // Stay on the form so nothing the user typed is lost.
      if (!mounted) return;
      setState(() {
        _saving = false;
        _server = e.fields ?? {};
      });
      snack(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final err = Theme.of(context).colorScheme.error;
    return Scaffold(
      appBar: AppBar(title: Text(widget.medicine == null ? 'Add medicine' : 'Edit medicine')),
      body: PageBody(
        child: Form(
          key: _form,
          child: ListView(padding: const EdgeInsets.all(16), children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Medicine name'),
              validator: (v) => _server['name'] ?? validateRequired(v, 'Name'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _dosage,
              decoration: const InputDecoration(labelText: 'Dosage', hintText: 'e.g. 1 tablet, 5 ml'),
              validator: (v) => _server['dosage'] ?? validateRequired(v, 'Dosage'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _instructions,
              decoration: const InputDecoration(
                  labelText: 'Instructions (optional)', hintText: 'e.g. after food'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notes,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickDate(true),
                  icon: const Icon(Icons.event),
                  label: Text('Start: ${ymd(_start)}'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickDate(false),
                  icon: const Icon(Icons.event_busy),
                  label: Text(_end == null ? 'End: none' : 'End: ${ymd(_end!)}'),
                ),
              ),
              if (_end != null)
                IconButton(
                    tooltip: 'Clear end date',
                    onPressed: () => setState(() => _end = null),
                    icon: const Icon(Icons.clear)),
            ]),
            if (_dateErr != null || _server['start_date'] != null || _server['end_date'] != null)
              Text(_dateErr ?? _server['start_date'] ?? _server['end_date']!,
                  style: TextStyle(color: err)),
            const SizedBox(height: 16),
            Text('Frequency', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Every day')),
                ButtonSegment(value: true, label: Text('Selected days')),
              ],
              selected: {_selectedDays},
              onSelectionChanged: (v) => setState(() => _selectedDays = v.first),
            ),
            if (_selectedDays) ...[
              const SizedBox(height: 8),
              Wrap(spacing: 6, children: [
                for (var i = 0; i < 7; i++)
                  FilterChip(
                    label: Text(Medicine.dayNames[i]),
                    selected: _days.contains(i),
                    onSelected: (on) => setState(() {
                      on ? _days.add(i) : _days.remove(i);
                      _daysErr = null;
                    }),
                  ),
              ]),
              if (_daysErr != null || _server['days_of_week'] != null)
                Text(_daysErr ?? _server['days_of_week']!, style: TextStyle(color: err)),
            ],
            const SizedBox(height: 16),
            Text('Reminder times (one or more per day)',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 4, children: [
              for (final t in _times)
                InputChip(label: Text(t), onDeleted: () => setState(() => _times.remove(t))),
              ActionChip(avatar: const Icon(Icons.add), label: const Text('Add time'), onPressed: _addTime),
            ]),
            if (_timesErr != null || _server['times'] != null)
              Text(_timesErr ?? _server['times']!, style: TextStyle(color: err)),
            const SizedBox(height: 8),
            Text(
              'Enter schedules exactly as prescribed by your clinician. MedMinder does not calculate or recommend doses.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _saving ? null : _submit,
              icon: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save),
              label: Text(_saving ? 'Saving…' : 'Save'),
            ),
          ]),
        ),
      ),
    );
  }
}
