import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../admin.dart';
import '../community.dart';
import '../theme.dart';
import '../widgets/common.dart';

String _when(DateTime? d) => d == null ? '–' : DateFormat('yyyy. MMM d. HH:mm', 'hu').format(d);

/// Admin felület: áttekintés, felhasználók, hibák, visszajelzések, megosztott programok.
class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 6,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin'),
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Áttekintés'),
              Tab(text: 'Felhasználók'),
              Tab(text: 'Hibák'),
              Tab(text: 'Visszajelzések'),
              Tab(text: 'Programok'),
              Tab(text: 'Ötletek'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_Overview(), _Users(), _Errors(), _FeedbackList(), _SharedEvents(), _CommunityIdeas()],
        ),
      ),
    );
  }
}

/// Betöltés, hiba és frissítés (lehúzással) egy helyen.
class _Loader<T> extends StatefulWidget {
  const _Loader({required this.load, required this.builder});

  final Future<T> Function() load;
  final Widget Function(BuildContext context, T data, VoidCallback reload) builder;

  @override
  State<_Loader<T>> createState() => _LoaderState<T>();
}

class _LoaderState<T> extends State<_Loader<T>> {
  late Future<T> _future = widget.load();

  void _reload() {
    final future = widget.load();
    setState(() {
      _future = future;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: _future,
      builder: (context, snap) {
        if (snap.hasError) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              EmptyState(emoji: '⚠️', text: 'Nem sikerült betölteni.\n${snap.error}', action: 'Újra', onAction: _reload),
            ],
          );
        }
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: widget.builder(context, snap.data as T, _reload),
        );
      },
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview();

  @override
  Widget build(BuildContext context) {
    return _Loader<AdminStats>(
      load: Admin.instance.stats,
      builder: (context, s, _) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(children: [
            _Tile('Felhasználó', '${s.total}'),
            const SizedBox(width: 8),
            _Tile('Aktív (7 nap)', '${s.active7}'),
            const SizedBox(width: 8),
            _Tile('Aktív (30 nap)', '${s.active30}'),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            _Tile('Új a héten', '${s.newThisWeek}'),
            const SizedBox(width: 8),
            _Tile('Nyitott visszajelzés', '${s.openFeedback}'),
            const SizedBox(width: 8),
            _Tile('Hiba (24 óra)', '${s.errors24h}', warn: s.errors24h > 0),
          ]),
          const SectionTitle('Tartalom összesen'),
          Card(
            child: Column(children: [
              ListTile(leading: const Text('📔', style: TextStyle(fontSize: 22)), title: const Text('Naplóbejegyzés'), trailing: _Num(s.totals['journal'])),
              ListTile(leading: const Text('✅', style: TextStyle(fontSize: 22)), title: const Text('Cél'), trailing: _Num(s.totals['habits'])),
              ListTile(leading: const Text('🎉', style: TextStyle(fontSize: 22)), title: const Text('Program'), trailing: _Num(s.totals['events'])),
              ListTile(leading: const Text('🔗', style: TextStyle(fontSize: 22)), title: const Text('Megosztott program'), trailing: _Num(s.sharedEvents)),
            ]),
          ),
          const SectionTitle('Platformok'),
          Card(
            child: Column(children: [
              for (final e in s.platforms.entries)
                ListTile(title: Text(e.key == 'web' ? '🌐 Weboldal' : e.key == 'android' ? '🤖 Android' : e.key), trailing: _Num(e.value)),
            ]),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile(this.label, this.value, {this.warn = false});

  final String label;
  final String value;
  final bool warn;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            child: Column(children: [
              Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: warn ? Colors.red.shade400 : null)),
              Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
            ]),
          ),
        ),
      );
}

class _Num extends StatelessWidget {
  const _Num(this.value);

  final int? value;

  @override
  Widget build(BuildContext context) => Text('${value ?? 0}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16));
}

class _Users extends StatefulWidget {
  const _Users();

  @override
  State<_Users> createState() => _UsersState();
}

class _UsersState extends State<_Users> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return _Loader<List<UserProfile>>(
      load: Admin.instance.users,
      builder: (context, users, reload) {
        final q = _query.toLowerCase();
        final shown = users.where((u) => q.isEmpty || u.name.toLowerCase().contains(q) || u.email.toLowerCase().contains(q)).toList();
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              decoration: const InputDecoration(hintText: 'Keresés névre vagy e-mailre', prefixIcon: Icon(Icons.search)),
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 8),
            Text('${shown.length} felhasználó', style: TextStyle(color: AppColors.textMuted)),
            for (final u in shown)
              Card(
                child: ListTile(
                  leading: NameAvatar(u.name.isEmpty ? '?' : u.name),
                  title: Text('${u.name.isEmpty ? '(névtelen)' : u.name}${u.banned ? '  ⛔' : ''}',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('${u.email}\nUtoljára: ${_when(u.lastSeen)} • ${u.platform} ${u.version}'),
                  isThreeLine: true,
                  onTap: () async {
                    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => _UserDetail(user: u)));
                    reload();
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

class _UserDetail extends StatefulWidget {
  const _UserDetail({required this.user});

  final UserProfile user;

  @override
  State<_UserDetail> createState() => _UserDetailState();
}

class _UserDetailState extends State<_UserDetail> {
  late bool _banned = widget.user.banned;
  bool _busy = false;

  Future<void> _run(Future<void> Function() action, String done) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(done)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Nem sikerült: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm(String title, String text) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(text),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Mégse')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red.shade400),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Igen'),
            ),
          ],
        ),
      ) ??
      false;

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    return Scaffold(
      appBar: AppBar(title: Text(u.name.isEmpty ? 'Felhasználó' : u.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Column(children: [
              ListTile(title: const Text('E-mail'), subtitle: Text(u.email)),
              ListTile(
                title: const Text('Azonosító (UID)'),
                subtitle: Text(u.uid),
                trailing: IconButton(
                  tooltip: 'Másolás',
                  icon: const Icon(Icons.copy),
                  onPressed: () => Clipboard.setData(ClipboardData(text: u.uid)),
                ),
              ),
              ListTile(title: const Text('Regisztrált'), subtitle: Text(_when(u.createdAt))),
              ListTile(title: const Text('Utoljára aktív'), subtitle: Text(_when(u.lastSeen))),
              ListTile(title: const Text('Eszköz, verzió'), subtitle: Text('${u.platform} • ${u.version}')),
              ListTile(
                title: const Text('Adatai'),
                subtitle: Text('${u.counts['journal'] ?? 0} napló • ${u.counts['habits'] ?? 0} cél • ${u.counts['events'] ?? 0} program'),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text('A napló tartalmát adatvédelmi okból az admin sem látja.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ),
          const SectionTitle('Kezelés'),
          Card(
            child: Column(children: [
              SwitchListTile(
                secondary: const Text('⛔', style: TextStyle(fontSize: 22)),
                title: const Text('Felfüggesztve'),
                subtitle: const Text('Nem tudja használni az appot, amíg vissza nem kapcsolod.'),
                value: _banned,
                onChanged: _busy
                    ? null
                    : (on) => _run(() async {
                          await Admin.instance.setBanned(u.uid, on);
                          setState(() => _banned = on);
                        }, on ? 'Felfüggesztve' : 'Felfüggesztés feloldva'),
              ),
              ListTile(
                leading: Icon(Icons.delete_forever_outlined, color: Colors.red.shade400),
                title: Text('Minden adatának törlése', style: TextStyle(color: Colors.red.shade400)),
                subtitle: const Text('A fiókot a Firebase konzolban (Authentication) lehet törölni.'),
                enabled: !_busy,
                onTap: () async {
                  if (!await _confirm('Törlöd ${u.name} összes adatát?', 'Napló, célok, programok. Nem vonható vissza.')) return;
                  await _run(() => Admin.instance.deleteUserData(u.uid), 'Adatok törölve');
                },
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

class _Errors extends StatelessWidget {
  const _Errors();

  @override
  Widget build(BuildContext context) {
    return _Loader<List<ErrorReport>>(
      load: Admin.instance.errors,
      builder: (context, errors, reload) {
        // Ugyanaz a hiba sokszor jöhet: üzenet szerint csoportosítjuk, a leggyakoribb elöl.
        final groups = <String, List<ErrorReport>>{};
        for (final e in errors) {
          groups.putIfAbsent(e.message, () => []).add(e);
        }
        final sorted = groups.entries.toList()..sort((a, b) => b.value.length.compareTo(a.value.length));
        if (sorted.isEmpty) {
          return ListView(padding: const EdgeInsets.all(16), children: const [EmptyState(emoji: '🎉', text: 'Nincs bejelentett hiba.')]);
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final g in sorted)
              Card(
                child: ExpansionTile(
                  title: Text(g.key, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  subtitle: Text('${g.value.length}× • utoljára ${_when(g.value.first.at)} • '
                      '${{for (final e in g.value) '${e.platform} ${e.version}'}.join(', ')}'),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  children: [
                    SelectableText(g.value.first.stack, style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
                    const SizedBox(height: 8),
                    Row(children: [
                      TextButton.icon(
                        onPressed: () => Clipboard.setData(ClipboardData(text: '${g.key}\n\n${g.value.first.stack}')),
                        icon: const Icon(Icons.copy, size: 18),
                        label: const Text('Másolás'),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () async {
                          await Admin.instance.deleteErrorsLike(g.key);
                          reload();
                        },
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('Javítva, törlés'),
                      ),
                    ]),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _FeedbackList extends StatelessWidget {
  const _FeedbackList();

  @override
  Widget build(BuildContext context) {
    return _Loader<List<UserFeedback>>(
      load: Admin.instance.feedback,
      builder: (context, items, reload) {
        if (items.isEmpty) {
          return ListView(padding: const EdgeInsets.all(16), children: const [EmptyState(emoji: '📭', text: 'Még nincs visszajelzés.')]);
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final f in items)
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${f.done ? '✅ ' : ''}${f.name} • ${f.email}', style: const TextStyle(fontWeight: FontWeight.w800)),
                      Text(_when(f.at), style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                      const SizedBox(height: 6),
                      SelectableText(f.text),
                      Row(children: [
                        const Spacer(),
                        TextButton(
                          onPressed: () async {
                            await Admin.instance.setFeedbackDone(f.id, !f.done);
                            reload();
                          },
                          child: Text(f.done ? 'Újranyitás' : 'Kész'),
                        ),
                        IconButton(
                          tooltip: 'Törlés',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            await Admin.instance.deleteFeedback(f.id);
                            reload();
                          },
                        ),
                      ]),
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

class _SharedEvents extends StatelessWidget {
  const _SharedEvents();

  @override
  Widget build(BuildContext context) {
    return _Loader<List<Map<String, dynamic>>>(
      load: Admin.instance.sharedEvents,
      builder: (context, events, reload) {
        if (events.isEmpty) {
          return ListView(padding: const EdgeInsets.all(16), children: const [EmptyState(emoji: '🔗', text: 'Nincs megosztott program.')]);
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final e in events)
              Card(
                child: ListTile(
                  title: Text(e['title'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('Szervező: ${e['ownerName'] ?? '?'} • ${e['date'] ?? ''}'),
                  trailing: IconButton(
                    tooltip: 'Törlés (moderálás)',
                    icon: Icon(Icons.delete_outline, color: Colors.red.shade400),
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Törlöd a programot?'),
                          content: const Text('A meghívottaknál is megszűnik, az üzenőfalával együtt.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Mégse')),
                            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Törlés')),
                          ],
                        ),
                      );
                      if (ok != true) return;
                      await Admin.instance.deleteSharedEvent(e['id'] as String);
                      reload();
                    },
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Közösségi ötletek moderálása: a jelentettek elöl, a jelentések okával.
class _CommunityIdeas extends StatelessWidget {
  const _CommunityIdeas();

  static Future<(List<CommunityIdea>, Map<String, List<String>>)> _load() async =>
      (await Community.instance.latest(), await Community.instance.reports());

  @override
  Widget build(BuildContext context) {
    return _Loader<(List<CommunityIdea>, Map<String, List<String>>)>(
      load: _load,
      builder: (context, data, reload) {
        final (ideas, reports) = data;
        final sorted = [...ideas]..sort((a, b) => (reports[b.id]?.length ?? 0).compareTo(reports[a.id]?.length ?? 0));
        if (sorted.isEmpty) {
          return ListView(padding: const EdgeInsets.all(16), children: const [EmptyState(emoji: '💡', text: 'Még nincs közösségi ötlet.')]);
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final i in sorted)
              Card(
                color: (reports[i.id]?.isNotEmpty ?? false) ? Colors.red.withValues(alpha: 0.08) : null,
                child: ListTile(
                  leading: Text(i.emoji, style: const TextStyle(fontSize: 26)),
                  title: Text(i.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text([
                    '${i.authorName} · ${i.place.label.isEmpty ? 'hely nélkül' : i.place.label}',
                    if (reports[i.id] != null) '🚩 ${reports[i.id]!.length} jelentés: ${reports[i.id]!.where((r) => r.isNotEmpty).join('; ')}',
                  ].join('\n')),
                  isThreeLine: reports[i.id] != null,
                  trailing: IconButton(
                    tooltip: 'Törlés',
                    icon: Icon(Icons.delete_outline, color: Colors.red.shade400),
                    onPressed: () async {
                      await Community.instance.delete(i.id, asAdmin: true);
                      reload();
                    },
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
