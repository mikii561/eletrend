import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../calendar_link.dart';
import '../event_background.dart';
import '../models.dart';
import '../social.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/weather_tile.dart';
import 'events_screen.dart' show repeatLabel;
import 'social_widgets.dart';

/// Egy meghívás a vendég szemével: visszajelzés, szavazás az időpontról, üzenőfal.
/// A meghívólink (…/eletrend/?e=azonosító) ezt nyitja meg.
class InviteScreen extends StatefulWidget {
  const InviteScreen({super.key, required this.eventId});

  final String eventId;

  @override
  State<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends State<InviteScreen> {
  late final _event = Social.instance.watchEvent(widget.eventId);
  late final _rsvps = Social.instance.watchRsvps(widget.eventId);
  late final _name = TextEditingController(text: StoreScope.of(context).myName);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  /// A visszajelzéshez név kell; a mezőből vesszük, és megjegyezzük.
  String? _nameOrAsk() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Előbb írd be a neved!')));
      return null;
    }
    final store = StoreScope.of(context);
    if (store.myName != name) store.setMyName(name.length > 40 ? name.substring(0, 40) : name);
    return store.myName;
  }

  Future<void> _respond({RsvpStatus? status, Set<String>? votes}) async {
    final name = _nameOrAsk();
    if (name == null) return;
    try {
      await Social.instance.respond(widget.eventId, name: name, status: status, votes: votes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Nem sikerült elküldeni. Van internet? ($e)')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Meghívás')),
      body: StreamBuilder<SharedEvent?>(
        stream: _event,
        builder: (context, snap) {
          if (snap.hasError) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: const [EmptyState(emoji: '📡', text: 'Nem sikerült betölteni a meghívást.\nVan internet?')],
            );
          }
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final event = snap.data;
          if (event == null) {
            // ListView-ban a kártya a tartalmához méreteződik, nem nyúlik meg.
            return ListView(
              padding: const EdgeInsets.all(16),
              children: const [EmptyState(emoji: '🤷', text: 'Ez a program már nem létezik.\nLehet, hogy a szervező törölte.')],
            );
          }
          // Megjegyezzük, hogy később a Programok között is megtaláld.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final known = store.invites.where((i) => i.id == event.id).firstOrNull;
            if (event.ownerUid != Social.instance.uid && (known?.title != event.title || known?.date != event.date)) {
              store.saveInvite(Invite(id: event.id, title: event.title, date: event.date));
            }
          });
          return StreamBuilder<List<Rsvp>>(
            stream: _rsvps,
            builder: (context, rsnap) {
              final rsvps = rsnap.data ?? const <Rsvp>[];
              final mine = rsvps.where((r) => r.uid == Social.instance.uid).firstOrNull;
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                children: [
                  if (event.bgTheme != null || event.bgImage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: SizedBox(
                        height: 140,
                        child: EventBackdrop(
                          theme: event.bgTheme,
                          image: event.bgImage,
                          child: Align(
                            alignment: Alignment.bottomLeft,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text('Meghívtak! 🎉',
                                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
                            ),
                          ),
                        ),
                      ),
                    ),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          DateBadge(event.date, size: 64),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(event.title,
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                                const SizedBox(height: 4),
                                Text(
                                  event.pollOpen
                                      ? 'Az időpontról még szavazás van'
                                      : DateFormat('MMMM d., EEEE HH:mm', 'hu').format(event.date),
                                  style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w700),
                                ),
                                if (event.repeat != Repeat.none)
                                  Text(repeatLabel(Event(id: '', title: '', date: event.date, repeat: event.repeat)),
                                      style: TextStyle(color: AppColors.textMuted)),
                                if (event.place.isNotEmpty) Text('📍 ${event.place}', style: TextStyle(color: AppColors.textMuted)),
                                Text('Szervező: ${event.ownerName}', style: TextStyle(color: AppColors.textMuted)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (!event.pollOpen && event.lat != null && event.lng != null)
                    Card(child: WeatherTile(lat: event.lat!, lng: event.lng!, at: event.date)),
                  if (!event.pollOpen)
                    OutlinedButton.icon(
                      onPressed: () => launchUrl(
                        googleCalendarLink(
                          title: event.title,
                          start: event.date,
                          place: event.place,
                          repeat: event.repeat,
                          details: 'Szervező: ${event.ownerName}\n${Social.instance.linkFor(event.id)}',
                        ),
                        mode: LaunchMode.externalApplication,
                      ),
                      icon: const Icon(Icons.event_available_outlined),
                      label: const Text('Mentés a naptárba'),
                    ),
                  const SectionTitle('Jössz?'),
                  TextField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    maxLength: 40,
                    decoration: const InputDecoration(labelText: 'A neved', prefixIcon: Icon(Icons.person_outline), counterText: ''),
                  ),
                  const SizedBox(height: 10),
                  RsvpButtons(current: mine?.status ?? RsvpStatus.none, onChanged: (s) => _respond(status: s)),
                  if (event.pollOpen) ...[
                    const SectionTitle('Időpont'),
                    PollCard(
                      event: event,
                      rsvps: rsvps,
                      myVotes: mine?.votes ?? const {},
                      onToggleVote: (key) {
                        final votes = {...?mine?.votes};
                        votes.contains(key) ? votes.remove(key) : votes.add(key);
                        _respond(votes: votes);
                      },
                    ),
                  ],
                  const SectionTitle('Ki mit hoz?'),
                  BringList(
                    eventId: event.id,
                    isOwner: event.ownerUid == Social.instance.uid,
                    nameOf: _nameOrAsk,
                  ),
                  const SectionTitle('Ki jön még?'),
                  Card(child: RsvpSummary(rsvps: rsvps)),
                  const SectionTitle('Üzenőfal'),
                  ChatPanel(eventId: event.id, isOwner: event.ownerUid == Social.instance.uid),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
