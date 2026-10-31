import 'package:flutter/material.dart';

import '../models.dart';
import '../social.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'event_detail_screen.dart';
import 'social_widgets.dart';

/// Egy közös program a meghívott szemével: adatok, „Hozzáadom a naptáramhoz”, visszajelzés,
/// szavazás, reakciók, hozzászólások. A meghívólink (…/?e=azonosító) és a Meghívásaim ezt nyitják.
class InviteScreen extends StatefulWidget {
  const InviteScreen({super.key, required this.eventId});

  final String eventId;

  @override
  State<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends State<InviteScreen> {
  late final _event = Social.instance.watchEvent(widget.eventId);

  /// A meghívást megjegyezzük, hogy később is megtaláld (és frissítjük, ha változott).
  void _remember(AppStore store, SharedEvent e) {
    if (e.ownerUid == Social.instance.uid) return;
    final known = store.invites.where((i) => i.id == e.id).firstOrNull;
    if (known?.title != e.title || known?.date != e.date) {
      store.saveInvite(Invite(id: e.id, title: e.title, date: e.date, fromName: e.ownerName));
    }
    // Megnyitotta: már nem számít újnak.
    store.markInviteSeen(e.id);
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final inCalendar = store.events.where((e) => e.shareId == widget.eventId).firstOrNull;
    return Scaffold(
      appBar: AppBar(title: const Text('Közös program')),
      body: StreamBuilder<SharedEvent?>(
        stream: _event,
        builder: (context, snap) {
          if (snap.hasError) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: const [
                ErrorState(
                  text: 'Nem sikerült betölteni. Lehet, hogy nincs internet, vagy ez a program csak a meghívottaknak látható.',
                ),
              ],
            );
          }
          if (snap.connectionState == ConnectionState.waiting) return const Center(child: LoadingState());
          final e = snap.data;
          if (e == null) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: const [
                EmptyState(emoji: '🤷', text: 'Ez a program már nem létezik.\nLehet, hogy a szervező törölte.'),
              ],
            );
          }
          WidgetsBinding.instance.addPostFrameCallback((_) => _remember(store, e));
          final color = AppColors.category(EventCategory.shared);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            children: [
              EventHeader(
                title: e.title,
                color: color,
                icon: categoryIcon(e.category),
                start: e.date,
                end: e.end,
                allDay: e.allDay,
                repeat: e.repeat,
                place: e.place,
                notes: e.notes,
                lat: e.lat,
                lng: e.lng,
                extra: 'Szervező: ${e.ownerName}${e.pollOpen ? ' · az időpontról szavazás van' : ''}',
              ),
              const SizedBox(height: 8),
              if (e.ownerUid != Social.instance.uid)
                inCalendar == null
                    ? FilledButton.icon(
                        onPressed: () {
                          store.saveEvent(e.toEvent());
                          ScaffoldMessenger.of(context)
                              .showSnackBar(const SnackBar(content: Text('Bekerült a naptáradba.')));
                        },
                        icon: const Icon(Icons.event_available_outlined),
                        label: const Text('Hozzáadom a naptáramhoz'),
                      )
                    : OutlinedButton.icon(
                        onPressed: () => store.removeEvent(inCalendar),
                        icon: const Icon(Icons.event_busy_outlined),
                        label: const Text('Kiveszem a naptáramból'),
                      ),
              SharedEventSection(shareId: e.id),
            ],
          );
        },
      ),
    );
  }
}
