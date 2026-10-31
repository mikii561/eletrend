import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../availability.dart';
import '../availability_service.dart';
import '../formatting.dart';
import '../friends.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'event_editor.dart';
import 'social_widgets.dart';

/// Közös időpont keresése: kiválasztasz pár barátot, és megmutatja, mikor ér rá mindenki.
///
/// Csak a megosztott foglalt időszakokat és a „mikor szoktam ráérni” sávokat használja; a
/// bejegyzések részleteit senki nem látja. Akiről nincs adat, annál „nem tudjuk” szerepel.
class FindTimeScreen extends StatefulWidget {
  const FindTimeScreen({super.key, this.initialUids = const []});

  final List<String> initialUids;

  @override
  State<FindTimeScreen> createState() => _FindTimeScreenState();
}

class _FindTimeScreenState extends State<FindTimeScreen> {
  late final List<String> _friends = [...widget.initialUids];
  int _hours = 2;
  DayPart _part = DayPart.evening;
  int _days = 7;
  final Set<String> _excluded = {};
  Future<List<CommonSlot>>? _result;
  String? _error;

  Future<void> _pickFriends() async {
    final picked = await showFriendPicker(
      context,
      title: 'Kikkel találkoznál?',
      action: 'Kész',
      initial: {..._friends},
    );
    if (picked == null) return;
    setState(() {
      _friends
        ..clear()
        ..addAll(picked);
      _error = null;
      _result = null;
    });
  }

  void _search() {
    if (_friends.isEmpty) {
      setState(() => _error = 'Válassz legalább egy barátot.');
      return;
    }
    final store = StoreScope.of(context);
    setState(() {
      _error = null;
      _result = _find(store);
    });
  }

  Future<List<CommonSlot>> _find(AppStore store) async {
    final now = DateTime.now();
    final from = startOfDay(now);
    final to = from.add(Duration(days: _days));
    final data = await AvailabilityService.instance.fetchAll(_friends);
    final people = [
      Participant(
        uid: 'me',
        name: 'Te',
        known: true,
        busy: store.busyIntervals(from, to),
        windows: store.freeWindows,
        utcOffsetMin: localOffsetMin(now),
      ),
      for (final uid in _friends)
        data[uid]?.toParticipant(uid, store.nameOf(uid)) ?? Participant.unknown(uid: uid, name: store.nameOf(uid)),
    ];
    return findCommonTime(
      people: people,
      from: from,
      to: to,
      duration: Duration(hours: _hours),
      part: _part,
      excludedDays: _excluded,
      viewerOffsetMin: localOffsetMin(now),
      now: now,
    );
  }

  void _create(CommonSlot slot) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EventEditor(
          initialStart: slot.start.toLocal(),
          initialDurationMin: _hours * 60,
          inviteUids: _friends,
          social: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final today = startOfDay(DateTime.now());
    final days = [for (var i = 0; i < _days; i++) DateTime(today.year, today.month, today.day + i)];
    return Scaffold(
      appBar: AppBar(title: const Text('Közös időpont')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          Text(
            'Megkeressük, mikor ér rá mindenki. A barátaidtól csak annyit látunk, mikor foglaltak, a részleteket nem.',
            style: TextStyle(color: AppColors.textMuted),
          ),
          if (!Friends.instance.ready)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: ErrorState(text: 'Ehhez internet kell. Próbáld újra kicsit később.'),
            ),
          const SectionTitle('Kikkel?'),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final uid in _friends)
                InputChip(
                  avatar: NameAvatar(store.nameOf(uid), radius: 11),
                  label: Text(store.nameOf(uid)),
                  onDeleted: () => setState(() {
                    _friends.remove(uid);
                    _result = null;
                  }),
                ),
              ActionChip(
                avatar: const Icon(Icons.person_add_alt_outlined, size: 18),
                label: Text(_friends.isEmpty ? 'Barátok kiválasztása' : 'Módosítás'),
                onPressed: _pickFriends,
              ),
            ],
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(_error!, style: TextStyle(color: AppColors.danger, fontSize: 13)),
            ),
          const SectionTitle('Mennyi időre?'),
          Wrap(
            spacing: 6,
            children: [
              for (final h in [1, 2, 3, 4])
                ChoiceChip(label: Text('$h óra'), selected: _hours == h, onSelected: (_) => setState(() => _hours = h)),
            ],
          ),
          const SectionTitle('Mikor?'),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final p in DayPart.values)
                ChoiceChip(label: Text(p.label), selected: _part == p, onSelected: (_) => setState(() => _part = p)),
              const SizedBox(width: 8),
              for (final (n, label) in [(7, 'Egy héten belül'), (14, 'Két héten belül')])
                ChoiceChip(
                  label: Text(label),
                  selected: _days == n,
                  onSelected: (_) => setState(() {
                    _days = n;
                    _excluded.removeWhere((k) => !days.any((d) => dayKey(d) == k));
                  }),
                ),
            ],
          ),
          const SectionTitle('Kihagyott napok', trailing: 'koppints a kizáráshoz'),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final d in days)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(DateFormat('E d.', 'hu').format(d)),
                      selected: _excluded.contains(dayKey(d)),
                      showCheckmark: false,
                      avatar: _excluded.contains(dayKey(d)) ? const Icon(Icons.block, size: 16) : null,
                      onSelected: (on) => setState(() => on ? _excluded.add(dayKey(d)) : _excluded.remove(dayKey(d))),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(onPressed: _search, icon: const Icon(Icons.search), label: const Text('Keresés')),
          if (_result != null)
            FutureBuilder<List<CommonSlot>>(
              future: _result,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) return const LoadingState(text: 'Keresés…');
                if (snap.hasError) return ErrorState(text: 'Nem sikerült lekérni. Van internet?', onRetry: _search);
                final slots = snap.data!;
                if (slots.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: EmptyState(
                      emoji: '🗓️',
                      text: 'Ebben az időszakban nincs mindenkinek megfelelő időpont.\nPróbálj rövidebb időt, másik napszakot, vagy két hetet.',
                    ),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SectionTitle('Találatok', trailing: '${slots.length}'),
                    for (final s in slots) _SlotCard(slot: s, onCreate: () => _create(s)),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class _SlotCard extends StatelessWidget {
  const _SlotCard({required this.slot, required this.onCreate});

  final CommonSlot slot;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final start = slot.start.toLocal(), end = slot.end.toLocal();
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        title: Text(
          '${formatDay(start)} · ${formatRange(start, end)}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: slot.confirmed
                ? Pill('Mindenki ráér', icon: Icons.check, color: AppColors.status(AvailabilityStatus.available))
                : Pill('Nem tudjuk: ${slot.unknown.join(', ')}', icon: Icons.help_outline, color: AppColors.textMuted),
          ),
        ),
        trailing: FilledButton.tonal(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
          onPressed: onCreate,
          child: const Text('Tervezés'),
        ),
      ),
    );
  }
}
