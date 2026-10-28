import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../friends.dart';
import 'bump_screens.dart';
import '../models.dart';
import '../social.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';

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
  store.setMyName(name.trim().length > 40 ? name.trim().substring(0, 40) : name);
  return store.myName;
}

void _showError(BuildContext context, Object e) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text('Nem sikerült kapcsolódni. Van internet? ($e)', maxLines: 3),
  ));
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

/// Jövök / Talán / Nem jövök gombok.
class RsvpButtons extends StatelessWidget {
  const RsvpButtons({super.key, required this.current, required this.onChanged});

  final RsvpStatus current;
  final ValueChanged<RsvpStatus> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<RsvpStatus>(
      showSelectedIcon: false,
      emptySelectionAllowed: true,
      segments: [
        for (final s in [RsvpStatus.yes, RsvpStatus.maybe, RsvpStatus.no])
          ButtonSegment(value: s, label: Text('${s.emoji} ${s.label}')),
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
    if (rsvps.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text('Még senki nem jelzett vissza.', style: TextStyle(color: AppColors.textMuted)),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final s in RsvpStatus.values)
          if (rsvps.any((r) => r.status == s))
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${s.emoji} ${s.label} (${rsvps.where((r) => r.status == s).length})',
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final r in rsvps.where((r) => r.status == s))
                        Chip(avatar: NameAvatar(r.name, radius: 11), label: Text(r.name), visualDensity: VisualDensity.compact),
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
              child: Text('🗳️ Melyik időpont jó?', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
              child: Text('Jelöld be az összeset, ami neked jó.', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
            ),
            for (final o in event.pollOptions)
              Builder(builder: (context) {
                final key = o.toIso8601String();
                final voters = rsvps.where((r) => r.votes.contains(key)).toList();
                return CheckboxListTile(
                  value: myVotes.contains(key),
                  onChanged: (_) => onToggleVote(key),
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Row(
                    children: [
                      Flexible(child: Text(formatOption(o), style: const TextStyle(fontWeight: FontWeight.w700))),
                      if (o == best) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(8)),
                          child: const Text('⭐ Legjobb', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                        ),
                      ],
                    ],
                  ),
                  subtitle: Text(voters.isEmpty ? 'Még senkinek' : '${voters.length}: ${voters.map((r) => r.name).join(', ')}'),
                  secondary: onChoose == null
                      ? null
                      : TextButton(onPressed: () => onChoose!(o), child: const Text('Ez lesz')),
                );
              }),
          ],
        ),
      ),
    );
  }
}

/// Üzenőfal egy programhoz.
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
      await Social.instance.send(widget.eventId, name: name, text: text.length > 500 ? text.substring(0, 500) : text);
      _text.clear();
    } catch (e) {
      if (mounted) _showError(context, e);
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
                final messages = snap.data ?? const [];
                if (messages.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text('Még nincs üzenet. Kérdezd meg, ki mit hoz! 🍿',
                        style: TextStyle(color: AppColors.textMuted)),
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
                    decoration: const InputDecoration(hintText: 'Írj valamit… (pl. ki hoz chipset?)', counterText: ''),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: 'Küldés',
                  onPressed: _sending ? null : _send,
                  icon: const Icon(Icons.send),
                ),
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
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onDelete == null
            ? null
            : () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Törlöd az üzenetet?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Mégse')),
                      FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Törlés')),
                    ],
                  ),
                );
                if (ok == true) onDelete!();
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
                Text(m.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: AppColors.primary)),
              Text(m.text, style: TextStyle(color: mine ? Colors.white : null)),
              if (m.at != null)
                Text(DateFormat('MMM d. HH:mm', 'hu').format(m.at!),
                    style: TextStyle(fontSize: 10, color: mine ? Colors.white70 : AppColors.textMuted)),
            ],
          ),
        ),
      ),
    );
  }
}

/// A szervező része a program részleteinél: meghívólink, visszajelzések, szavazás, üzenőfal.
class OwnerSocialSection extends StatefulWidget {
  const OwnerSocialSection({super.key, required this.event});

  final Event event;

  @override
  State<OwnerSocialSection> createState() => _OwnerSocialSectionState();
}

class _OwnerSocialSectionState extends State<OwnerSocialSection> {
  bool _busy = false;
  Stream<SharedEvent?>? _shared;
  Stream<List<Rsvp>>? _rsvps;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  void _listen() {
    final id = widget.event.shareId;
    if (id == null) return;
    _shared = Social.instance.watchEvent(id);
    _rsvps = Social.instance.watchRsvps(id);
  }

  Future<void> _publish() async {
    final store = StoreScope.of(context);
    final name = await ensureMyName(context);
    if (name == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final id = await Social.instance.publish(widget.event, ownerName: name);
      widget.event.shareId = id;
      store.saveEvent(widget.event);
      _listen();
      if (mounted) await shareInvite(context, widget.event.title, Social.instance.linkFor(id));
    } catch (e) {
      if (mounted) _showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Barátok meghívása egy gombnyomással: a program (ha kell) megosztódik, és a barátaid
  /// „Meghívásaim” listájába kerül, link küldése nélkül.
  Future<void> _inviteFriends() async {
    final store = StoreScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final List<Friend> all;
    try {
      all = await Friends.instance.watchFriends().first;
    } catch (e) {
      if (mounted) _showError(context, e);
      return;
    }
    if (!mounted) return;
    if (all.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('Még nincs barátod az appban. A Barátok oldalon add meg a kódjukat!')));
      return;
    }
    final picked = await showModalBottomSheet<List<String>>(
      context: context,
      showDragHandle: true,
      builder: (_) => _FriendPicker(friends: all),
    );
    if (picked == null || picked.isEmpty || !mounted) return;
    final name = await ensureMyName(context);
    if (name == null || !mounted) return;
    setState(() => _busy = true);
    try {
      if (widget.event.shareId == null) {
        widget.event.shareId = await Social.instance.publish(widget.event, ownerName: name);
        store.saveEvent(widget.event);
        _listen();
      }
      await Friends.instance.invite(widget.event, picked);
      messenger.showSnackBar(SnackBar(content: Text('Meghívtad: ${picked.length} barát. 🎉')));
    } catch (e) {
      if (mounted) _showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _startPoll(SharedEvent shared) async {
    final options = await showModalBottomSheet<List<DateTime>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _PollEditor(initial: shared.pollOptions.isEmpty ? [widget.event.date] : shared.pollOptions),
    );
    if (options == null) return;
    try {
      await Social.instance.setPoll(shared.id, options);
    } catch (e) {
      if (mounted) _showError(context, e);
    }
  }

  Future<void> _choose(SharedEvent shared, DateTime date) async {
    final store = StoreScope.of(context);
    try {
      await Social.instance.choose(shared.id, date);
      widget.event.date = date;
      store.saveEvent(widget.event);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Az időpont: ${formatOption(date)}')));
      }
    } catch (e) {
      if (mounted) _showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.event.shareId;
    if (id == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionTitle('Ki jön?'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Küldj meghívólinket a barátaidnak! Visszajelezhetnek, szavazhatnak az időpontról, '
                      'és írhatnak az üzenőfalra. Nem kell hozzá telepíteniük az appot.'),
                  const SizedBox(height: 12),
                  if (Friends.instance.ready) ...[
                    FilledButton.icon(
                      onPressed: _busy ? null : _inviteFriends,
                      icon: const Icon(Icons.group_add_outlined),
                      label: const Text('Barátok meghívása'),
                    ),
                    const SizedBox(height: 8),
                  ],
                  FilledButton.icon(
                    onPressed: _busy ? null : _publish,
                    icon: _busy
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.link),
                    label: const Text('Meghívólink létrehozása'),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }
    return StreamBuilder<SharedEvent?>(
      stream: _shared,
      builder: (context, eventSnap) {
        if (eventSnap.hasError) {
          return Card(child: ListTile(title: Text('Nem sikerült betölteni a visszajelzéseket. Van internet?',
              style: TextStyle(color: AppColors.textMuted))));
        }
        final shared = eventSnap.data;
        if (shared == null) return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
        return StreamBuilder<List<Rsvp>>(
          stream: _rsvps,
          builder: (context, snap) {
            final rsvps = snap.data ?? const <Rsvp>[];
            final mine = rsvps.where((r) => r.uid == Social.instance.uid).firstOrNull;
            final coming = rsvps.where((r) => r.status == RsvpStatus.yes).length;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionTitle('Ki jön?', trailing: coming == 0 ? null : '$coming jön'),
                Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      RsvpSummary(rsvps: rsvps),
                      if (Friends.instance.ready)
                        ListTile(
                          leading: const Icon(Icons.group_add_outlined, color: AppColors.primary),
                          title: const Text('Barátok meghívása',
                              style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
                          onTap: _busy ? null : _inviteFriends,
                        ),
                      if (Friends.instance.ready)
                        ListTile(
                          leading: const Text('👋', style: TextStyle(fontSize: 22)),
                          title: const Text('Bump a barátoknak',
                              style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
                          subtitle: const Text('Emlékeztető képpel, hanggal, konfettivel'),
                          onTap: () async {
                            final all = await Friends.instance.watchFriends().first;
                            if (!context.mounted) return;
                            if (all.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Még nincs barátod az appban.')));
                              return;
                            }
                            final picked = await showModalBottomSheet<List<String>>(
                              context: context,
                              showDragHandle: true,
                              builder: (_) => _FriendPicker(friends: all),
                            );
                            if (picked == null || picked.isEmpty || !context.mounted) return;
                            await showBumpComposer(
                              context,
                              to: {for (final f in all) if (picked.contains(f.uid)) f.uid: f.name},
                              event: widget.event,
                            );
                          },
                        ),
                      ListTile(
                        leading: const Icon(Icons.share_outlined, color: AppColors.primary),
                        title: const Text('Meghívólink küldése',
                            style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
                        onTap: () => shareInvite(context, widget.event.title, Social.instance.linkFor(id)),
                      ),
                    ],
                  ),
                ),
                const SectionTitle('Ki mit hoz?'),
                BringList(eventId: id, isOwner: true),
                const SectionTitle('Időpont'),
                if (shared.pollOpen)
                  PollCard(
                    event: shared,
                    rsvps: rsvps,
                    myVotes: mine?.votes ?? const {},
                    onToggleVote: (key) {
                      final votes = {...?mine?.votes};
                      votes.contains(key) ? votes.remove(key) : votes.add(key);
                      Social.instance.respond(id, name: StoreScope.of(context).myName, votes: votes);
                    },
                    onChoose: (d) => _choose(shared, d),
                  ),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.how_to_vote_outlined, color: AppColors.primary),
                    title: Text(shared.pollOpen ? 'Lehetőségek módosítása' : 'Időpont-szavazás indítása',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: shared.pollOpen
                        ? const Text('A „Ez lesz” gombbal választod ki a végleges időpontot.')
                        : const Text('Ajánlj fel 2–3 időpontot, a barátaid megszavazzák.'),
                    onTap: () => _startPoll(shared),
                  ),
                ),
                const SectionTitle('Üzenőfal'),
                ChatPanel(eventId: id, isOwner: true),
              ],
            );
          },
        );
      },
    );
  }
}

/// 2–3 időpont összeállítása a szavazáshoz.
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
    setState(() => _options
      ..add(option)
      ..sort());
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
                  leading: const Icon(Icons.event, color: AppColors.primary),
                  title: Text(formatOption(o), style: const TextStyle(fontWeight: FontWeight.w700)),
                  trailing: IconButton(
                    tooltip: 'Eltávolítás',
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _options.remove(o)),
                  ),
                ),
              ),
            if (_options.length < 3)
              OutlinedButton.icon(onPressed: _add, icon: const Icon(Icons.add), label: const Text('Időpont hozzáadása')),
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

/// Kiket hívsz meg az app-beli barátaid közül.
class _FriendPicker extends StatefulWidget {
  const _FriendPicker({required this.friends});

  final List<Friend> friends;

  @override
  State<_FriendPicker> createState() => _FriendPickerState();
}

class _FriendPickerState extends State<_FriendPicker> {
  final Set<String> _picked = {};

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Kiket hívsz meg?', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final f in widget.friends)
                    CheckboxListTile(
                      secondary: NameAvatar(f.name),
                      title: Text(f.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      value: _picked.contains(f.uid),
                      onChanged: (on) => setState(() => on == true ? _picked.add(f.uid) : _picked.remove(f.uid)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _picked.isEmpty ? null : () => Navigator.pop(context, _picked.toList()),
              child: Text(_picked.isEmpty ? 'Válassz barátot' : 'Meghívás (${_picked.length})'),
            ),
          ],
        ),
      ),
    );
  }
}

/// „Ki mit hoz?”: tételek, amiket bárki elvállalhat; látszik, mi hiányzik még.
class BringList extends StatefulWidget {
  const BringList({super.key, required this.eventId, required this.isOwner, this.nameOf});

  final String eventId;
  final bool isOwner;

  /// A vendég oldalon a név a meghívás képernyőjén van beírva; innen kérjük el.
  final String? Function()? nameOf;

  @override
  State<BringList> createState() => _BringListState();
}

class _BringListState extends State<BringList> {
  late final Stream<List<BringItem>> _items = Social.instance.watchItems(widget.eventId);
  final _text = TextEditingController();

  Future<String?> _name() async {
    final fromField = widget.nameOf?.call();
    if (fromField != null && fromField.isNotEmpty) return fromField;
    return ensureMyName(context);
  }

  Future<void> _add() async {
    final title = _text.text.trim();
    if (title.isEmpty) return;
    final name = await _name();
    if (name == null || !mounted) return;
    try {
      await Social.instance.addItem(widget.eventId, title: title, name: name);
      _text.clear();
    } catch (e) {
      if (mounted) _showError(context, e);
    }
  }

  Future<void> _claim(BringItem item, bool take) async {
    final name = take ? await _name() : null;
    if (take && name == null) return;
    try {
      await Social.instance.claimItem(widget.eventId, item.id, name: name);
    } catch (e) {
      if (mounted) _showError(context, e);
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
        padding: const EdgeInsets.fromLTRB(4, 8, 12, 12),
        child: StreamBuilder<List<BringItem>>(
          stream: _items,
          builder: (context, snap) {
            final items = snap.data ?? const <BringItem>[];
            final missing = items.where((i) => i.who == null).length;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 0, 8),
                    child: Text('Mi kell még? Írd fel, és valaki elvállalja (chips, üdítő, társas…).',
                        style: TextStyle(color: AppColors.textMuted)),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 0, 4),
                    child: Text(missing == 0 ? 'Minden megvan! 🎉' : 'Még $missing tétel vár gazdára',
                        style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w700)),
                  ),
                for (final i in items)
                  ListTile(
                    dense: true,
                    leading: Icon(i.who == null ? Icons.radio_button_unchecked : Icons.check_circle,
                        color: i.who == null ? AppColors.textMuted : AppColors.primary),
                    title: Text(i.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: i.who == null ? null : Text('${i.whoName} hozza'),
                    trailing: i.who == null
                        ? TextButton(onPressed: () => _claim(i, true), child: const Text('Elvállalom'))
                        : i.who == me
                            ? TextButton(onPressed: () => _claim(i, false), child: const Text('Mégsem'))
                            : null,
                    onLongPress: i.addedBy == me || widget.isOwner ? () => Social.instance.deleteItem(widget.eventId, i.id) : null,
                  ),
                Padding(
                  padding: const EdgeInsets.only(left: 12, top: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _text,
                          maxLength: 60,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(hintText: 'Új tétel (pl. chips)', counterText: ''),
                          onSubmitted: (_) => _add(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(tooltip: 'Hozzáadás', onPressed: _add, icon: const Icon(Icons.add)),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
