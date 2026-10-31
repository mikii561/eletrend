import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../admin.dart';
import '../availability.dart' show AvailabilityStatus;
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/motion.dart';

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
              Tab(text: 'Jelentések'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_Overview(), _Users(), _Errors(), _FeedbackList(), _SharedEvents(), _Reports()],
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
              EmptyState(
                emoji: '⚠️',
                text: 'Nem sikerült betölteni.\n${snap.error}',
                action: 'Újra',
                onAction: _reload,
              ),
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

class _Overview extends StatefulWidget {
  const _Overview();

  @override
  State<_Overview> createState() => _OverviewState();
}

class _OverviewState extends State<_Overview> {
  StatRange _range = StatRange.week;

  @override
  Widget build(BuildContext context) {
    return _Loader<AdminStats>(
      load: Admin.instance.stats,
      builder: (context, s, _) {
        TrendSeries series(TrendKind k) => s.trends.of(k, _range);
        final newUsers = series(TrendKind.newUsers);
        final active = series(TrendKind.active);
        final errors = series(TrendKind.errors);
        final feedback = series(TrendKind.feedback);
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SegmentedButton<StatRange>(
              showSelectedIcon: false,
              segments: [for (final r in StatRange.values) ButtonSegment(value: r, label: Text(r.label))],
              selected: {_range},
              onSelectionChanged: (v) => setState(() => _range = v.first),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 2),
              child: Text(
                'A változás az előző ${_range.previousLabel} képest.',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _Tile('Felhasználó', '${s.total}', delta: newUsers.total, goodWhenUp: true),
                const SizedBox(width: 8),
                _Tile('Aktív', '${active.total}', delta: active.delta, goodWhenUp: true),
                const SizedBox(width: 8),
                _Tile('Új', '${newUsers.total}', delta: newUsers.delta, goodWhenUp: true),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _Tile('Hiba', '${errors.total}', delta: errors.delta, goodWhenUp: false),
                const SizedBox(width: 8),
                _Tile('Visszajelzés', '${feedback.total}', delta: feedback.delta, goodWhenUp: true),
                const SizedBox(width: 8),
                _Tile('Nyitott visszajelzés', '${s.openFeedback}'),
              ],
            ),
            const SectionTitle('Alakulás'),
            _ChartCard('Új felhasználók', newUsers, _range),
            _ChartCard('Aktív felhasználók', active, _range),
            _ChartCard('Hibák száma', errors, _range, goodWhenUp: false, color: AppColors.danger),
            _ChartCard('Beérkezett visszajelzések', feedback, _range),
            const SectionTitle('Tartalom összesen'),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const IconTile(Icons.checklist),
                    title: const Text('Feladat'),
                    trailing: _Num(s.totals['tasks']),
                  ),
                  ListTile(
                    leading: const IconTile(Icons.task_alt),
                    title: const Text('Cél'),
                    trailing: _Num(s.totals['habits']),
                  ),
                  ListTile(
                    leading: const IconTile(Icons.celebration_outlined),
                    title: const Text('Naptárbejegyzés'),
                    trailing: _Num(s.totals['events']),
                  ),
                  ListTile(
                    leading: const IconTile(Icons.link),
                    title: const Text('Megosztott program'),
                    trailing: _Num(s.sharedEvents),
                  ),
                ],
              ),
            ),
            const SectionTitle('Platformok'),
            Card(
              child: Column(
                children: [
                  for (final e in s.platforms.entries)
                    ListTile(
                      title: Text(
                        e.key == 'web'
                            ? '🌐 Weboldal'
                            : e.key == 'android'
                            ? '🤖 Android'
                            : e.key,
                      ),
                      trailing: _Num(e.value),
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

/// „+3” zölden, „-2” pirosan; a hibáknál fordítva (a több a rossz). Nullánál szürke „±0”.
class _Delta extends StatelessWidget {
  const _Delta(this.delta, {required this.goodWhenUp, this.fontSize = 12});

  final int delta;
  final bool goodWhenUp;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final good = AppColors.status(AvailabilityStatus.available);
    final bad = AppColors.danger;
    final color = delta == 0 ? AppColors.textMuted : ((delta > 0) == goodWhenUp ? good : bad);
    return Text(
      delta == 0 ? '±0' : (delta > 0 ? '+$delta' : '$delta'),
      style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w800, color: color),
    );
  }
}

/// Egy mutató kártyája: az összeg, a változás és az oszlopdiagram.
class _ChartCard extends StatelessWidget {
  const _ChartCard(this.title, this.series, this.range, {this.goodWhenUp = true, this.color});

  final String title;
  final TrendSeries series;
  final StatRange range;
  final bool goodWhenUp;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                Text('${series.total}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                const SizedBox(width: 8),
                _Delta(series.delta, goodWhenUp: goodWhenUp, fontSize: 14),
              ],
            ),
            const SizedBox(height: 10),
            _BarChart(series, range, color: color ?? AppColors.primary),
          ],
        ),
      ),
    );
  }
}

class _BarChart extends StatelessWidget {
  const _BarChart(this.series, this.range, {required this.color});

  final TrendSeries series;
  final StatRange range;
  final Color color;

  static const _height = 96.0;

  String _label(DateTime d) => range.monthly ? DateFormat.MMM('hu').format(d) : DateFormat('M. d.', 'hu').format(d);

  @override
  Widget build(BuildContext context) {
    final max = series.counts.fold(0, (a, b) => a > b ? a : b);
    final n = series.counts.length;
    final muted = TextStyle(fontSize: 10, color: AppColors.textMuted);
    return Column(
      children: [
        SizedBox(
          height: _height,
          child: Stack(
            children: [
              for (final f in [0.0, 0.5, 1.0])
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: f * (_height - 1),
                  child: Divider(height: 1, color: AppColors.divider),
                ),
              Positioned(left: 0, top: 0, child: Text(max == 0 ? '' : '$max', style: muted)),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < n; i++)
                    Expanded(
                      child: Tooltip(
                        message: '${_label(series.starts[i])}: ${series.counts[i]}',
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: n > 20 ? 1 : 3),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(end: max == 0 ? 0 : series.counts[i] / max),
                            duration: Motion.of(context, Motion.slow),
                            curve: Motion.curve,
                            builder: (context, v, _) => FractionallySizedBox(
                              alignment: Alignment.bottomCenter,
                              heightFactor: series.counts[i] == 0 ? 0 : v.clamp(0.03, 1.0),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                                ),
                                child: const SizedBox(width: double.infinity),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_label(series.starts.first), style: muted),
            if (n > 7) Text(_label(series.starts[n ~/ 2]), style: muted),
            Text(_label(series.starts.last), style: muted),
          ],
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile(this.label, this.value, {this.delta, this.goodWhenUp = true});

  final String label;
  final String value;

  /// Változás az előző időszakhoz képest (nincs → nem látszik).
  final int? delta;
  final bool goodWhenUp;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Column(
          children: [
            Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
            if (delta != null) _Delta(delta!, goodWhenUp: goodWhenUp) else const SizedBox(height: 15),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Num extends StatelessWidget {
  const _Num(this.value);

  final int? value;

  @override
  Widget build(BuildContext context) =>
      Text('${value ?? 0}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16));
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
        final shown = users
            .where((u) => q.isEmpty || u.name.toLowerCase().contains(q) || u.email.toLowerCase().contains(q))
            .toList();
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              decoration: const InputDecoration(
                hintText: 'Keresés névre vagy e-mailre',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 8),
            Text('${shown.length} felhasználó', style: TextStyle(color: AppColors.textMuted)),
            for (final u in shown)
              Card(
                child: ListTile(
                  leading: NameAvatar(u.name.isEmpty ? '?' : u.name),
                  title: Text(
                    '${u.name.isEmpty ? '(névtelen)' : u.name}${u.banned ? '  ⛔' : ''}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
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
            child: Column(
              children: [
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
                  subtitle: Text(
                    '${u.counts['events'] ?? 0} bejegyzés • ${u.counts['tasks'] ?? 0} feladat • ${u.counts['habits'] ?? 0} cél',
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              'A bejegyzések, feladatok tartalmát adatvédelmi okból az admin sem látja.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ),
          const SectionTitle('Kezelés'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const IconTile(Icons.block),
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
                    final ok = await _confirm(
                      'Törlöd ${u.name} összes adatát?',
                      'Naptár, feladatok, célok. Nem vonható vissza.',
                    );
                    if (!ok) return;
                    await _run(() => Admin.instance.deleteUserData(u.uid), 'Adatok törölve');
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
          return ListView(
            padding: const EdgeInsets.all(16),
            children: const [EmptyState(emoji: '🎉', text: 'Nincs bejelentett hiba.')],
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final g in sorted)
              Card(
                child: ExpansionTile(
                  title: Text(
                    g.key,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  subtitle: Text(
                    '${g.value.length}× • utoljára ${_when(g.value.first.at)} • '
                    '${{for (final e in g.value) '${e.platform} ${e.version}'}.join(', ')}',
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  children: [
                    SelectableText(g.value.first.stack, style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
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
                      ],
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

class _FeedbackList extends StatelessWidget {
  const _FeedbackList();

  @override
  Widget build(BuildContext context) {
    return _Loader<List<UserFeedback>>(
      load: Admin.instance.feedback,
      builder: (context, items, reload) {
        if (items.isEmpty) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: const [EmptyState(emoji: '📭', text: 'Még nincs visszajelzés.')],
          );
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
                      Text(
                        '${f.done ? '✅ ' : ''}${f.name} • ${f.email}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text(_when(f.at), style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                      const SizedBox(height: 6),
                      SelectableText(f.text),
                      if (f.images.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final (i, image) in f.images.indexed)
                              Semantics(
                                button: true,
                                label: '${i + 1}. képernyőkép megnyitása',
                                child: GestureDetector(
                                  onTap: () => _showScreenshot(context, base64Decode(image)),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.memory(base64Decode(image), width: 96, height: 96, fit: BoxFit.cover),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                      Row(
                        children: [
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

class _SharedEvents extends StatelessWidget {
  const _SharedEvents();

  @override
  Widget build(BuildContext context) {
    return _Loader<List<Map<String, dynamic>>>(
      load: Admin.instance.sharedEvents,
      builder: (context, events, reload) {
        if (events.isEmpty) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: const [EmptyState(emoji: '🔗', text: 'Nincs megosztott program.')],
          );
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

/// Felhasználói jelentések: kiről vagy melyik programról, miért. Innen lehet felfüggeszteni
/// (a Felhasználók fülön) vagy a programot törölni (a Programok fülön).
class _Reports extends StatelessWidget {
  const _Reports();

  @override
  Widget build(BuildContext context) {
    return _Loader<List<UserReport>>(
      load: Admin.instance.reports,
      builder: (context, reports, reload) {
        if (reports.isEmpty) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: const [EmptyState(emoji: '🚩', text: 'Nincs jelentés.')],
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final r in reports)
              Card(
                child: ListTile(
                  leading: const IconTile(Icons.flag_outlined),
                  title: Text(r.reason.isEmpty ? '(indoklás nélkül)' : r.reason),
                  subtitle: SelectableText(
                    [
                      if (r.userUid != null) 'Felhasználó: ${r.userUid}',
                      if (r.eventId != null) 'Program: ${r.eventId}',
                      'Bejelentő: ${r.reporterUid} • ${_when(r.at)}',
                    ].join('\n'),
                  ),
                  trailing: IconButton(
                    tooltip: 'Kezelve (törlés)',
                    icon: const Icon(Icons.done),
                    onPressed: () async {
                      await Admin.instance.deleteReport(r.id);
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

/// Egy csatolt képernyőkép nagyban (nagyítható).
Future<void> _showScreenshot(BuildContext context, Uint8List bytes) => showDialog<void>(
  context: context,
  builder: (context) => Dialog(
    insetPadding: const EdgeInsets.all(12),
    child: Stack(
      children: [
        InteractiveViewer(maxScale: 5, child: Image.memory(bytes, fit: BoxFit.contain)),
        Positioned(
          right: 4,
          top: 4,
          child: IconButton.filledTonal(
            tooltip: 'Bezárás',
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ],
    ),
  ),
);
