import 'package:flutter/material.dart';

import '../challenges.dart';
import '../friends.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// A célhoz kötött közös cél azonosítója (ha van).
String? sharedGoalIdOf(AppStore store, Habit h) =>
    store.challengeHabits.entries.where((e) => e.value == h.id).firstOrNull?.key;

/// Barátok kiválasztása egy cél megosztásához.
Future<void> showShareGoalSheet(BuildContext context, Habit habit) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _ShareGoalSheet(habit: habit),
);

class _ShareGoalSheet extends StatefulWidget {
  const _ShareGoalSheet({required this.habit});

  final Habit habit;

  @override
  State<_ShareGoalSheet> createState() => _ShareGoalSheetState();
}

class _ShareGoalSheetState extends State<_ShareGoalSheet> {
  late final Stream<List<Friend>> _friends = Friends.instance.watchFriends();
  final Map<String, String> _picked = {};
  bool _busy = false;
  String? _error;

  Future<void> _share() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Challenges.instance.shareGoal(widget.habit, _picked);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(SnackBar(content: Text('Elküldve: ${_picked.values.join(', ')} megkapta a meghívást.')));
    } catch (e) {
      if (mounted) setState(() => _error = 'Nem sikerült. Van internet? ($e)');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Közös cél: ${widget.habit.name}', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              'A barátod is felveszi ezt a célt, és egymás pipáit látjátok a kártyán. Egy évig tart.',
              style: TextStyle(color: AppColors.textMuted),
            ),
            const SizedBox(height: 12),
            StreamBuilder<List<Friend>>(
              stream: _friends,
              builder: (context, snap) {
                final list = snap.data;
                if (snap.hasError) return Text('Nem sikerült betölteni a barátokat: ${snap.error}');
                if (list == null) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (list.isEmpty) {
                  return const EmptyState(
                    emoji: '👋',
                    text: 'Még nincs barátod az appban. A Barátok fülön kóddal felveheted.',
                  );
                }
                return ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 320),
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final f in list)
                        CheckboxListTile(
                          secondary: NameAvatar(f.name),
                          title: Text(f.name),
                          value: _picked.containsKey(f.uid),
                          onChanged: (on) => setState(() => on! ? _picked[f.uid] = f.name : _picked.remove(f.uid)),
                        ),
                    ],
                  ),
                );
              },
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: TextStyle(color: Colors.red.shade400)),
              ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _picked.isEmpty || _busy ? null : _share,
              child: Text(_busy ? 'Küldés…' : 'Közös cél indítása'),
            ),
          ],
        ),
      ),
    );
  }
}

/// A célkártya alján: a társak elmúlt 7 napja, buzdítással.
class SharedGoalRow extends StatefulWidget {
  const SharedGoalRow({super.key, required this.challengeId});

  final String challengeId;

  @override
  State<SharedGoalRow> createState() => _SharedGoalRowState();
}

class _SharedGoalRowState extends State<SharedGoalRow> {
  late final Stream<List<ChallengeProgress>> _progress = Challenges.instance.watchProgress(widget.challengeId);
  final Set<String> _cheered = {};

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final days = List.generate(7, (i) => addDays(today, i - 6));
    return StreamBuilder<List<ChallengeProgress>>(
      stream: _progress,
      builder: (context, snap) {
        final others = [
          for (final p in snap.data ?? const <ChallengeProgress>[])
            if (p.uid != Challenges.instance.uid) p,
        ];
        if (others.isEmpty) {
          return Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              snap.data == null ? '' : 'Közös cél · várjuk, hogy a barátod csatlakozzon',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          );
        }
        return Column(
          children: [
            for (final p in others)
              Padding(
                padding: const EdgeInsets.only(top: 10, right: 12),
                child: Row(
                  children: [
                    NameAvatar(p.name, radius: 13),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        p.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    for (final d in days)
                      Container(
                        width: 12,
                        height: 12,
                        margin: const EdgeInsets.only(left: 4),
                        decoration: BoxDecoration(
                          color: p.done.contains(dayKey(d)) ? AppColors.accent : AppColors.divider,
                          shape: BoxShape.circle,
                        ),
                      ),
                    const SizedBox(width: 4),
                    IconButton(
                      tooltip: 'Buzdítás',
                      visualDensity: VisualDensity.compact,
                      onPressed: _cheered.contains(p.uid)
                          ? null
                          : () {
                              setState(() => _cheered.add(p.uid));
                              Challenges.instance.cheer(widget.challengeId, p.uid).catchError((Object _) {});
                            },
                      icon: const Text('👏', style: TextStyle(fontSize: 16)),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

/// A Célok tetején: barátok közös cél meghívásai, amikre még nem válaszoltál.
class SharedGoalInvites extends StatefulWidget {
  const SharedGoalInvites({super.key});

  @override
  State<SharedGoalInvites> createState() => _SharedGoalInvitesState();
}

class _SharedGoalInvitesState extends State<SharedGoalInvites> {
  final Stream<List<Challenge>>? _goals = Challenges.instance.ready ? Challenges.instance.watchSharedGoals() : null;
  final Set<String> _handled = {};

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    if (_goals == null) return const SizedBox.shrink();
    return StreamBuilder<List<Challenge>>(
      stream: _goals,
      builder: (context, snap) {
        final invites = [
          for (final c in snap.data ?? const <Challenge>[])
            if (!store.challengeHabits.containsKey(c.id) &&
                c.ownerUid != Challenges.instance.uid &&
                !_handled.contains(c.id))
              c,
        ];
        return Column(
          children: [
            for (final c in invites)
              Card(
                color: AppColors.accent.withValues(alpha: 0.10),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${c.names[c.ownerUid] ?? 'Egy barátod'} közös célt indított veled',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                      ),
                      const SizedBox(height: 2),
                      Text(c.title, style: Theme.of(context).textTheme.titleMedium),
                      Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 4,
                        children: [
                          TextButton(
                            onPressed: () {
                              setState(() => _handled.add(c.id));
                              Challenges.instance.leave(c).catchError((Object _) {});
                            },
                            child: const Text('Nem most'),
                          ),
                          const SizedBox(width: 4),
                          FilledButton(
                            style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                            onPressed: () {
                              setState(() => _handled.add(c.id));
                              Challenges.instance.joinSharedGoal(c).catchError((Object e) {
                                debugPrint('Csatlakozás később: $e');
                              });
                            },
                            child: const Text('Csatlakozom'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Közös cél leállítása: aki indította, törli; aki csatlakozott, kilép.
Future<void> stopSharedGoal(BuildContext context, String challengeId) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Közös cél leállítása?'),
      content: const Text('A célod megmarad, csak a barátaid nem látják tovább a pipáidat.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Mégse')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Leállítás')),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  final store = StoreScope.of(context);
  store.linkChallengeHabit(challengeId, null);
  try {
    final c = await Challenges.instance.get(challengeId);
    if (c == null) return;
    c.ownerUid == Challenges.instance.uid ? await Challenges.instance.delete(c) : await Challenges.instance.leave(c);
  } catch (e) {
    debugPrint('Közös cél leállítása később: $e');
  }
}
