import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../formatting.dart';
import '../models.dart';
import '../social.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/map_view.dart';
import 'event_editor.dart';
import 'social_widgets.dart';

/// Egy bejegyzés fejléce: színes csík, cím, idő, ismétlődés, hely, jegyzet, térkép.
class EventHeader extends StatelessWidget {
  const EventHeader({
    super.key,
    required this.title,
    required this.color,
    required this.icon,
    required this.start,
    required this.end,
    this.allDay = false,
    this.repeat = Repeat.none,
    this.place = '',
    this.notes = '',
    this.lat,
    this.lng,
    this.extra,
  });

  final String title;
  final Color color;
  final IconData icon;
  final DateTime start;
  final DateTime end;
  final bool allDay;
  final Repeat repeat;
  final String place;
  final String notes;
  final double? lat;
  final double? lng;

  /// Egy további sor (pl. „Szervező: Anna”).
  final String? extra;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          clipBehavior: Clip.antiAlias,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 6, color: color),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(icon, size: 18, color: color),
                            const SizedBox(width: 6),
                            Expanded(child: Text(title, style: theme.textTheme.titleLarge)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _Line(Icons.calendar_today_outlined, formatDay(start)),
                        _Line(Icons.schedule, formatRange(start, end, allDay: allDay)),
                        if (repeat != Repeat.none) _Line(Icons.repeat, repeatLabel(repeat, start)),
                        if (place.isNotEmpty) _Line(Icons.location_on_outlined, place),
                        if (extra != null) _Line(Icons.person_outline, extra!),
                        if (notes.isNotEmpty) ...[const SizedBox(height: 8), Text(notes)],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (lat != null && lng != null) ...[
          const SizedBox(height: 8),
          MapPreview(point: LatLng(lat!, lng!), height: 160),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => launchUrl(
              Uri.https('www.google.com', '/maps/dir/', {'api': '1', 'destination': '$lat,$lng'}),
              mode: LaunchMode.externalApplication,
            ),
            icon: const Icon(Icons.directions_outlined),
            label: const Text('Útvonal'),
          ),
        ],
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.textMuted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: TextStyle(color: AppColors.textMuted)),
        ),
      ],
    ),
  );
}

/// Egy saját bejegyzés részletei. Ismétlődőnél a megnyitott alkalom ([start]) látszik.
class EventDetailScreen extends StatelessWidget {
  const EventDetailScreen({super.key, required this.eventId, this.start});

  final String eventId;
  final DateTime? start;

  Future<void> _delete(BuildContext context, Event e, DateTime occurrence) async {
    final store = StoreScope.of(context);
    final navigator = Navigator.of(context);
    if (e.repeat != Repeat.none) {
      final choice = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.event_busy_outlined),
                title: const Text('Csak ezt az alkalmat'),
                subtitle: Text(formatDay(occurrence)),
                onTap: () => Navigator.pop(context, 'one'),
              ),
              ListTile(
                leading: Icon(Icons.delete_outline, color: AppColors.danger),
                title: Text('Az összes alkalmat', style: TextStyle(color: AppColors.danger)),
                onTap: () => Navigator.pop(context, 'all'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
      if (choice == null) return;
      if (choice == 'one') {
        store.skipOccurrence(e, occurrence);
        navigator.pop();
        return;
      }
    } else if (!context.mounted ||
        !await confirm(context, title: 'Törlöd?', text: e.title, action: 'Törlés', danger: true)) {
      return;
    }
    // A közös példányt is töröljük, ha én szerveztem (ha nincs internet, a felhőben marad, de nem baj).
    final shareId = e.shareId;
    if (shareId != null && !e.id.startsWith('inv-')) {
      unawaited(Social.instance.unpublish(shareId).catchError((_) {}));
    }
    store.removeEvent(e);
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final e = store.eventById(eventId);
    if (e == null) {
      return Scaffold(
        appBar: AppBar(),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: const [EmptyState(emoji: '🗓️', text: 'Ez a bejegyzés már nem létezik.')],
        ),
      );
    }
    final occurrence = start ?? e.nextOccurrence()?.start ?? e.start;
    final end = occurrence.add(e.duration);
    final joined = e.id.startsWith('inv-');
    return Scaffold(
      appBar: AppBar(
        actions: [
          if (!joined)
            IconButton(
              tooltip: 'Szerkesztés',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => EventEditor(existing: e))),
            ),
          IconButton(
            tooltip: joined ? 'Kiveszem a naptáramból' : 'Törlés',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _delete(context, e, occurrence),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          EventHeader(
            title: e.title,
            color: AppColors.ofEvent(e),
            icon: categoryIcon(e.category),
            start: occurrence,
            end: end,
            allDay: e.allDay,
            repeat: e.repeat,
            place: e.place,
            notes: e.notes,
            lat: e.lat,
            lng: e.lng,
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              Pill(e.category.label, color: AppColors.ofEvent(e), icon: categoryIcon(e.category)),
              Pill(reminderLabel(e.reminderMin), color: AppColors.textMuted, icon: Icons.notifications_none),
              if (!e.busy) Pill('Szabadnak mutat', color: AppColors.textMuted, icon: Icons.visibility_outlined),
            ],
          ),
          if (e.shareId != null)
            SharedEventSection(shareId: e.shareId!, ownEvent: joined ? null : e)
          else ...[
            const SectionTitle('Barátokkal'),
            Card(
              child: ListTile(
                leading: IconTile(Icons.group_add_outlined, color: AppColors.category(EventCategory.shared)),
                title: const Text('Barátok meghívása', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Közös programmá válik: visszajelezhetnek, hozzászólhatnak.'),
                onTap: () async {
                  final picked = await showFriendPicker(context);
                  if (picked == null || picked.isEmpty || !context.mounted) return;
                  try {
                    await inviteFriendsTo(context, e, picked);
                  } catch (err) {
                    if (context.mounted) showSocialError(context, err);
                  }
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
