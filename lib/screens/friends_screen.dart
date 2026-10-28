import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../bumps.dart';
import '../friends.dart';
import 'bump_screens.dart';
import 'challenges_screen.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Barátok: az appban lévők (kóddal jelölve, sorozatokkal) és a csak név szerint felvettek.
class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  // Egyszer iratkozunk fel, nem minden újrarajzolásnál.
  late final Stream<List<FriendRequest>>? _requests = Friends.instance.ready ? Friends.instance.watchRequests() : null;
  late final Stream<List<Friend>>? _friends = Friends.instance.ready ? Friends.instance.watchFriends() : null;

  /// Akiktől némítottam a bumpokat.
  final Set<String> _muted = {};

  @override
  void initState() {
    super.initState();
    if (Bumps.instance.ready) {
      Bumps.instance.settings().then((s) {
        if (mounted) setState(() => _muted.addAll(s.muted));
      }).catchError((_) {});
    }
  }

  Future<void> _addByCode(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final code = await showTextInputSheet(context, title: 'Barát kódja', hint: 'pl. K7M2QX', action: 'Jelölés');
    if (code == null || code.trim().isEmpty) return;
    try {
      await Friends.instance.addByCode(code);
      messenger.showSnackBar(const SnackBar(content: Text('Jelölés elküldve! Ha elfogadja, megjelenik a barátaid között.')));
    } on FriendException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Nem sikerült. Van internet? ($e)')));
    }
  }

  Future<void> _shareCode(BuildContext context, String code) async {
    final messenger = ScaffoldMessenger.of(context);
    final text = 'Jelölj be barátnak az Életrendben! A kódom: $code\nhttps://mikii561.github.io/eletrend/';
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
    return Scaffold(
      appBar: AppBar(title: const Text('Barátok')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          if (!friends.ready)
            const EmptyState(emoji: '📡', text: 'A barátokhoz internet kell.\nPróbáld újra kicsit később.')
          else ...[
            Card(
              child: ListTile(
                leading: const Text('👋', style: TextStyle(fontSize: 26)),
                title: const Text('Kapott bumpok', style: TextStyle(fontWeight: FontWeight.w800)),
                subtitle: const Text('A barátaid üzenetei, képei, hangüzenetei.'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BumpsInboxScreen())),
              ),
            ),
            Card(
              color: AppColors.accent.withValues(alpha: 0.12),
              child: ListTile(
                leading: const Text('🏁', style: TextStyle(fontSize: 26)),
                title: const Text('Közös kihívások', style: TextStyle(fontWeight: FontWeight.w800)),
                subtitle: const Text('Pl. 30 nap edzés a barátaiddal, ranglistával.'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChallengesScreen())),
              ),
            ),
            // Saját kód
            Card(
              color: AppColors.primary.withValues(alpha: 0.10),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text('A barátkódod', style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    SelectableText(
                      friends.myCode ?? '…',
                      style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: 6, color: AppColors.primary),
                    ),
                    const SizedBox(height: 4),
                    Text('Add meg a barátodnak, vagy kérd el az övét.',
                        textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: friends.myCode == null ? null : () => _shareCode(context, friends.myCode!),
                            icon: const Icon(Icons.share_outlined),
                            label: const Text('Megosztás'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                            onPressed: () => _addByCode(context),
                            icon: const Icon(Icons.person_add_alt_1),
                            label: const Text('Kód megadása'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Jelölések
            StreamBuilder<List<FriendRequest>>(
              stream: _requests,
              builder: (context, snap) {
                final requests = snap.data ?? const [];
                if (requests.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SectionTitle('Barátjelölések', trailing: '${requests.length}'),
                    for (final r in requests)
                      Card(
                        child: ListTile(
                          leading: NameAvatar(r.fromName),
                          title: Text(r.fromName, style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: const Text('Barátnak jelölt'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(tooltip: 'Elutasítás', icon: const Icon(Icons.close), onPressed: () => friends.decline(r)),
                              IconButton.filled(tooltip: 'Elfogadás', icon: const Icon(Icons.check), onPressed: () => friends.accept(r)),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),

            // Barátok az appban
            const SectionTitle('Barátaim az appban'),
            StreamBuilder<List<Friend>>(
              stream: _friends,
              builder: (context, snap) {
                final list = snap.data;
                if (list == null) return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
                if (list.isEmpty) {
                  return Card(
                    child: ListTile(
                      title: Text('Még nincs barátod az appban. Küldd el nekik a kódodat!',
                          style: TextStyle(color: AppColors.textMuted)),
                    ),
                  );
                }
                return Card(
                  child: Column(
                    children: [
                      for (final f in list)
                        ListTile(
                          leading: NameAvatar(f.name, radius: 20),
                          title: Text(f.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: f.streaks.isEmpty
                              ? null
                              : Text(f.streaks.take(3).map((s) => '🔥 ${s.$1} ${s.$2} nap').join(' · ')),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton.filledTonal(
                                tooltip: 'Bump',
                                onPressed: () => showBumpComposer(context, to: {f.uid: f.name}),
                                icon: const Text('👋', style: TextStyle(fontSize: 18)),
                              ),
                              PopupMenuButton<String>(
                                onSelected: (v) async {
                                  if (v == 'remove') return friends.remove(f.uid);
                                  final mute = !_muted.contains(f.uid);
                                  await Bumps.instance.setMuted(f.uid, mute);
                                  setState(() => mute ? _muted.add(f.uid) : _muted.remove(f.uid));
                                },
                                itemBuilder: (_) => [
                                  PopupMenuItem(
                                    value: 'mute',
                                    child: Text(_muted.contains(f.uid) ? 'Bumpok újra engedélyezése' : 'Bumpok némítása tőle'),
                                  ),
                                  const PopupMenuItem(value: 'remove', child: Text('Barát eltávolítása')),
                                ],
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
            Card(
              child: SwitchListTile(
                secondary: const Text('🔥', style: TextStyle(fontSize: 22)),
                title: const Text('Sorozataim megosztása', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('A barátaid látják, hány napja tartod a szokásaidat. A naplód nem látszik.'),
                value: store.shareStreaks,
                onChanged: store.setShareStreaks,
              ),
            ),
          ],

          // Csak név szerint (pl. a költségmegosztáshoz azok, akiknek nincs fiókjuk)
          const SectionTitle('Csak név szerint'),
          Card(
            child: Column(
              children: [
                for (final f in store.friends)
                  ListTile(
                    leading: NameAvatar(f, radius: 20),
                    title: Text(f, style: const TextStyle(fontWeight: FontWeight.w700)),
                    trailing: IconButton(
                      tooltip: 'Eltávolítás',
                      icon: Icon(Icons.close, color: AppColors.textMuted),
                      onPressed: () => store.removeFriend(f),
                    ),
                  ),
                ListTile(
                  leading: const Icon(Icons.person_add_alt_outlined, color: AppColors.primary),
                  title: const Text('Név hozzáadása', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
                  subtitle: const Text('Akinek nincs fiókja: meghívólinkkel hívhatod, és a költségeknél is szerepelhet.'),
                  onTap: () async {
                    final name = await showTextInputSheet(context, title: 'Új név', hint: 'Név', action: 'Hozzáadás');
                    if (name != null) store.addFriend(name);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
