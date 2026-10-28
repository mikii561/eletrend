import 'package:flutter/material.dart';

import '../habit_templates.dart';
import '../models.dart';
import '../notifications.dart';
import '../store.dart';
import '../theme.dart';

/// Új szokás felvétele vagy egy meglévő módosítása: név, gyakoriság, mennyiség, emlékeztető.
Future<void> showHabitEditor(BuildContext context, {Habit? habit}) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _HabitEditor(store: StoreScope.of(context), habit: habit),
    );

class _HabitEditor extends StatefulWidget {
  const _HabitEditor({required this.store, this.habit});

  final AppStore store;
  final Habit? habit;

  @override
  State<_HabitEditor> createState() => _HabitEditorState();
}

class _HabitEditorState extends State<_HabitEditor> {
  late final _name = TextEditingController(text: widget.habit?.name);
  late final _unit = TextEditingController(text: widget.habit?.unit);
  late bool _weekly = widget.habit?.isWeekly ?? false;
  late int _perWeek = widget.habit?.perWeek ?? 3;
  late bool _counted = widget.habit?.isCounted ?? false;
  late int _target = widget.habit?.isCounted == true ? widget.habit!.target : 8;
  late TimeOfDay? _reminder = widget.habit?.reminderMinutes == null
      ? null
      : TimeOfDay(hour: widget.habit!.reminderMinutes! ~/ 60, minute: widget.habit!.reminderMinutes! % 60);
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _unit.dispose();
    super.dispose();
  }

  Future<void> _pickReminder() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _reminder ?? const TimeOfDay(hour: 9, minute: 0),
      helpText: 'Mikor emlékeztesselek?',
    );
    if (picked != null) setState(() => _reminder = picked);
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) return setState(() => _error = 'Adj nevet a szokásnak');
    final reminder = _reminder == null ? null : _reminder!.hour * 60 + _reminder!.minute;
    final h = widget.habit;
    if (h == null) {
      widget.store.addHabit(
        name,
        perWeek: _weekly ? _perWeek : null,
        target: _counted ? _target : 1,
        unit: _counted ? _unit.text : '',
        reminderMinutes: reminder,
      );
    } else {
      final wasCounted = h.isCounted;
      h
        ..name = name
        ..perWeek = _weekly ? _perWeek : null
        ..target = _counted ? _target : 1
        ..unit = _counted ? _unit.text.trim() : ''
        ..reminderMinutes = reminder;
      // Ha a napi mennyiség változott, a napok „kész” állapotát újraszámoljuk.
      if (_counted) {
        // Eddig sima pipa volt: a kipipált napok teljes adagnak számítanak.
        if (!wasCounted) {
          for (final d in h.doneDays) {
            h.counts[d] = h.target;
          }
        }
        h.counts.updateAll((_, n) => n > h.target ? h.target : n);
        h.doneDays = {for (final e in h.counts.entries) if (e.value >= h.target) e.key};
      } else {
        h.doneDays.addAll([for (final e in h.counts.entries) if (e.value > 0) e.key]);
        h.counts.clear();
      }
      widget.store.updateHabit(h);
    }
    if (reminder != null) Notifications.requestPermission();
    Navigator.pop(context);
  }

  Widget _stepper(int value, int min, int max, ValueChanged<int> onChanged) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton.outlined(
            tooltip: 'Kevesebb',
            onPressed: value > min ? () => onChanged(value - 1) : null,
            icon: const Icon(Icons.remove),
          ),
          SizedBox(
            width: 40,
            child: Text('$value', textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          ),
          IconButton.outlined(
            tooltip: 'Több',
            onPressed: value < max ? () => onChanged(value + 1) : null,
            icon: const Icon(Icons.add),
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.habit == null ? 'Új szokás' : 'Szokás szerkesztése', style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              autofocus: widget.habit == null,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: 'Név', hintText: 'pl. Víz, Edzés, 10 perc olvasás', errorText: _error),
              onChanged: (_) => setState(() => _error = null),
            ),
            const SizedBox(height: 20),

            Text('Milyen gyakran?', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: false, label: Text('Minden nap')),
                ButtonSegment(value: true, label: Text('Hetente')),
              ],
              selected: {_weekly},
              onSelectionChanged: (s) => setState(() => _weekly = s.first),
            ),
            if (_weekly) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Expanded(child: Text('Hány napon egy héten?', style: TextStyle(fontWeight: FontWeight.w600))),
                  _stepper(_perWeek, 1, 6, (v) => setState(() => _perWeek = v)),
                ],
              ),
            ],
            const SizedBox(height: 20),

            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Mennyiség naponta', style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text('Pl. 8 pohár víz: minden pohárnál egy koppintás.'),
              value: _counted,
              onChanged: (on) => setState(() => _counted = on),
            ),
            if (_counted)
              Row(
                children: [
                  _stepper(_target, 2, 30, (v) => setState(() => _target = v)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _unit,
                      decoration: const InputDecoration(labelText: 'Egység', hintText: 'pl. pohár, oldal, perc'),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 12),

            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Saját emlékeztető', style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(_reminder == null
                  ? 'Értesítés a telefonon, ha még nincs kész.'
                  : 'Minden nap ${_reminder!.format(context)}-kor, ha még nincs kész.'),
              value: _reminder != null,
              onChanged: (on) => on ? _pickReminder() : setState(() => _reminder = null),
            ),
            if (_reminder != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _pickReminder,
                  icon: const Icon(Icons.schedule),
                  label: Text('Időpont: ${_reminder!.format(context)}'),
                ),
              ),
            if (!Notifications.supported)
              Text('Az emlékeztető csak a telefonos appban működik.', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            const SizedBox(height: 20),
            FilledButton(onPressed: _save, child: const Text('Mentés')),
          ],
        ),
      ),
    );
  }
}

/// Szokás-sablonok: egy csomag egy koppintással felvehető (a már meglévő nevűeket kihagyja).
Future<void> showHabitTemplates(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final store = StoreScope.of(context);
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.8,
          maxChildSize: 0.95,
          builder: (_, controller) => ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              Text('Szokás-sablonok', style: Theme.of(sheetContext).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text('Válassz egy csomagot; utána bármelyik szokást átírhatod vagy törölheted.',
                  style: TextStyle(color: AppColors.textMuted)),
              const SizedBox(height: 12),
              for (final pack in habitPacks)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${pack.emoji} ${pack.title}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                        Text(pack.text, style: TextStyle(color: AppColors.textMuted)),
                        const SizedBox(height: 8),
                        for (final h in pack.habits)
                          Text([
                            '• ${h.name}',
                            if (h.target > 1) '(${h.target} ${h.unit})',
                            if (h.perWeek != null) '(hetente ${h.perWeek}×)',
                          ].join(' ')),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton.tonal(
                            onPressed: () {
                              final existing = {for (final h in store.habits) h.name.toLowerCase()};
                              var added = 0;
                              for (final h in pack.habits) {
                                if (existing.contains(h.name.toLowerCase())) continue;
                                store.addHabit(h.name, perWeek: h.perWeek, target: h.target, unit: h.unit);
                                added++;
                              }
                              Navigator.pop(sheetContext);
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text(added == 0 ? 'Ezek már mind megvannak. 🙂' : '$added új szokás felvéve. Hajrá! 💪'),
                              ));
                            },
                            child: const Text('Felvétel'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
