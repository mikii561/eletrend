import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../formatting.dart';
import '../friends.dart';
import '../geocoding.dart';
import '../models.dart';
import '../social.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/map_view.dart';
import 'location_picker.dart';
import 'social_widgets.dart';

/// Bejegyzés létrehozása vagy szerkesztése. Gyors: elég a cím, minden másnak van jó alapértéke.
class EventEditor extends StatefulWidget {
  const EventEditor({
    super.key,
    this.existing,
    this.initialStart,
    this.initialDurationMin,
    this.initialTitle,
    this.initialCategory,
    this.inviteUids = const [],
    this.social = false,
  });

  final Event? existing;
  final DateTime? initialStart;
  final int? initialDurationMin;
  final String? initialTitle;
  final EventCategory? initialCategory;

  /// Előre kiválasztott meghívottak (pl. a közös időpont keresőből).
  final List<String> inviteUids;

  /// Közös programként indul (a Létrehozás menüből): rögtön látszik a meghívás rész.
  final bool social;

  @override
  State<EventEditor> createState() => _EventEditorState();
}

class _EventEditorState extends State<EventEditor> {
  late final Event? _e = widget.existing;
  late final _title = TextEditingController(text: _e?.title ?? widget.initialTitle);
  late final _notes = TextEditingController(text: _e?.notes ?? '');
  late final _limit = TextEditingController(text: _e?.limit?.toString() ?? '');
  late DateTime _start = _e?.start ?? widget.initialStart ?? _defaultStart();
  late int _duration = _e?.durationMin ?? widget.initialDurationMin ?? 60;
  late bool _allDay = _e?.allDay ?? false;
  late EventCategory _category =
      _e?.category ?? widget.initialCategory ?? (widget.social ? EventCategory.social : EventCategory.personal);
  late int? _color = _e?.color;
  late Repeat _repeat = _e?.repeat ?? Repeat.none;
  late int? _reminder = _e?.reminderMin ?? StoreScope.of(context).defaultReminderMin;
  late bool _busy = _e?.busy ?? true;
  late bool _inviteOnly = _e?.inviteOnly ?? false;
  late Place? _place = _initialPlace();
  late final List<String> _invite = [...widget.inviteUids];
  String? _titleError;
  String? _limitError;
  bool _saving = false;

  static DateTime _defaultStart() {
    final n = DateTime.now().add(const Duration(hours: 1));
    return DateTime(n.year, n.month, n.day, n.hour);
  }

  Place? _initialPlace() {
    final e = _e;
    if (e == null || e.place.isEmpty) return null;
    return Place(name: e.place, point: e.hasLocation ? LatLng(e.lat!, e.lng!) : defaultCenter);
  }

  DateTime get _end => _start.add(Duration(minutes: _duration));

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    _limit.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked == null) return;
    setState(() => _start = DateTime(picked.year, picked.month, picked.day, _start.hour, _start.minute));
  }

  Future<void> _pickStart() async {
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_start));
    if (t != null) setState(() => _start = DateTime(_start.year, _start.month, _start.day, t.hour, t.minute));
  }

  /// A befejezés választásakor az időtartam változik (a kezdés marad).
  Future<void> _pickEnd() async {
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_end));
    if (t == null) return;
    var end = DateTime(_start.year, _start.month, _start.day, t.hour, t.minute);
    if (!end.isAfter(_start)) end = end.add(const Duration(days: 1)); // éjfélen átnyúló
    setState(() => _duration = end.difference(_start).inMinutes);
  }

  Future<void> _pickPlace() async {
    final picked = await Navigator.of(context)
        .push<Place>(MaterialPageRoute(builder: (_) => LocationPicker(initial: _place)));
    if (picked != null) setState(() => _place = picked);
  }

  Future<void> _pickFriends() async {
    final picked = await showFriendPicker(context, action: 'Kész', initial: {..._invite});
    if (picked == null) return;
    setState(
      () => _invite
        ..clear()
        ..addAll(picked),
    );
  }

  Future<void> _save() async {
    if (_saving) return;
    final title = _title.text.trim();
    final limitText = _limit.text.trim();
    final limit = limitText.isEmpty ? null : int.tryParse(limitText);
    setState(() {
      _titleError = title.isEmpty ? 'Adj neki címet.' : null;
      _limitError = limitText.isNotEmpty && (limit == null || limit < 2 || limit > 500)
          ? '2 és 500 közötti szám legyen.'
          : null;
    });
    if (_titleError != null || _limitError != null) return;

    final store = StoreScope.of(context);
    final navigator = Navigator.of(context);
    final e = _e ?? Event(id: newId(), title: '', start: _start);
    e
      ..title = title.length > 100 ? title.substring(0, 100) : title
      ..start = _allDay ? DateTime(_start.year, _start.month, _start.day) : _start
      ..durationMin = _allDay ? 1440 : _duration
      ..allDay = _allDay
      ..category = _category
      ..color = _color
      ..repeat = _repeat
      ..reminderMin = _reminder
      ..busy = _busy
      ..place = _place?.name ?? ''
      ..lat = _place == null || _place!.point == defaultCenter ? null : _place!.point.latitude
      ..lng = _place == null || _place!.point == defaultCenter ? null : _place!.point.longitude
      ..notes = _notes.text.trim()
      ..limit = limit
      ..inviteOnly = _inviteOnly;
    store.saveEvent(e);

    setState(() => _saving = true);
    try {
      // A megosztott példányt is frissítjük, hogy a meghívottak a változást lássák.
      if (e.shareId != null) await Social.instance.publish(e, ownerName: store.myName);
      if (_invite.isNotEmpty && mounted) await inviteFriendsTo(context, e, _invite);
    } catch (err) {
      if (mounted) showSocialError(context, err);
    }
    if (mounted) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final color = _color != null ? Color(_color!) : AppColors.category(_category);
    final social = widget.social || _invite.isNotEmpty || _e?.shareId != null;
    return Scaffold(
      appBar: AppBar(title: Text(_e == null ? (widget.social ? 'Közös program' : 'Új bejegyzés') : 'Szerkesztés')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Mentés…' : (_invite.isNotEmpty ? 'Mentés és meghívás' : 'Mentés')),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          TextField(
            controller: _title,
            autofocus: _e == null && widget.initialTitle == null,
            textCapitalization: TextCapitalization.sentences,
            maxLength: 100,
            style: Theme.of(context).textTheme.titleMedium,
            decoration: InputDecoration(
              hintText: widget.social ? 'Mi a program? (pl. Mozi, foci, vacsora)' : 'Cím (pl. Fogorvos, Edzés)',
              prefixIcon: Icon(categoryIcon(_category), color: color),
              errorText: _titleError,
              counterText: '',
            ),
            onChanged: (_) {
              if (_titleError != null) setState(() => _titleError = null);
            },
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final c in EventCategory.values)
                ChoiceChip(
                  showCheckmark: false,
                  avatar: Icon(categoryIcon(c), size: 16, color: AppColors.category(c)),
                  label: Text(c.label),
                  selected: _category == c,
                  onSelected: (_) => setState(() => _category = c),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.wb_sunny_outlined),
                  title: const Text('Egész nap'),
                  value: _allDay,
                  onChanged: (v) => setState(() {
                    _allDay = v;
                    // Egész napos dolgok (pl. szülinap) alapból nem foglalnak.
                    if (v) _busy = false;
                  }),
                ),
                ListTile(
                  leading: const Icon(Icons.calendar_today_outlined),
                  title: Text(formatDay(_start)),
                  subtitle: Text(DateFormat('yyyy. MMMM d., EEEE', 'hu').format(_start)),
                  onTap: _pickDate,
                ),
                if (!_allDay)
                  Row(
                    children: [
                      Expanded(
                        child: ListTile(
                          leading: const Icon(Icons.schedule),
                          title: Text(formatTime(_start)),
                          subtitle: const Text('Kezdés'),
                          onTap: _pickStart,
                        ),
                      ),
                      Expanded(
                        child: ListTile(
                          title: Text(formatTime(_end)),
                          subtitle: Text('Vége · ${formatDuration(_duration)}'),
                          onTap: _pickEnd,
                        ),
                      ),
                    ],
                  ),
                ListTile(
                  leading: const Icon(Icons.repeat),
                  title: DropdownButtonHideUnderline(
                    child: DropdownButton<Repeat>(
                      value: _repeat,
                      isExpanded: true,
                      items: [
                        for (final r in Repeat.values)
                          DropdownMenuItem(value: r, child: Text(r == Repeat.none ? r.label : repeatLabel(r, _start))),
                      ],
                      onChanged: (r) => setState(() => _repeat = r ?? Repeat.none),
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.notifications_none),
                  title: DropdownButtonHideUnderline(
                    child: DropdownButton<int?>(
                      value: _reminder,
                      isExpanded: true,
                      items: [
                        for (final m in {...reminderOptions, _reminder})
                          DropdownMenuItem(value: m, child: Text(reminderLabel(m))),
                      ],
                      onChanged: (m) => setState(() => _reminder = m),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.location_on_outlined),
                  title: Text(
                    _place?.name ?? 'Helyszín',
                    style: TextStyle(color: _place == null ? AppColors.textMuted : null),
                  ),
                  trailing: _place == null
                      ? const Icon(Icons.map_outlined)
                      : IconButton(
                          tooltip: 'Helyszín törlése',
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(() => _place = null),
                        ),
                  onTap: _pickPlace,
                ),
                if (_place != null && _place!.point != defaultCenter)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    child: MapPreview(point: _place!.point, height: 120, onTap: _pickPlace),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: TextField(
                    controller: _notes,
                    minLines: 1,
                    maxLines: 5,
                    maxLength: 1000,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      hintText: 'Jegyzet, leírás',
                      prefixIcon: Icon(Icons.notes),
                      counterText: '',
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SectionTitle('Megjelenés és adatvédelem'),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _Swatch(
                        color: AppColors.category(_category),
                        selected: _color == null,
                        label: 'Kategória',
                        onTap: () => setState(() => _color = null),
                      ),
                      for (final c in AppColors.customColors)
                        _Swatch(color: Color(c), selected: _color == c, onTap: () => setState(() => _color = c)),
                    ],
                  ),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.event_busy_outlined),
                  title: const Text('Foglaltnak mutat'),
                  subtitle: const Text('A barátaid csak annyit látnak, hogy foglalt vagy; a címet, helyet soha.'),
                  value: _busy,
                  onChanged: (v) => setState(() => _busy = v),
                ),
              ],
            ),
          ),
          if (social || Friends.instance.ready) ...[
            const SectionTitle('Barátokkal'),
            Card(
              margin: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ListTile(
                    leading: Icon(Icons.group_add_outlined, color: AppColors.primary),
                    title: Text(
                      _invite.isEmpty ? 'Barátok meghívása' : 'Meghívod: ${_invite.map(store.nameOf).join(', ')}',
                      style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                    ),
                    subtitle: _e?.shareId != null
                        ? const Text('Már közös program; itt újabb barátokat hívhatsz.')
                        : null,
                    onTap: _pickFriends,
                  ),
                  if (social) ...[
                    SwitchListTile(
                      secondary: const Icon(Icons.lock_outline),
                      title: const Text('Csak a meghívottak láthatják'),
                      subtitle: const Text('Kikapcsolva a meghívólinkkel bárki visszajelezhet.'),
                      value: _inviteOnly,
                      onChanged: (v) => setState(() => _inviteOnly = v),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: TextField(
                        controller: _limit,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Létszámkorlát (nem kötelező)',
                          prefixIcon: const Icon(Icons.groups_outlined),
                          errorText: _limitError,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.color, required this.selected, required this.onTap, this.label});

  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label ?? 'Szín',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: selected ? AppColors.text : Colors.transparent, width: 2.5),
          ),
          child: selected ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
        ),
      ),
    );
  }
}
