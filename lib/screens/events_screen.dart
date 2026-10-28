import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../calendar_link.dart';
import '../community.dart';
import '../event_background.dart';
import '../photos.dart';
import '../geocoding.dart';
import '../models.dart';
import '../social.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/map_view.dart';
import '../widgets/weather_tile.dart';
import 'community_screen.dart';
import 'costs_section.dart';
import 'idea_sheet.dart';
import 'invite_screen.dart';
import 'location_picker.dart';
import 'social_widgets.dart';

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
          IconButton(
            tooltip: 'Közösségi ötletek',
            icon: const Icon(Icons.lightbulb_outline),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CommunityIdeasScreen())),
          ),
          IconButton.filledTonal(
            tooltip: 'Ötlet',
            icon: const Icon(Icons.casino_outlined),
            onPressed: () => showIdeaSheet(context),
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
              text: 'Nincs tervezett program.\nNem tudjátok, mit csináljatok? Dobj egy ötletet!',
              action: '🎲 Ötletet kérek',
              onAction: () => showIdeaSheet(context),
            )
          else
            for (final e in upcoming) EventCard(event: e),
          if (store.invites.isNotEmpty) ...[
            const SectionTitle('Meghívásaim'),
            for (final i in store.invites)
              Card(
                child: ListTile(
                  leading: DateBadge(i.date),
                  title: Text(i.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(DateFormat('EEEE HH:mm', 'hu').format(i.date)),
                  trailing: PopupMenuButton<String>(
                    onSelected: (_) => store.removeInvite(i.id),
                    itemBuilder: (_) => const [PopupMenuItem(value: 'remove', child: Text('Eltávolítás a listából'))],
                  ),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => InviteScreen(eventId: i.id))),
                ),
              ),
          ],
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
    final next = e.nextDate();
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => EventDetail(event: e))),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              DateBadge(next),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.title, style: Theme.of(context).textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    _IconLine(
                      e.repeat == Repeat.none ? Icons.schedule : Icons.repeat,
                      [DateFormat('EEEE HH:mm', 'hu').format(next), if (e.repeat != Repeat.none) repeatLabel(e)].join(' • '),
                    ),
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
            child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.textMuted)),
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
    final next = e.nextDate();
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
                // A meghívólink is megszűnik (ha nincs internet, a felhőben marad, de nem baj).
                if (e.shareId != null) unawaited(Social.instance.unpublish(e.shareId!).catchError((_) {}));
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
          if (e.bgTheme != null || e.bgImage != null)
            // Egyedi háttér: a cím a kép\/téma fölött.
            SizedBox(
              height: 170,
              child: EventBackdrop(
                theme: e.bgTheme,
                image: e.bgImage,
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        DateBadge(next, size: 58),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(e.title,
                              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900, color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          else
            Row(
              children: [
                DateBadge(next, size: 64),
                const SizedBox(width: 16),
                Expanded(child: Text(e.title, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800))),
              ],
            ),
          const SizedBox(height: 20),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.schedule, color: AppColors.primary),
                  title: Text(DateFormat('yyyy. MMMM d., EEEE', 'hu').format(next)),
                  subtitle: Text(DateFormat('HH:mm', 'hu').format(next)),
                ),
                if (e.repeat != Repeat.none)
                  ListTile(
                    leading: Icon(Icons.repeat, color: AppColors.primary),
                    title: Text(repeatLabel(e)),
                    subtitle: const Text('Mindig a következő alkalom látszik'),
                  ),
                if (e.place.isNotEmpty)
                  ListTile(
                    leading: const Icon(Icons.location_on_outlined, color: AppColors.accent),
                    title: Text(e.place),
                  ),
                if (e.hasLocation) WeatherTile(lat: e.lat!, lng: e.lng!, at: next),
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
          const SizedBox(height: 8),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            onPressed: () => launchUrl(
              googleCalendarLink(
                title: e.title,
                start: next,
                place: e.place,
                repeat: e.repeat,
                details: e.shareId == null ? '' : 'Visszajelzés: ${Social.instance.linkFor(e.shareId!)}',
              ),
              mode: LaunchMode.externalApplication,
            ),
            icon: const Icon(Icons.event_available_outlined),
            label: const Text('Mentés a naptárba'),
          ),
          TextButton.icon(
            onPressed: () => showShareIdeaSheet(
              context,
              title: e.title,
              place: e.hasLocation ? IdeaPlace(name: e.place, lat: e.lat, lng: e.lng) : null,
            ),
            icon: const Icon(Icons.lightbulb_outline),
            label: const Text('Megosztom ötletként mindenkivel'),
          ),
          const SectionTitle('Meghívottak'),
          if (e.invited.isEmpty)
            Card(child: ListTile(title: Text('Még senkit nem hívtál meg.', style: TextStyle(color: AppColors.textMuted))))
          else
            Card(
              child: Column(
                children: [
                  for (final f in e.invited) ListTile(leading: NameAvatar(f), title: Text(f)),
                ],
              ),
            ),
          OwnerSocialSection(event: e),
          CostsSection(event: e),
        ],
      ),
    );
  }
}

/// Program létrehozása vagy szerkesztése.
class EventEditor extends StatefulWidget {
  const EventEditor({super.key, this.existing, this.initialTitle, this.initialPlace});

  final Event? existing;

  /// Új programnál előre kitöltött név (pl. az ötletadóból).
  final String? initialTitle;

  /// Új programnál előre kitöltött helyszín (pl. egy közösségi ötletből).
  final Place? initialPlace;

  @override
  State<EventEditor> createState() => _EventEditorState();
}

class _EventEditorState extends State<EventEditor> {
  late final _title = TextEditingController(text: widget.existing?.title ?? widget.initialTitle);
  late Repeat _repeat = widget.existing?.repeat ?? Repeat.none;
  late DateTime _date = widget.existing?.date ?? DateTime.now().add(const Duration(days: 1));
  late TimeOfDay _time = widget.existing == null
      ? const TimeOfDay(hour: 18, minute: 0)
      : TimeOfDay.fromDateTime(widget.existing!.date);
  late final Set<String> _invited = {...?widget.existing?.invited};
  late Place? _place = _initialPlace();
  late String? _bgTheme = widget.existing?.bgTheme;
  late String? _bgImage = widget.existing?.bgImage;
  String? _bgError;

  Future<void> _pickBackground() async {
    try {
      final image = await EventBackgrounds.pick(ImageSource.gallery);
      if (image != null) {
        setState(() {
          _bgImage = image;
          _bgError = null;
        });
      } else if (mounted) {
        setState(() => _bgError = null);
      }
    } catch (e) {
      if (mounted) setState(() => _bgError = 'Ezt a képet nem tudom megnyitni. Próbálj JPG-t vagy PNG-t.');
    }
  }

  Place? _initialPlace() {
    final e = widget.existing;
    if (e == null) return widget.initialPlace;
    if (e.place.isEmpty) return null;
    return Place(name: e.place, point: e.hasLocation ? LatLng(e.lat!, e.lng!) : defaultCenter);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      // Egy régebben kezdődött ismétlődő program első napja is maradhasson.
      firstDate: _date.isBefore(DateTime.now()) ? _date : DateTime.now().subtract(const Duration(days: 1)),
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
      ..invited = _invited.toList()
      ..repeat = _repeat
      ..bgTheme = _bgTheme
      ..bgImage = _bgImage;
    final store = StoreScope.of(context);
    store.saveEvent(e);
    // A megosztott példányt is frissítjük, hogy a meghívottak a változást lássák.
    if (e.shareId != null) unawaited(Social.instance.publish(e, ownerName: store.myName).then((_) {}, onError: (_) {}));
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
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.repeat, color: AppColors.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _repeat == Repeat.none
                              ? 'Ismétlődés'
                              : repeatLabel(Event(id: '', title: '', date: _date, repeat: _repeat)),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final r in Repeat.values)
                        ChoiceChip(
                          label: Text(r == Repeat.none ? 'Egyszeri' : r.label),
                          selected: _repeat == r,
                          onSelected: (_) => setState(() => _repeat = r),
                        ),
                    ],
                  ),
                ],
              ),
            ),
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

          // Háttér
          const SectionTitle('Háttér'),
          SizedBox(
            height: 64,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _BgSwatch(
                  selected: _bgTheme == null && _bgImage == null,
                  onTap: () => setState(() {
                    _bgTheme = null;
                    _bgImage = null;
                  }),
                  colors: const [Color(0xFF9E9E9E), Color(0xFF757575)],
                  child: const Icon(Icons.block, color: Colors.white70),
                ),
                _BgSwatch(
                  selected: _bgImage != null,
                  onTap: _pickBackground,
                  image: _bgImage,
                  colors: const [Color(0xFF5B5BD6), Color(0xFF9B6BE0)],
                  child: _bgImage == null ? const Icon(Icons.add_photo_alternate_outlined, color: Colors.white) : null,
                ),
                for (final t in backgroundThemes)
                  _BgSwatch(
                    selected: _bgImage == null && _bgTheme == t.key,
                    onTap: () => setState(() {
                      _bgTheme = t.key;
                      _bgImage = null;
                    }),
                    colors: t.colors,
                    child: Text(t.emoji, style: const TextStyle(fontSize: 24)),
                  ),
              ],
            ),
          ),
          if (_bgError != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(_bgError!, style: TextStyle(color: Colors.red.shade400, fontWeight: FontWeight.w600)),
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                    Text(value,
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// „minden csütörtökön” alakhoz: hétfőnként, keddenként…
String weekdayEvery(int weekday) => const [
      'hétfőnként',
      'keddenként',
      'szerdánként',
      'csütörtökönként',
      'péntekenként',
      'szombatonként',
      'vasárnaponként',
    ][weekday - 1];

/// Az ismétlődés olvasható leírása, pl. „Hetente, csütörtökönként”.
String repeatLabel(Event e) => switch (e.repeat) {
      Repeat.none => '',
      Repeat.weekly => 'Hetente, ${weekdayEvery(e.date.weekday)}',
      Repeat.biweekly => 'Kéthetente, ${weekdayEvery(e.date.weekday)}',
      Repeat.monthly => 'Havonta, minden hónap ${e.date.day}. napján',
    };

/// Egy háttér-választó négyzet.
class _BgSwatch extends StatelessWidget {
  const _BgSwatch({required this.selected, required this.onTap, required this.colors, this.child, this.image});

  final bool selected;
  final VoidCallback onTap;
  final List<Color> colors;
  final Widget? child;
  final String? image;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 64,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? AppColors.primary : Colors.transparent, width: 3),
            gradient: image == null ? LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight) : null,
            image: image == null ? null : DecorationImage(image: MemoryImage(TagImages.decode(image!)), fit: BoxFit.cover),
          ),
          alignment: Alignment.center,
          child: child,
        ),
      ),
    );
  }
}
