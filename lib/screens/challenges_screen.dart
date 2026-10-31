import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../challenges.dart';
import '../friends.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';

void _error(BuildContext context, Object e) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Nem sikerült. Van internet? ($e)')));

/// Közös kihívások listája.
class ChallengesScreen extends StatefulWidget {
  const ChallengesScreen({super.key});

  @override
  State<ChallengesScreen> createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends State<ChallengesScreen> {
  late final Stream<List<Challenge>>? _mine = Challenges.instance.ready ? Challenges.instance.watchMine() : null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kihívások')),
      floatingActionButton: _mine == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                showDragHandle: true,
                builder: (_) => const _NewChallenge(),
              ),
              icon: const Icon(Icons.flag_outlined),
              label: const Text('Új kihívás', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
      body: _mine == null
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: EmptyState(emoji: '📡', text: 'A kihívásokhoz internet kell.'),
            )
          : StreamBuilder<List<Challenge>>(
              stream: _mine,
              builder: (context, snap) {
                if (snap.hasError) return Center(child: Text('Nem sikerült betölteni: ${snap.error}'));
                final list = snap.data?.where((c) => !c.isGoal).toList();
                if (list == null) return const Center(child: CircularProgressIndicator());
                if (list.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: EmptyState(
                      emoji: '🏁',
                      text: 'Még nincs kihívásod.\nHívd ki a barátaidat: ki bírja tovább?',
                    ),
                  );
                }
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                  children: [
                    for (final c in list)
                      Card(
                        child: ListTile(
                          leading: ChallengeIcon(c, size: 40),
                          title: Text(c.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                          subtitle: Text(
                            c.isActive()
                                ? '${c.dayNumber()}. nap a ${c.days}-ból · ${c.members.length} résztvevő'
                                : c.dayNumber() == 0
                                ? 'Kezdés: ${DateFormat('MMM d.', 'hu').format(c.start)} · ${c.members.length} résztvevő'
                                : 'Véget ért · ${c.members.length} résztvevő',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () =>
                              Navigator.of(context)
                                  .push(MaterialPageRoute(builder: (_) => ChallengeDetail(challenge: c))),
                        ),
                      ),
                  ],
                );
              },
            ),
    );
  }
}

class _NewChallenge extends StatefulWidget {
  const _NewChallenge();

  @override
  State<_NewChallenge> createState() => _NewChallengeState();
}

class _NewChallengeState extends State<_NewChallenge> {
  final _title = TextEditingController(text: challengeIdeas.first.$2);
  String _emoji = challengeIdeas.first.$1;
  int _days = challengeIdeas.first.$3;
  late final _daysField = TextEditingController(text: '$_days');
  late final _emojiField = TextEditingController(text: _emoji);
  String _image = '';
  DateTime _start = DateTime.now();
  final Map<String, String> _picked = {};
  late final Future<List<Friend>> _friends = Friends.instance.watchFriends().first;
  bool _busy = false;

  /// Kép a galériából; a kihívás ikonja lesz (négyzetre vágva, kicsinyítve).
  Future<void> _pickImage() async {
    try {
      final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1000, maxHeight: 1000);
      if (file == null) return;
      final image = prepareChallengeIcon(await file.readAsBytes());
      if (mounted) setState(() => _image = image);
    } catch (e) {
      if (mounted) _error(context, e is FormatException ? e.message : e);
    }
  }

  void _useIdea(String emoji, String title, int days) => setState(() {
    _title.text = title;
    _emoji = emoji;
    _emojiField.text = emoji;
    _image = '';
    _days = days;
    _daysField.text = '$days';
  });

  Future<void> _create() async {
    if (_title.text.trim().isEmpty) return;
    if (_days < 1 || _days > maxChallengeDays) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('A napok száma 1 és $maxChallengeDays között lehet.')));
      return;
    }
    setState(() => _busy = true);
    try {
      await Challenges.instance.create(
        title: _title.text,
        emoji: _emoji.isEmpty ? '🏁' : _emoji,
        image: _image,
        days: _days,
        start: _start,
        friends: _picked,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) _error(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _daysField.dispose();
    _emojiField.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Új kihívás', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('Válassz egy ötletet, vagy alkosd meg a sajátodat.', style: TextStyle(color: AppColors.textMuted)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final (emoji, title, days) in challengeIdeas)
                  ChoiceChip(
                    label: Text('$emoji $title'),
                    selected: _title.text == title,
                    onSelected: (_) => _useIdea(emoji, title, days),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                ChallengeIcon.preview(emoji: _emoji, image: _image, size: 56),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _emojiField,
                    decoration: const InputDecoration(labelText: 'Emoji', hintText: '🏆', counterText: ''),
                    onChanged: (v) => setState(() {
                      // Egyetlen emoji kell: az utolsónak beírtat tartjuk meg.
                      _emoji = v.characters.isEmpty ? '' : v.characters.last;
                      if (_emoji.isNotEmpty && _emojiField.text != _emoji) {
                        _emojiField.value = TextEditingValue(
                          text: _emoji,
                          selection: TextSelection.collapsed(offset: _emoji.length),
                        );
                      }
                      if (_emoji.isNotEmpty) _image = '';
                    }),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: Text(_image.isEmpty ? 'Kép a galériából' : 'Másik kép'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                ),
                if (_image.isNotEmpty)
                  TextButton(onPressed: () => setState(() => _image = ''), child: const Text('Kép törlése')),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _title,
              maxLength: 60,
              decoration: const InputDecoration(labelText: 'Név (vagy írj sajátot)', counterText: ''),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Expanded(
                  child: Text('Hány nap?', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
                for (final d in [7, 14, 21, 30])
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: ChoiceChip(
                      label: Text('$d'),
                      selected: _days == d,
                      onSelected: (_) => setState(() {
                        _days = d;
                        _daysField.text = '$d';
                      }),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _daysField,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
              decoration: InputDecoration(
                labelText: 'Vagy írd be a napok számát',
                helperText: 'Például 10 vagy 100 (legfeljebb $maxChallengeDays)',
                suffixText: 'nap',
              ),
              onChanged: (v) => setState(() => _days = int.tryParse(v) ?? 0),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.calendar_today_outlined, color: AppColors.primary),
              title: Text('Kezdés: ${DateFormat('MMMM d., EEEE', 'hu').format(_start)}'),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _start,
                  firstDate: DateTime.now().subtract(const Duration(days: 7)),
                  lastDate: DateTime.now().add(const Duration(days: 60)),
                );
                if (d != null) setState(() => _start = d);
              },
            ),
            const SizedBox(height: 4),
            const Text('Kiket hívsz ki?', style: TextStyle(fontWeight: FontWeight.w700)),
            FutureBuilder<List<Friend>>(
              future: _friends,
              builder: (context, snap) {
                final friends = snap.data;
                if (friends == null) {
                  return const Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator());
                }
                if (friends.isEmpty) {
                  return Text(
                    'Még nincs barátod az appban; egyedül is elindíthatod.',
                    style: TextStyle(color: AppColors.textMuted),
                  );
                }
                return Wrap(
                  spacing: 6,
                  children: [
                    for (final f in friends)
                      FilterChip(
                        avatar: NameAvatar(f.name, radius: 11),
                        label: Text(f.name),
                        selected: _picked.containsKey(f.uid),
                        onSelected: (on) => setState(() => on ? _picked[f.uid] = f.name : _picked.remove(f.uid)),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _busy ? null : _create, child: const Text('Kihívás indítása')),
          ],
        ),
      ),
    );
  }
}

/// Egy kihívás: ranglista, mai teljesítés, buzdítás, célhoz kötés.
class ChallengeDetail extends StatefulWidget {
  const ChallengeDetail({super.key, required this.challenge});

  final Challenge challenge;

  @override
  State<ChallengeDetail> createState() => _ChallengeDetailState();
}

class _ChallengeDetailState extends State<ChallengeDetail> {
  late final Stream<List<ChallengeProgress>> _progress = Challenges.instance.watchProgress(widget.challenge.id);

  @override
  Widget build(BuildContext context) {
    final c = widget.challenge;
    final store = StoreScope.of(context);
    final me = Challenges.instance.uid;
    final linked = store.challengeHabits[c.id];
    final today = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            ChallengeIcon(c, size: 28),
            const SizedBox(width: 10),
            Expanded(child: Text(c.title, overflow: TextOverflow.ellipsis)),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) async {
              final navigator = Navigator.of(context);
              try {
                v == 'delete' ? await Challenges.instance.delete(c) : await Challenges.instance.leave(c);
                navigator.pop();
              } catch (e) {
                if (context.mounted) _error(context, e);
              }
            },
            itemBuilder: (_) => [
              if (c.ownerUid == me)
                const PopupMenuItem(value: 'delete', child: Text('Kihívás törlése'))
              else
                const PopupMenuItem(value: 'leave', child: Text('Kilépés a kihívásból')),
            ],
          ),
        ],
      ),
      body: StreamBuilder<List<ChallengeProgress>>(
        stream: _progress,
        builder: (context, snap) {
          final progress = snap.data ?? const <ChallengeProgress>[];
          final mine = progress.where((p) => p.uid == me).firstOrNull;
          final doneToday = mine?.done.contains(dayKey(today)) ?? false;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        c.isActive()
                            ? '${c.dayNumber()}. nap a ${c.days}-ból'
                            : c.dayNumber() == 0
                            ? 'Még nem kezdődött el'
                            : 'A kihívás véget ért',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        '${DateFormat('MMM d.', 'hu').format(c.start)} – ${DateFormat('MMM d.', 'hu').format(c.end)}',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                      const SizedBox(height: 12),
                      if (c.isActive())
                        FilledButton.icon(
                          onPressed: linked != null
                              ? null
                              : () => Challenges.instance.checkIn(c, today, !doneToday).catchError((Object e) {
                                  if (context.mounted) _error(context, e);
                                }),
                          icon: Icon(doneToday ? Icons.check_circle : Icons.radio_button_unchecked),
                          label: Text(
                            linked != null
                                ? (doneToday ? 'Ma kész ✅ (a célból)' : 'A célod kipipálásával teljesül')
                                : doneToday
                                ? 'Ma kész ✅'
                                : 'Ma teljesítettem',
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SectionTitle('Ranglista'),
              Card(
                child: Column(
                  children: [
                    for (final (i, p) in progress.indexed)
                      ListTile(
                        leading: CircleAvatar(
                          backgroundColor: i == 0 ? AppColors.accent : AppColors.background,
                          child: Text(
                            i == 0
                                ? '🥇'
                                : i == 1
                                ? '🥈'
                                : i == 2
                                ? '🥉'
                                : '${i + 1}.',
                          ),
                        ),
                        title: Text(
                          p.uid == me ? '${p.name} (te)' : p.name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(value: p.done.length / c.days, minHeight: 6),
                            ),
                            const SizedBox(height: 2),
                            Text('${p.done.length}/${c.days} nap${p.cheers > 0 ? ' · 👏 ${p.cheers}' : ''}'),
                          ],
                        ),
                        trailing: p.uid == me
                            ? null
                            : IconButton(
                                tooltip: 'Buzdítás',
                                icon: const Text('👏', style: TextStyle(fontSize: 22)),
                                onPressed: () async {
                                  await Challenges.instance.cheer(c.id, p.uid);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(SnackBar(content: Text('Megbuzdítottad: ${p.name} 👏')));
                                  }
                                },
                              ),
                      ),
                    for (final m in c.members.where((m) => !progress.any((p) => p.uid == m)))
                      ListTile(
                        leading: const CircleAvatar(child: Text('⏳')),
                        title: Text(c.names[m] ?? '?'),
                        subtitle: const Text('Még nem kezdte el'),
                      ),
                  ],
                ),
              ),
              if (store.habits.isNotEmpty) ...[
                const SectionTitle('Célhoz kötés'),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: DropdownButtonFormField<String?>(
                      initialValue: store.habits.any((h) => h.id == linked) ? linked : null,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Ha kipipálom ezt a célt, a kihívásban is teljesül'),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Nincs (kézzel jelölöm)')),
                        for (final Habit h in store.habits)
                          DropdownMenuItem(
                            value: h.id,
                            child: Text(h.name, overflow: TextOverflow.ellipsis),
                          ),
                      ],
                      onChanged: (v) {
                        store.linkChallengeHabit(c.id, v);
                        Challenges.instance.syncLinkedHabits();
                      },
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// A kihívás ikonja: saját kép, ha van, különben az emoji.
class ChallengeIcon extends StatelessWidget {
  const ChallengeIcon(Challenge c, {super.key, this.size = 36}) : emoji = null, image = null, challenge = c;

  /// Ikon egy még el nem mentett kihíváshoz (az új kihívás űrlapján).
  const ChallengeIcon.preview({super.key, required String this.emoji, required String this.image, this.size = 36})
    : challenge = null;

  final Challenge? challenge;
  final String? emoji;
  final String? image;
  final double size;

  @override
  Widget build(BuildContext context) {
    final img = challenge?.image ?? image ?? '';
    final symbol = challenge?.emoji ?? emoji ?? '';
    if (img.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.25),
        child: Image.memory(
          base64Decode(img),
          width: size,
          height: size,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => SizedBox(
            width: size,
            height: size,
            child: const Center(child: Text('🏁')),
          ),
        ),
      );
    }
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: Text(symbol.isEmpty ? '🏁' : symbol, style: TextStyle(fontSize: size * 0.75)),
      ),
    );
  }
}
