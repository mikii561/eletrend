import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../geocoding.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/map_view.dart';
import 'location_picker.dart';

/// Közös programok listája.
class EventsScreen extends StatelessWidget {
  const EventsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final upcoming = store.upcomingEvents;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Programok'),
        actions: [
          IconButton.filledTonal(
            tooltip: 'Barátok',
            icon: const Icon(Icons.people_alt_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FriendsScreen())),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EventEditor())),
        icon: const Icon(Icons.add),
        label: const Text('Új program', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
        children: [
          if (upcoming.isEmpty)
            EmptyState(
              emoji: '🎉',
              text: 'Nincs tervezett program.\nMozi, főzés, túra? Hívd meg a barátaidat!',
              action: 'Program szervezése',
              onAction: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EventEditor())),
            )
          else
            for (final e in upcoming) EventCard(event: e),
        ],
      ),
    );
  }
}

/// Programkártya a listákban; koppintásra a részletek nyílnak meg.
class EventCard extends StatelessWidget {
  const EventCard({super.key, required this.event});

  final Event event;

  @override
  Widget build(BuildContext context) {
    final e = event;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => EventDetail(event: e))),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              DateBadge(e.date),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.title, style: Theme.of(context).textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    _IconLine(Icons.schedule, DateFormat('EEEE HH:mm', 'hu').format(e.date)),
                    if (e.place.isNotEmpty) _IconLine(Icons.location_on_outlined, e.place),
                  ],
                ),
              ),
              if (e.invited.isNotEmpty) AvatarStack(e.invited, max: 3),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconLine extends StatelessWidget {
  const _IconLine(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Icon(icon, size: 15, color: AppColors.textMuted),
          const SizedBox(width: 4),
          Expanded(
            child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textMuted)),
          ),
        ],
      ),
    );
  }
}

/// Egy program részletei térképpel.
class EventDetail extends StatelessWidget {
  const EventDetail({super.key, required this.event});

  final Event event;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final e = event;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: 'Szerkesztés',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => EventEditor(existing: e))),
          ),
          IconButton(
            tooltip: 'Törlés',
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Törlöd a programot?'),
                  content: Text(e.title),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Mégse')),
                    FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Törlés')),
                  ],
                ),
              );
              if (ok == true && context.mounted) {
                store.removeEvent(e);
                Navigator.pop(context);
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Row(
            children: [
              DateBadge(e.date, size: 64),
              const SizedBox(width: 16),
              Expanded(child: Text(e.title, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800))),
            ],
          ),
          const SizedBox(height: 20),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.schedule, color: AppColors.primary),
                  title: Text(DateFormat('yyyy. MMMM d., EEEE', 'hu').format(e.date)),
                  subtitle: Text(DateFormat('HH:mm', 'hu').format(e.date)),
                ),
                if (e.place.isNotEmpty)
                  ListTile(
                    leading: const Icon(Icons.location_on_outlined, color: AppColors.accent),
                    title: Text(e.place),
                  ),
              ],
            ),
          ),
          if (e.hasLocation) ...[
            const SizedBox(height: 8),
            MapPreview(point: LatLng(e.lat!, e.lng!), height: 200),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              onPressed: () => launchUrl(
                Uri.https('www.google.com', '/maps/dir/', {'api': '1', 'destination': '${e.lat},${e.lng}'}),
                mode: LaunchMode.externalApplication,
              ),
              icon: const Icon(Icons.directions),
              label: const Text('Útvonal Google Térképpel'),
            ),
          ],
          const SectionTitle('Meghívottak'),
          if (e.invited.isEmpty)
            const Card(child: ListTile(title: Text('Még senkit nem hívtál meg.', style: TextStyle(color: AppColors.textMuted))))
          else
            Card(
              child: Column(
                children: [
                  for (final f in e.invited) ListTile(leading: NameAvatar(f), title: Text(f)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Program létrehozása vagy szerkesztése.
class EventEditor extends StatefulWidget {
  const EventEditor({super.key, this.existing});

  final Event? existing;

  @override
  State<EventEditor> createState() => _EventEditorState();
}

class _EventEditorState extends State<EventEditor> {
  late final _title = TextEditingController(text: widget.existing?.title);
  late DateTime _date = widget.existing?.date ?? DateTime.now().add(const Duration(days: 1));
  late TimeOfDay _time = widget.existing == null
      ? const TimeOfDay(hour: 18, minute: 0)
      : TimeOfDay.fromDateTime(widget.existing!.date);
  late final Set<String> _invited = {...?widget.existing?.invited};
  late Place? _place = _initialPlace();

  Place? _initialPlace() {
    final e = widget.existing;
    if (e == null || e.place.isEmpty) return null;
    return Place(name: e.place, point: e.hasLocation ? LatLng(e.lat!, e.lng!) : defaultCenter);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _pickPlace() async {
    final picked = await Navigator.of(context).push<Place>(
      MaterialPageRoute(builder: (_) => LocationPicker(initial: _place)),
    );
    if (picked != null) setState(() => _place = picked);
  }

  void _save() {
    if (_title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Adj nevet a programnak.')));
      return;
    }
    final e = widget.existing ?? Event(id: newId(), title: '', date: _date);
    e
      ..title = _title.text.trim()
      ..date = DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute)
      ..place = _place?.name ?? ''
      ..lat = _place?.point.latitude
      ..lng = _place?.point.longitude
      ..invited = _invited.toList();
    StoreScope.of(context).saveEvent(e);
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final theme = Theme.of(context);
    final place = _place;
    return Scaffold(
      appBar: AppBar(title: Text(widget.existing == null ? 'Új program' : 'Program szerkesztése')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: FilledButton(onPressed: _save, child: const Text('Mentés')),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          TextField(
            controller: _title,
            textCapitalization: TextCapitalization.sentences,
            style: theme.textTheme.titleMedium,
            decoration: const InputDecoration(
              hintText: 'Mi a program? (pl. Mozi, közös főzés)',
              prefixIcon: Icon(Icons.celebration_outlined),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _PickerTile(
                  icon: Icons.calendar_today_outlined,
                  label: 'Nap',
                  value: DateFormat('MMM d., EEE', 'hu').format(_date),
                  onTap: _pickDate,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _PickerTile(icon: Icons.schedule, label: 'Időpont', value: _time.format(context), onTap: _pickTime),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Helyszín
          Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.location_on_outlined, color: AppColors.accent),
                  title: Text(place?.name ?? 'Helyszín kiválasztása a térképen',
                      style: TextStyle(fontWeight: FontWeight.w700, color: place == null ? AppColors.textMuted : null)),
                  trailing: place == null
                      ? const Icon(Icons.map_outlined)
                      : IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _place = null)),
                  onTap: _pickPlace,
                ),
                if (place != null && place.point != defaultCenter)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    child: MapPreview(point: place.point, height: 140, onTap: _pickPlace),
                  ),
              ],
            ),
          ),

          // Meghívottak
          SectionTitle('Kiket hívsz meg?', trailing: _invited.isEmpty ? null : '${_invited.length}'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final f in store.friends)
                FilterChip(
                  avatar: NameAvatar(f, radius: 12),
                  label: Text(f),
                  selected: _invited.contains(f),
                  onSelected: (on) => setState(() => on ? _invited.add(f) : _invited.remove(f)),
                ),
              ActionChip(
                avatar: const Icon(Icons.person_add_alt_1, size: 18),
                label: const Text('Új barát'),
                onPressed: () async {
                  final name = await showTextInputSheet(context, title: 'Új barát', hint: 'Név', action: 'Hozzáadás');
                  if (name == null || name.trim().isEmpty) return;
                  store.addFriend(name);
                  setState(() => _invited.add(name.trim()));
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({required this.icon, required this.label, required this.value, required this.onTap});

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primary),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Barátlista kezelése.
class FriendsScreen extends StatelessWidget {
  const FriendsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Barátok')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final name = await showTextInputSheet(context, title: 'Új barát', hint: 'Név', action: 'Hozzáadás');
          if (name != null) store.addFriend(name);
        },
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Új barát', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
        children: [
          if (store.friends.isEmpty)
            const EmptyState(emoji: '👋', text: 'Még nincs barátod a listán.\nAdd hozzá, akikkel programokat szervezel!')
          else
            Card(
              child: Column(
                children: [
                  for (final f in store.friends)
                    ListTile(
                      leading: NameAvatar(f, radius: 20),
                      title: Text(f, style: const TextStyle(fontWeight: FontWeight.w700)),
                      trailing: IconButton(
                        tooltip: 'Eltávolítás',
                        icon: const Icon(Icons.close, color: AppColors.textMuted),
                        onPressed: () => store.removeFriend(f),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
