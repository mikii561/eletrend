import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../availability_service.dart';
import '../formatting.dart';
import '../friends.dart';
import '../models.dart';
import '../nudges.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'challenges_screen.dart';
import 'event_editor.dart';
import 'find_time_screen.dart';
import 'nudge_screens.dart';
import 'status_sheet.dart';

/// Barátok: állapotom, jelölések, „Mikor érünk rá?”, csoportok, barátlista elérhetőséggel.
class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  // Egyszer iratkozunk fel, nem minden újrarajzolásnál.
  late final Stream<List<FriendRequest>>? _requests = Friends.instance.ready ? Friends.instance.watchRequests() : null;
  late final Stream<List<Friend>>? _friends = Friends.instance.ready ? Friends.instance.watchFriends() : null;
  late final Stream<int> _unseenNudges = Nudges.instance.watchUnseenCount();
  Future<Map<String, FriendAvailability?>>? _availability;
  String _availabilityKey = '';

  void _loadAvailability(List<Friend> friends) {
    final key = friends.map((f) => f.uid).join(',');
    if (key == _availabilityKey && _availability != null) return;
    _availabilityKey = key;
    _availability = AvailabilityService.instance.fetchAll(friends.map((f) => f.uid));
  }

  Future<void> _refresh() async {
    setState(() => _availabilityKey = '');
  }

  Future<void> _addByCode() async {
    final messenger = ScaffoldMessenger.of(context);
    final code = await showTextInputSheet(context, title: 'Barát kódja', hint: 'pl. K7M2QX', action: 'Jelölés');
    if (code == null || code.trim().isEmpty) return;
    try {
      await Friends.instance.addByCode(code);
      messenger.showSnackBar(
        const SnackBar(content: Text('Jelölés elküldve. Ha elfogadja, megjelenik a barátaid között.')),
      );
    } on FriendException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Nem sikerült. Van internet? ($e)')));
    }
  }

  Future<void> _shareCode(String code) async {
    final messenger = ScaffoldMessenger.of(context);
    final text = 'Jelölj be barátnak a LIFEUP-ban! A kódom: $code\nhttps://mikii561.github.io/eletrend/';
    try {
      final r = await SharePlus.instance.share(ShareParams(text: text));
      if (r.status != ShareResultStatus.unavailable) return;
    } catch (_) {
      // nincs megosztás menü: vágólap
    }
    await Clipboard.setData(ClipboardData(text: code));
    messenger.showSnackBar(const SnackBar(content: Text('A kódod a vágólapon.')));
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final friends = Friends.instance;
    final status = store.statusAt(DateTime.now());
    return Scaffold(
      appBar: AppBar(
        title: const Text('Barátok'),
        actions: [
          if (Nudges.instance.ready)
            IconButton(
              tooltip: 'Kapott bökések',
              icon: StreamBuilder<int>(
                stream: _unseenNudges,
                builder: (context, snap) => CountBadge(
                  count: snap.data ?? 0,
                  label: 'olvasatlan bökés',
                  child: const Icon(Icons.waving_hand_outlined),
                ),
              ),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NudgeInboxScreen())),
            ),
          IconButton(
            tooltip: 'Barát hozzáadása',
            icon: const Icon(Icons.person_add_alt_outlined),
            onPressed: friends.ready ? _addByCode : null,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: !friends.ready
          ? ListView(
              padding: const EdgeInsets.all(16),
              children: const [ErrorState(text: 'A barátokhoz internet kell. Próbáld újra kicsit később.')],
            )
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                children: [
                  Card(
                    child: ListTile(
                      leading: Icon(statusIcon(status), color: AppColors.status(status)),
                      title: Text('Az állapotod: ${status.label}', style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        store.shareAvailability == AvailabilityShare.nobody
                            ? 'Senkivel nem osztod meg, mikor érsz rá.'
                            : 'Látja: ${store.shareAvailability.label.toLowerCase()}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => showStatusSheet(context),
                    ),
                  ),
                  StreamBuilder<List<FriendRequest>>(
                    stream: _requests,
                    builder: (context, snap) {
                      final list = snap.data ?? const [];
                      if (list.isEmpty) return const SizedBox.shrink();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SectionTitle('Jelölések', trailing: '${list.length}'),
                          for (final r in list)
                            Card(
                              child: ListTile(
                                leading: NameAvatar(r.fromName),
                                title: Text(r.fromName, style: const TextStyle(fontWeight: FontWeight.w600)),
                                subtitle: const Text('Barátnak jelölt'),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: 'Elutasítás',
                                      icon: const Icon(Icons.close),
                                      onPressed: () => friends.decline(r),
                                    ),
                                    IconButton.filled(
                                      tooltip: 'Elfogadás',
                                      icon: const Icon(Icons.check),
                                      onPressed: () => friends.accept(r),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () =>
                              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FindTimeScreen())),
                          icon: const Icon(Icons.event_available_outlined),
                          label: const Text('Mikor érünk rá?'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                          onPressed: () =>
                              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChallengesScreen())),
                          icon: const Icon(Icons.emoji_events_outlined),
                          label: const Text('Kihívások'),
                        ),
                      ),
                    ],
                  ),
                  SectionTitle('Csoportok', trailing: store.groups.isEmpty ? null : '${store.groups.length}'),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final g in store.groups)
                        ActionChip(
                          avatar: const Icon(Icons.group_outlined, size: 18),
                          label: Text('${g.name} · ${g.members.length}'),
                          onPressed: () => showGroupEditor(context, group: g),
                        ),
                      ActionChip(
                        avatar: const Icon(Icons.add, size: 18),
                        label: const Text('Új csoport'),
                        onPressed: () => showGroupEditor(context),
                      ),
                    ],
                  ),
                  StreamBuilder<List<Friend>>(
                    stream: _friends,
                    builder: (context, snap) {
                      if (snap.hasError) return const ErrorState(text: 'A barátlista nem töltődött be. Van internet?');
                      if (!snap.hasData) return const LoadingState();
                      final list = snap.data!;
                      if (list.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.only(top: 16),
                          child: EmptyState(
                            emoji: '👋',
                            text:
                                'Még nincs barátod az appban.\nKüldd el a kódodat, vagy add meg az övékét a + gombbal.',
                          ),
                        );
                      }
                      _loadAvailability(list);
                      return FutureBuilder<Map<String, FriendAvailability?>>(
                        future: _availability,
                        builder: (context, a) {
                          final data = a.data ?? const {};
                          final now = DateTime.now();
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SectionTitle('Barátaim', trailing: '${list.length}'),
                              Card(
                                child: Column(
                                  children: [
                                    for (final f in list)
                                      _FriendTile(friend: f, availability: data[f.uid], loading: !a.hasData, now: now),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                  const SectionTitle('A barátkódod'),
                  Card(
                    child: ListTile(
                      title: SelectableText(
                        friends.myCode ?? '…',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 5,
                          color: AppColors.primary,
                        ),
                      ),
                      subtitle: const Text('Add meg a barátodnak, vagy kérd el az övét.'),
                      trailing: IconButton(
                        tooltip: 'Megosztás',
                        icon: const Icon(Icons.share_outlined),
                        onPressed: friends.myCode == null ? null : () => _shareCode(friends.myCode!),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _FriendTile extends StatelessWidget {
  const _FriendTile({required this.friend, required this.availability, required this.loading, required this.now});

  final Friend friend;
  final FriendAvailability? availability;
  final bool loading;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final a = availability;
    final status = a?.statusAt(now);
    final freeFrom = status == AvailabilityStatus.busy ? a?.freeFrom(now) : null;
    final subtitle = loading
        ? '…'
        : status == null
        ? 'Nem osztja meg az elérhetőségét'
        : freeFrom != null && sameDay(freeFrom, now)
        ? '${status.label} · ${formatTime(freeFrom)}-tól szabad'
        : status.label;
    return ListTile(
      leading: status == null
          ? NameAvatar(friend.name, photo: friend.photo)
          : Badge(
              backgroundColor: AppColors.status(status),
              smallSize: 11,
              alignment: Alignment.bottomRight,
              child: NameAvatar(friend.name, photo: friend.photo),
            ),
      title: Text(friend.name, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.more_horiz),
      onTap: () => showFriendSheet(context, friend),
    );
  }
}

/// Egy barát lapja: közös időpont, meghívás, bökés, csoportok, eltávolítás, letiltás, jelentés.
Future<void> showFriendSheet(BuildContext context, Friend f) {
  final store = StoreScope.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);
  final birthday = nextBirthdayOf(f.birthday);
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              leading: NameAvatar(f.name, radius: 22, photo: f.photo),
              title: Text(f.name, style: Theme.of(context).textTheme.titleLarge),
              subtitle: birthday == null ? null : Text('Születésnap: ${formatDay(birthday)}'),
            ),
            if (f.streaks.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final (name, days) in f.streaks)
                      Pill('$name · $days', icon: Icons.local_fire_department_outlined),
                  ],
                ),
              ),
            const Divider(),
            SettingsTile(
              icon: Icons.event_available_outlined,
              title: 'Közös időpont keresése',
              onTap: () {
                navigator.pop();
                navigator.push(MaterialPageRoute(builder: (_) => FindTimeScreen(initialUids: [f.uid])));
              },
            ),
            SettingsTile(
              icon: Icons.celebration_outlined,
              title: 'Meghívás egy programra',
              onTap: () {
                navigator.pop();
                navigator.push(MaterialPageRoute(builder: (_) => EventEditor(inviteUids: [f.uid], social: true)));
              },
            ),
            SettingsTile(
              icon: Icons.waving_hand_outlined,
              title: 'Bökés',
              onTap: () {
                navigator.pop();
                showNudgeComposer(navigator.context, to: {f.uid: f.name});
              },
            ),
            if (store.groups.isNotEmpty)
              SettingsTile(
                icon: Icons.group_outlined,
                title: 'Csoportok',
                subtitle: store.groups.where((g) => g.members.contains(f.uid)).map((g) => g.name).join(', '),
                onTap: () {
                  navigator.pop();
                  _pickGroups(navigator.context, f);
                },
              ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.person_remove_outlined),
              title: const Text('Barát eltávolítása'),
              onTap: () async {
                final ok = await confirm(context, title: 'Eltávolítod ${f.name}-t?', text: 'Később újra bejelölheted.', action: 'Eltávolítás');
                if (!ok) return;
                navigator.pop();
                await Friends.instance
                    .remove(f.uid)
                    .catchError((Object e) => messenger.showSnackBar(SnackBar(content: Text('Nem sikerült: $e'))));
              },
            ),
            ListTile(
              leading: Icon(Icons.block, color: AppColors.danger),
              title: Text('Letiltás', style: TextStyle(color: AppColors.danger)),
              subtitle: const Text('Nem lesztek barátok, és nem jelölhet, hívhat meg, bökhet meg.'),
              onTap: () async {
                if (!await confirm(context, title: 'Letiltod ${f.name}-t?', action: 'Letiltás', danger: true)) return;
                navigator.pop();
                try {
                  await Friends.instance.block(f.uid, f.name);
                  messenger.showSnackBar(
                    SnackBar(content: Text('${f.name} letiltva. A Profil → Adatvédelem alatt feloldhatod.')),
                  );
                } catch (e) {
                  messenger.showSnackBar(SnackBar(content: Text('Nem sikerült: $e')));
                }
              },
            ),
            ListTile(
              leading: Icon(Icons.flag_outlined, color: AppColors.textMuted),
              title: const Text('Jelentés'),
              onTap: () async {
                final reason = await showTextInputSheet(
                  context,
                  title: 'Mi a gond?',
                  hint: 'Írd le röviden',
                  action: 'Jelentés',
                );
                if (reason == null || reason.trim().isEmpty) return;
                navigator.pop();
                try {
                  await Friends.instance.report(userUid: f.uid, reason: reason);
                  messenger.showSnackBar(const SnackBar(content: Text('Köszönjük, megkaptuk.')));
                } catch (e) {
                  messenger.showSnackBar(SnackBar(content: Text('Nem sikerült: $e')));
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );
}

Future<void> _pickGroups(BuildContext context, Friend f) {
  final store = StoreScope.of(context);
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${f.name} csoportjai', style: Theme.of(context).textTheme.titleLarge),
            for (final g in store.groups)
              CheckboxListTile(
                title: Text(g.name),
                value: g.members.contains(f.uid),
                onChanged: (on) => setState(() {
                  on == true ? g.members.add(f.uid) : g.members.remove(f.uid);
                  store.saveGroup(g);
                }),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );
}

/// Csoport létrehozása vagy szerkesztése: név és tagok.
Future<void> showGroupEditor(BuildContext context, {FriendGroup? group}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _GroupEditor(group: group),
  );
}

class _GroupEditor extends StatefulWidget {
  const _GroupEditor({this.group});

  final FriendGroup? group;

  @override
  State<_GroupEditor> createState() => _GroupEditorState();
}

class _GroupEditorState extends State<_GroupEditor> {
  late final _name = TextEditingController(text: widget.group?.name);
  late final Set<String> _members = {...?widget.group?.members};
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Adj nevet a csoportnak.');
      return;
    }
    final store = StoreScope.of(context);
    final g = widget.group ?? FriendGroup(id: newId(), name: name);
    g
      ..name = name
      ..members = _members.toList();
    store.saveGroup(g);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final friends = [...store.friendsCache]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.group == null ? 'Új csoport' : 'Csoport', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Csak te látod. Meghívásnál és közös időpontnál egy koppintással kiválaszthatod őket.',
              style: TextStyle(color: AppColors.textMuted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              maxLength: 40,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Név (pl. Foci csapat, Család)',
                errorText: _error,
                counterText: '',
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  if (friends.isEmpty) const ListTile(title: Text('Előbb jelölj be barátokat.')),
                  for (final f in friends)
                    CheckboxListTile(
                      secondary: NameAvatar(f.name),
                      title: Text(f.name),
                      value: _members.contains(f.uid),
                      onChanged: (on) => setState(() => on == true ? _members.add(f.uid) : _members.remove(f.uid)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (widget.group != null)
                  TextButton.icon(
                    onPressed: () {
                      StoreScope.of(context).removeGroup(widget.group!);
                      Navigator.pop(context);
                    },
                    icon: Icon(Icons.delete_outline, color: AppColors.danger),
                    label: Text('Törlés', style: TextStyle(color: AppColors.danger)),
                  ),
                const Spacer(),
                FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size(140, 48)),
                  onPressed: _save,
                  child: const Text('Mentés'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
