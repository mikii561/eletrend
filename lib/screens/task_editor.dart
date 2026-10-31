import 'package:flutter/material.dart';

import '../formatting.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/conflicts.dart';

/// Feladat felvétele vagy szerkesztése alulról felcsúszó lapon.
Future<void> showTaskEditor(BuildContext context, {TaskItem? task, DateTime? due, DateTime? scheduled}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _TaskEditor(task: task, due: due, scheduled: scheduled),
  );
}

class _TaskEditor extends StatefulWidget {
  const _TaskEditor({this.task, this.due, this.scheduled});

  final TaskItem? task;
  final DateTime? due;
  final DateTime? scheduled;

  @override
  State<_TaskEditor> createState() => _TaskEditorState();
}

class _TaskEditorState extends State<_TaskEditor> {
  late final _title = TextEditingController(text: widget.task?.title);
  late DateTime? _due = widget.task?.due ?? widget.due;
  late DateTime? _scheduled = widget.task?.scheduled ?? widget.scheduled;
  late int _duration = widget.task?.durationMin ?? 30;
  late EventCategory _category = widget.task?.category ?? EventCategory.personal;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _pickDue() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _due ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) setState(() => _due = DateTime(picked.year, picked.month, picked.day, 12));
  }

  /// Időblokk: melyik nap, hánykor dolgozol rajta.
  Future<void> _pickSchedule() async {
    final now = DateTime.now();
    final base = _scheduled ?? _due ?? now;
    final day = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      helpText: 'Melyik nap dolgozol rajta?',
    );
    if (day == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: _scheduled == null
          ? TimeOfDay(hour: (now.hour + 1) % 24, minute: 0)
          : TimeOfDay.fromDateTime(_scheduled!),
      helpText: 'Hánykor kezded?',
    );
    if (time == null) return;
    setState(() => _scheduled = DateTime(day.year, day.month, day.day, time.hour, time.minute));
  }

  /// A beosztott időponttal ütköző programok (csak ha be van osztva).
  List<Conflict> _conflicts(AppStore store) {
    final s = _scheduled;
    if (s == null) return const [];
    return store.conflictsFor(start: s, durationMin: _duration, ignoreTaskId: widget.task?.id);
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Mi a teendő?');
      return;
    }
    final store = StoreScope.of(context);
    final navigator = Navigator.of(context);
    if (!await confirmDespiteConflicts(context, _conflicts(store)) || !mounted) return;
    final t = widget.task ?? TaskItem(id: newId(), title: title);
    t
      ..title = title
      ..due = _due
      ..scheduled = _scheduled
      ..durationMin = _duration
      ..category = _category;
    store.saveTask(t);
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.task == null ? 'Új feladat' : 'Feladat', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(
              controller: _title,
              autofocus: widget.task == null,
              maxLength: 200,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(hintText: 'Mit kell megcsinálni?', errorText: _error, counterText: ''),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final c in [
                  EventCategory.personal,
                  EventCategory.work,
                  EventCategory.study,
                  EventCategory.health,
                  EventCategory.important,
                ])
                  ChoiceChip(
                    avatar: Icon(categoryIcon(c), size: 16, color: AppColors.category(c)),
                    label: Text(c.label),
                    selected: _category == c,
                    onSelected: (_) => setState(() => _category = c),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.flag_outlined),
              title: Text(_due == null ? 'Határidő (nem kötelező)' : 'Határidő: ${formatDay(_due!)}'),
              trailing: _due == null
                  ? null
                  : IconButton(
                      tooltip: 'Határidő törlése',
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => _due = null),
                    ),
              onTap: _pickDue,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.view_timeline_outlined),
              title: Text(
                _scheduled == null
                    ? 'Beosztom a naptárba'
                    : '${formatDay(_scheduled!)} ${formatTime(_scheduled!)}, ${formatDuration(_duration)}',
              ),
              subtitle: _scheduled == null ? const Text('Időt foglalsz rá, és a naptárban is látszik.') : null,
              trailing: _scheduled == null
                  ? null
                  : IconButton(
                      tooltip: 'Beosztás törlése',
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => _scheduled = null),
                    ),
              onTap: _pickSchedule,
            ),
            if (_scheduled != null)
              Wrap(
                spacing: 6,
                children: [
                  for (final m in [15, 30, 60, 90, 120])
                    ChoiceChip(
                      label: Text(formatDuration(m)),
                      selected: _duration == m,
                      onSelected: (_) => setState(() => _duration = m),
                    ),
                ],
              ),
            ConflictHint(conflicts: _conflicts(store)),
            const SizedBox(height: 16),
            Row(
              children: [
                if (widget.task != null)
                  TextButton.icon(
                    onPressed: () {
                      store.removeTask(widget.task!);
                      Navigator.pop(context);
                    },
                    icon: Icon(Icons.delete_outline, color: AppColors.danger),
                    label: Text('Törlés', style: TextStyle(color: AppColors.danger)),
                  ),
                const Spacer(),
                FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size(140, 48)),
                  onPressed: _save,
                  child: const Text('Mentés'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Egy feladat a listákban: pipa, cím, határidő/beosztás.
class TaskTile extends StatelessWidget {
  const TaskTile({super.key, required this.task, this.dense = false});

  final TaskItem task;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final t = task;
    final overdue = t.isOverdue();
    final meta = [
      if (t.scheduled != null) '${formatDay(t.scheduled!, short: true)} ${formatTime(t.scheduled!)}',
      if (t.due != null && t.scheduled == null) 'Határidő: ${formatDay(t.due!, short: true)}',
    ];
    return ListTile(
      dense: dense,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      leading: Semantics(
        checked: t.done,
        label: t.done ? 'Kész' : 'Kipipálás',
        child: IconButton(
          tooltip: t.done ? 'Visszavonás' : 'Kész',
          icon: Icon(
            t.done ? Icons.check_circle : Icons.radio_button_unchecked,
            color: t.done ? AppColors.primary : AppColors.textMuted,
          ),
          onPressed: () => store.toggleTask(t),
        ),
      ),
      title: Text(
        t.title,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          decoration: t.done ? TextDecoration.lineThrough : null,
          color: t.done ? AppColors.textMuted : null,
        ),
      ),
      subtitle: meta.isEmpty && !overdue
          ? null
          : Row(
              children: [
                if (overdue) ...[Pill('Lejárt', color: AppColors.danger), const SizedBox(width: 6)],
                Flexible(child: Text(meta.join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis)),
              ],
            ),
      trailing: CategoryDot(AppColors.category(t.category)),
      onTap: () => showTaskEditor(context, task: t),
    );
  }
}
