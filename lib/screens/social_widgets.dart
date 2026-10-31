import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../friends.dart';
import '../models.dart';
import '../social.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'memory_screen.dart';
import 'nudge_screens.dart';

/// A felhasználó neve a közös funkciókhoz; ha még nincs, egyszer megkérdezzük.
Future<String?> ensureMyName(BuildContext context) async {
  final store = StoreScope.of(context);
  if (store.myName.isNotEmpty) return store.myName;
  final name = await showTextInputSheet(
    context,
    title: 'Hogy hívnak?',
    hint: 'Így látnak a barátaid (pl. Gabi)',
    action: 'Mentés',
  );
  if (name == null || name.trim().isEmpty) return null;
  store.setMyName(name);
  return store.myName;
}

/// Hálózati hiba egységes kiírása.
void showSocialError(BuildContext context, Object e) {
  final text = e is SocialException || e is FriendException ? '$e' : 'Nem sikerült. Van internet? ($e)';
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text, maxLines: 3)));
}

/// Meghívólink megosztása: telefonon a megosztás menü, egyébként vágólapra másolás.
Future<void> shareInvite(BuildContext context, String title, String link) async {
  final messenger = ScaffoldMessenger.of(context);
  final text = 'Gyere el: $title! Jelezz vissza itt: $link';
  try {
    final result = await SharePlus.instance.share(ShareParams(text: text, subject: title));
    if (result.status != ShareResultStatus.unavailable) return;
  } catch (_) {
    // Nincs megosztás menü (pl. gépen), marad a vágólap.
  }
  await Clipboard.setData(ClipboardData(text: link));
  messenger.showSnackBar(const SnackBar(content: Text('A meghívólink a vágólapon. Küldd el a barátaidnak!')));
}

/// Barátok kiválasztása (a csoportok egy koppintással), pl. meghíváshoz vagy közös időponthoz.
Future<List<String>?> showFriendPicker(
  BuildContext context, {
  String title = 'Kiket hívsz meg?',
  String action = 'Meghívás',
  Set<String> initial = const {},
}) {
  return showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _FriendPicker(title: title, action: action, initial: initial),
  );
}

class _FriendPicker extends StatefulWidget {
  const _FriendPicker({required this.title, required this.action, required this.initial});

  final String title;
  final String action;
  final Set<String> initial;

  @override
  State<_FriendPicker> createState() => _FriendPickerState();
}

class _FriendPickerState extends State<_FriendPicker> {
  late final Set<String> _picked = {...widget.initial};

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final friends = [...store.friendsCache]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
              if (friends.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: EmptyState(
                    emoji: '👥',
                    text:
                        'Még nincs barátod az appban.\nA Barátok fülön add meg a kódjukat, vagy küldd el a sajátodat.',
                  ),
                ),
              if (store.groups.isNotEmpty && friends.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final g in store.groups)
                      ActionChip(
                        avatar: const Icon(Icons.group_outlined, size: 18),
                        label: Text('${g.name} (${g.members.length})'),
                        onPressed: () => setState(() => _picked.addAll(g.members)),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final f in friends)
                      CheckboxListTile(
                        secondary: NameAvatar(f.name),
                        title: Text(f.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        value: _picked.contains(f.uid),
                        onChanged: (on) => setState(() => on == true ? _picked.add(f.uid) : _picked.remove(f.uid)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _picked.isEmpty ? null : () => Navigator.pop(context, _picked.toList()),
                child: Text(_picked.isEmpty ? 'Válassz barátot' : '${widget.action} (${_picked.length})'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Barátok meghívása egy bejegyzésre: ha még nincs megosztva, megosztja, aztán a barátok
/// „Meghívásaim” listájába kerül. Visszaadja, hány meghívás ment ki.
Future<int> inviteFriendsTo(BuildContext context, Event event, List<String> uids) async {
  final store = StoreScope.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final name = await ensureMyName(context);
  if (name == null) return 0;
  if (event.shareId == null) {
    if (event.category == EventCategory.personal) event.category = EventCategory.shared;
    event.shareId = await Social.instance.publish(event, ownerName: name);
    store.saveEvent(event);
  }
  await Social.instance.addInvited(event.shareId!, uids);
  final failed = await Friends.instance.invite(event, uids);
  final sent = uids.length - failed.length;
  if (failed.isNotEmpty) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Nem mehetett ki: ${failed.map(store.nameOf).join(', ')} (kikapcsolta a meghívásokat). '
          'Neki a meghívólinket küldheted el.',
        ),
      ),
    );
  } else if (sent > 0) {
    messenger.showSnackBar(SnackBar(content: Text('Meghívtad: $sent barát.')));
  }
  return sent;
}

/// Megyek / Talán / Nem megyek gombok.
class RsvpButtons extends StatelessWidget {
  const RsvpButtons({super.key, required this.current, required this.onChanged, this.full = false});

  final RsvpStatus current;
  final ValueChanged<RsvpStatus> onChanged;

  /// Betelt a létszám: a „Megyek” csak annak választható, aki már jön.
  final bool full;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<RsvpStatus>(
      showSelectedIcon: false,
      emptySelectionAllowed: true,
      segments: [
        ButtonSegment(
          value: RsvpStatus.yes,
          label: const Text('Megyek'),
          icon: const Icon(Icons.check),
          enabled: !full || current == RsvpStatus.yes,
        ),
        const ButtonSegment(value: RsvpStatus.maybe, label: Text('Talán'), icon: Icon(Icons.help_outline)),
        const ButtonSegment(value: RsvpStatus.no, label: Text('Nem'), icon: Icon(Icons.close)),
      ],
      selected: {if (current != RsvpStatus.none) current},
      onSelectionChanged: (s) => onChanged(s.isEmpty ? RsvpStatus.none : s.first),
    );
  }
}

/// Ki jön, ki talán, ki nem.
class RsvpSummary extends StatelessWidget {
  const RsvpSummary({super.key, required this.rsvps});

  final List<Rsvp> rsvps;

  @override
  Widget build(BuildContext context) {
    final answered = rsvps.where((r) => r.status != RsvpStatus.none).toList();
    if (answered.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text('Még senki nem jelzett vissza.', style: TextStyle(color: AppColors.textMuted)),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final s in [RsvpStatus.yes, RsvpStatus.maybe, RsvpStatus.no])
          if (answered.any((r) => r.status == s))
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${s.label} · ${answered.where((r) => r.status == s).length}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final r in answered.where((r) => r.status == s))
                        Chip(
                          avatar: NameAvatar(r.name, radius: 11),
                          label: Text(r.name),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                ],
              ),
            ),
        const SizedBox(height: 8),
      ],
    );
  }
}

String formatOption(DateTime d) => DateFormat('MMM d., EEEE HH:mm', 'hu').format(d);

/// Időpont-szavazás: a meghívottak bejelölik, mi jó nekik; a legjobb ki van emelve.
/// Szervezőként innen lehet kiválasztani a végleges időpontot.
class PollCard extends StatelessWidget {
  const PollCard({
    super.key,
    required this.event,
    required this.rsvps,
    required this.myVotes,
    required this.onToggleVote,
    this.onChoose,
  });

  final SharedEvent event;
  final List<Rsvp> rsvps;
  final Set<String> myVotes;
  final ValueChanged<String> onToggleVote;

  /// Csak a szervezőnél van megadva.
  final ValueChanged<DateTime>? onChoose;

  @override
  Widget build(BuildContext context) {
    final best = bestOption(event.pollOptions, rsvps);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text('Melyik időpont jó?', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
              child: Text(
                'Jelöld be az összeset, ami neked jó.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
            ),
            for (final o in event.pollOptions)
              Builder(
                builder: (context) {
                  final key = o.toIso8601String();
                  final voters = rsvps.where((r) => r.votes.contains(key)).toList();
                  return CheckboxListTile(
                    value: myVotes.contains(key),
                    onChanged: (_) => onToggleVote(key),
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Row(
                      children: [
                        Flexible(
                          child: Text(formatOption(o), style: const TextStyle(fontWeight: FontWeight.w600)),
                        ),
                        if (o == best) ...[const SizedBox(width: 6), Pill('Legjobb', color: AppColors.primary)],
                      ],
                    ),
                    subtitle: Text(
                      voters.isEmpty ? 'Még senkinek' : '${voters.length}: ${voters.map((r) => r.name).join(', ')}',
                    ),
                    secondary: onChoose == null
                        ? null
                        : TextButton(onPressed: () => onChoose!(o), child: const Text('Ez lesz')),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

/// 2–3 időpont összeállítása a szavazáshoz.
Future<List<DateTime>?> showPollEditor(BuildContext context, List<DateTime> initial) =>
    showModalBottomSheet<List<DateTime>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _PollEditor(initial: initial),
    );

class _PollEditor extends StatefulWidget {
  const _PollEditor({required this.initial});

  final List<DateTime> initial;

  @override
  State<_PollEditor> createState() => _PollEditorState();
}

class _PollEditorState extends State<_PollEditor> {
  late final List<DateTime> _options = [...widget.initial];

  Future<void> _add() async {
    final base = _options.isEmpty ? DateTime.now() : _options.last;
    final day = await showDatePicker(
      context: context,
      initialDate: base.isBefore(DateTime.now()) ? DateTime.now() : base,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (day == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(base));
    if (time == null) return;
    final option = DateTime(day.year, day.month, day.day, time.hour, time.minute);
    if (_options.contains(option)) return;
    setState(
      () => _options
        ..add(option)
        ..sort(),
    );
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
            Text('Időpontok a szavazáshoz', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('Adj meg 2 vagy 3 lehetőséget.', style: TextStyle(color: AppColors.textMuted)),
            const SizedBox(height: 12),
            for (final o in _options)
              Card(
                margin: const EdgeInsets.only(bottom: 6),
                child: ListTile(
                  leading: Icon(Icons.event, color: AppColors.primary),
                  title: Text(formatOption(o), style: const TextStyle(fontWeight: FontWeight.w600)),
                  trailing: IconButton(
                    tooltip: 'Eltávolítás',
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _options.remove(o)),
                  ),
                ),
              ),
            if (_options.length < 3)
              OutlinedButton.icon(
                onPressed: _add,
                icon: const Icon(Icons.add),
                label: const Text('Időpont hozzáadása'),
              ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _options.length < 2 ? null : () => Navigator.pop(context, _options),
              child: const Text('Szavazás indítása'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Reakciók egy közös programra: egy koppintás, egy ember egy reakció.
class ReactionBar extends StatefulWidget {
  const ReactionBar({super.key, required this.eventId});

  final String eventId;

  @override
  State<ReactionBar> createState() => _ReactionBarState();
}

class _ReactionBarState extends State<ReactionBar> {
  late final _stream = Social.instance.watchReactions(widget.eventId);

  @override
  Widget build(BuildContext context) {
    final me = Social.instance.uid;
    return StreamBuilder<Map<String, List<String>>>(
      stream: _stream,
      builder: (context, snap) {
        final data = snap.data ?? const {};
        final mine = data.entries.where((e) => e.value.contains(me)).firstOrNull?.key;
        return Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final e in reactionEmojis)
              ChoiceChip(
                showCheckmark: false,
                label: Text('$e ${data[e]?.length ?? ''}'.trim()),
                selected: mine == e,
                onSelected: (on) => Social.instance.react(widget.eventId, on ? e : null).catchError((Object err) {
                  if (context.mounted) showSocialError(context, err);
                }),
              ),
          ],
        );
      },
    );
  }
}

/// Hozzászólások egy programhoz.
class ChatPanel extends StatefulWidget {
  const ChatPanel({super.key, required this.eventId, required this.isOwner});

  final String eventId;
  final bool isOwner;

  @override
  State<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<ChatPanel> {
  final _text = TextEditingController();
  late final Stream<List<ChatMessage>> _messages = Social.instance.watchMessages(widget.eventId);
  bool _sending = false;

  Future<void> _send() async {
    final text = _text.text.trim();
    if (text.isEmpty || _sending) return;
    final name = await ensureMyName(context);
    if (name == null || !mounted) return;
    setState(() => _sending = true);
    try {
      await Social.instance.send(widget.eventId, name: name, text: text);
      _text.clear();
    } catch (e) {
      if (mounted) showSocialError(context, e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final me = Social.instance.uid;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            StreamBuilder<List<ChatMessage>>(
              stream: _messages,
              builder: (context, snap) {
                if (snap.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text('A hozzászólások nem töltődtek be.', style: TextStyle(color: AppColors.textMuted)),
                  );
                }
                final messages = snap.data ?? const [];
                if (messages.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      'Még nincs hozzászólás. Itt beszélhetitek meg a részleteket.',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  );
                }
                return Column(
                  children: [
                    for (final m in messages)
                      _Bubble(
                        message: m,
                        mine: m.uid == me,
                        onDelete: m.uid == me || widget.isOwner
                            ? () => Social.instance.deleteMessage(widget.eventId, m.id)
                            : null,
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _text,
                    maxLength: 500,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(hintText: 'Hozzászólás…', counterText: ''),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(tooltip: 'Küldés', onPressed: _sending ? null : _send, icon: const Icon(Icons.send)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.mine, this.onDelete});

  final ChatMessage message;
  final bool mine;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final m = message;
    final fg = mine ? AppColors.onPrimary : AppColors.text;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onDelete == null
            ? null
            : () async {
                final ok = await confirm(context, title: 'Törlöd a hozzászólást?', action: 'Törlés');
                if (ok) onDelete!();
              },
        child: Container(
          constraints: const BoxConstraints(maxWidth: 280),
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: mine ? AppColors.primary : AppColors.background,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!mine)
                Text(
                  m.name,
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.primary),
                ),
              Text(m.text, style: TextStyle(color: fg)),
              if (m.at != null)
                Text(
                  DateFormat('MMM d. HH:mm', 'hu').format(m.at!),
                  style: TextStyle(fontSize: 11, color: mine ? fg.withValues(alpha: 0.75) : AppColors.textMuted),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Egy közös program közösségi része: résztvevők, visszajelzés, meghívás, szavazás, reakciók,
/// hozzászólások. A szervező és a meghívottak ugyanezt látják, a szervező néhány extra gombbal.
class SharedEventSection extends StatefulWidget {
  const SharedEventSection({super.key, required this.shareId, this.ownEvent});

  final String shareId;

  /// A szervező saját bejegyzése (null, ha meghívottként nézem).
  final Event? ownEvent;

  @override
  State<SharedEventSection> createState() => _SharedEventSectionState();
}

class _SharedEventSectionState extends State<SharedEventSection> {
  late final _event = Social.instance.watchEvent(widget.shareId);
  late final _rsvps = Social.instance.watchRsvps(widget.shareId);
  bool _busy = false;

  Future<void> _respond(RsvpStatus status) async {
    final name = await ensureMyName(context);
    if (name == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await Social.instance.respond(widget.shareId, name: name, status: status);
    } catch (e) {
      if (mounted) showSocialError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _invite() async {
    final own = widget.ownEvent;
    if (own == null) return;
    final picked = await showFriendPicker(context);
    if (picked == null || picked.isEmpty || !mounted) return;
    setState(() => _busy = true);
    try {
      await inviteFriendsTo(context, own, picked);
    } catch (e) {
      if (mounted) showSocialError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _nudge(SharedEvent shared) async {
    final store = StoreScope.of(context);
    final picked = await showFriendPicker(context, title: 'Kit böksz meg?', action: 'Tovább');
    if (picked == null || picked.isEmpty || !mounted) return;
    await showNudgeComposer(
      context,
      to: {for (final uid in picked) uid: store.nameOf(uid)},
      eventId: shared.id,
      eventTitle: shared.title,
    );
  }

  Future<void> _poll(SharedEvent shared) async {
    final options = await showPollEditor(context, shared.pollOptions.isEmpty ? [shared.date] : shared.pollOptions);
    if (options == null) return;
    try {
      await Social.instance.setPoll(shared.id, options);
    } catch (e) {
      if (mounted) showSocialError(context, e);
    }
  }

  Future<void> _choose(SharedEvent shared, DateTime date) async {
    final store = StoreScope.of(context);
    try {
      await Social.instance.choose(shared.id, date);
      final own = widget.ownEvent;
      if (own != null) {
        own.start = date;
        store.saveEvent(own);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Az időpont: ${formatOption(date)}')));
      }
    } catch (e) {
      if (mounted) showSocialError(context, e);
    }
  }

  Future<void> _vote(SharedEvent shared, Rsvp? mine, String key) async {
    final name = await ensureMyName(context);
    if (name == null) return;
    final votes = {...?mine?.votes};
    votes.contains(key) ? votes.remove(key) : votes.add(key);
    try {
      await Social.instance.respond(shared.id, name: name, votes: votes);
    } catch (e) {
      if (mounted) showSocialError(context, e);
    }
  }

  void _openMemories(SharedEvent shared) => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => MemoryScreen(
          eventId: shared.id,
          title: shared.title,
          start: shared.date,
          place: shared.place,
          going: shared.going.contains(Social.instance.uid),
          ownerUid: shared.ownerUid,
        ),
      ));

  Future<void> _report(SharedEvent shared) async {
    final reason = await showTextInputSheet(
      context,
      title: 'Program jelentése',
      hint: 'Mi a gond vele?',
      action: 'Jelentés',
    );
    if (reason == null || !mounted) return;
    try {
      await Friends.instance.report(eventId: shared.id, userUid: shared.ownerUid, reason: reason);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Köszönjük, megkaptuk.')));
    } catch (e) {
      if (mounted) showSocialError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SharedEvent?>(
      stream: _event,
      builder: (context, eventSnap) {
        if (eventSnap.hasError) {
          return const ErrorState(text: 'Nem sikerült betölteni a közös részt. Van internet?');
        }
        if (eventSnap.connectionState == ConnectionState.waiting) return const LoadingState();
        final shared = eventSnap.data;
        if (shared == null) {
          return const EmptyState(emoji: '🤷', text: 'Ez a közös program már nem létezik.');
        }
        final isOwner = shared.ownerUid == Social.instance.uid;
        return StreamBuilder<List<Rsvp>>(
          stream: _rsvps,
          builder: (context, snap) {
            final rsvps = snap.data ?? const <Rsvp>[];
            final mine = rsvps.where((r) => r.uid == Social.instance.uid).firstOrNull;
            final going = shared.going.length;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionTitle(
                  'Résztvevők',
                  trailing: shared.limit == null ? '$going megy' : '$going / ${shared.limit} hely',
                ),
                Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                        child: RsvpButtons(
                          current: mine?.status ?? RsvpStatus.none,
                          full: shared.full,
                          onChanged: _busy ? (_) {} : _respond,
                        ),
                      ),
                      if (shared.full && mine?.status != RsvpStatus.yes)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                          child: Text('Betelt a létszám.', style: TextStyle(color: AppColors.textMuted)),
                        ),
                      RsvpSummary(rsvps: rsvps),
                      if (isOwner && widget.ownEvent != null && Friends.instance.ready)
                        _ActionTile(
                          icon: Icons.group_add_outlined,
                          title: 'Barátok meghívása',
                          onTap: _busy ? null : _invite,
                        ),
                      if (isOwner && !shared.inviteOnly)
                        _ActionTile(
                          icon: Icons.link,
                          title: 'Meghívólink küldése',
                          subtitle: 'Az app nélkül is visszajelezhetnek.',
                          onTap: () => shareInvite(context, shared.title, Social.instance.linkFor(shared.id)),
                        ),
                      if (Friends.instance.ready)
                        _ActionTile(
                          icon: Icons.waving_hand_outlined,
                          title: 'Bökés a barátoknak',
                          subtitle: 'Rövid, barátságos emlékeztető erről a programról.',
                          onTap: () => _nudge(shared),
                        ),
                    ],
                  ),
                ),
                const SectionTitle('Reakciók'),
                ReactionBar(eventId: shared.id),
                SectionTitle(
                  'Emlékek',
                  onMore: () => _openMemories(shared),
                ),
                if (shared.date.isAfter(DateTime.now()))
                  Text('A program után itt oszthatjátok meg egymással a fotókat.', style: TextStyle(color: AppColors.textMuted))
                else
                  MemoryStrip(
                    eventId: shared.id,
                    going: shared.going.contains(Social.instance.uid),
                    onOpen: () => _openMemories(shared),
                  ),
                if (shared.pollOpen || isOwner) const SectionTitle('Időpont-szavazás'),
                if (shared.pollOpen)
                  PollCard(
                    event: shared,
                    rsvps: rsvps,
                    myVotes: mine?.votes ?? const {},
                    onToggleVote: (key) => _vote(shared, mine, key),
                    onChoose: isOwner ? (d) => _choose(shared, d) : null,
                  ),
                if (isOwner)
                  Card(
                    child: ListTile(
                      leading: Icon(Icons.how_to_vote_outlined, color: AppColors.primary),
                      title: Text(shared.pollOpen ? 'Lehetőségek módosítása' : 'Szavazás indítása'),
                      subtitle: Text(
                        shared.pollOpen
                            ? 'Az „Ez lesz” gombbal választod ki a végleges időpontot.'
                            : 'Ajánlj fel 2–3 időpontot, a barátaid megszavazzák.',
                      ),
                      onTap: () => _poll(shared),
                    ),
                  ),
                const SectionTitle('Hozzászólások'),
                ChatPanel(eventId: shared.id, isOwner: isOwner),
                if (!isOwner)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => _report(shared),
                      icon: Icon(Icons.flag_outlined, color: AppColors.textMuted),
                      label: Text('Program jelentése', style: TextStyle(color: AppColors.textMuted)),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.icon, required this.title, this.subtitle, this.onTap});

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon, color: AppColors.primary),
    title: Text(
      title,
      style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
    ),
    subtitle: subtitle == null ? null : Text(subtitle!),
    onTap: onTap,
  );
}
