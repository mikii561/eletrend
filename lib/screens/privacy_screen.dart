import 'package:flutter/material.dart';

import '../availability.dart';
import '../friends.dart';
import '../nudges.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Adatvédelem: ki mit lát rólam, ki hívhat meg, ki bökhet meg, kiket tiltottam le.
class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({super.key});

  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  ({bool off, Set<String> muted})? _nudges;
  late final Stream<Map<String, String>>? _blocked = Friends.instance.ready ? Friends.instance.watchBlocked() : null;

  @override
  void initState() {
    super.initState();
    if (Nudges.instance.ready) {
      Nudges.instance
          .settings()
          .then((s) {
            if (mounted) setState(() => _nudges = s);
          })
          .catchError((_) {});
    }
  }

  Future<void> _setNudgesOff(bool off) async {
    setState(() => _nudges = (off: off, muted: _nudges?.muted ?? {}));
    await Nudges.instance.setOff(off).catchError((Object e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Nem sikerült menteni: $e')));
    });
  }

  Future<void> _mute() async {
    final store = StoreScope.of(context);
    final muted = {...?_nudges?.muted};
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text('Kitől nem kérsz bökést?', style: Theme.of(context).textTheme.titleLarge),
              ),
              for (final f in store.friendsCache)
                SwitchListTile(
                  title: Text(f.name),
                  value: muted.contains(f.uid),
                  onChanged: (on) {
                    setSheet(() => on ? muted.add(f.uid) : muted.remove(f.uid));
                    Nudges.instance.setMuted(f.uid, on).catchError((_) {});
                  },
                ),
            ],
          ),
        ),
      ),
    );
    if (mounted) setState(() => _nudges = (off: _nudges?.off ?? false, muted: muted));
  }

  Future<void> _addWindow() async {
    final store = StoreScope.of(context);
    final window = await showModalBottomSheet<FreeWindow>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _WindowEditor(),
    );
    if (window != null) store.setFreeWindows([...store.freeWindows, window]);
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Adatvédelem')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          Card(
            color: AppColors.primary.withValues(alpha: AppColors.dark ? 0.16 : 0.06),
            child: const ListTile(
              leading: Icon(Icons.shield_outlined),
              title: Text('Mit látnak a barátaid?'),
              subtitle: Text(
                'A neved és a kódod. Ha engeded: mikor vagy foglalt (cím, hely, részletek nélkül), a születésnapod (év nélkül) '
                'és a célsorozataid. A bejegyzéseidet, feladataidat és céljaidat senki más nem látja.',
              ),
            ),
          ),
          const SectionTitle('Elérhetőségem'),
          Card(
            child: RadioGroup<AvailabilityShare>(
              groupValue: store.shareAvailability,
              onChanged: (v) => store.setPrivacy(shareAvailability: v),
              child: Column(
                children: [
                  for (final s in AvailabilityShare.values)
                    RadioListTile<AvailabilityShare>(
                      value: s,
                      title: Text(s.label),
                      subtitle: s == AvailabilityShare.nobody
                          ? const Text('A közös időpont keresésénél „nem tudjuk” leszel.')
                          : null,
                    ),
                  if (store.shareAvailability == AvailabilityShare.groups)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: store.groups.isEmpty
                          ? Text(
                              'Még nincs csoportod. A Barátok fülön hozhatsz létre.',
                              style: TextStyle(color: AppColors.textMuted),
                            )
                          : Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                for (final g in store.groups)
                                  FilterChip(
                                    label: Text(g.name),
                                    selected: store.shareGroups.contains(g.id),
                                    onSelected: (on) => store.setPrivacy(
                                      shareGroups: on
                                          ? {...store.shareGroups, g.id}
                                          : ({...store.shareGroups}..remove(g.id)),
                                    ),
                                  ),
                              ],
                            ),
                    ),
                ],
              ),
            ),
          ),
          const SectionTitle('Mikor szoktam ráérni?'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'A közös időpont keresése ezekben a sávokban ajánl. Ha egyet sem jelölsz, reggel 8 és este 11 között bármikor.',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final p in freeWindowPresets)
                        FilterChip(
                          label: Text(p.label),
                          selected: store.freeWindows.contains(p.window),
                          onSelected: (on) => store.setFreeWindows(
                            on
                                ? [...store.freeWindows, p.window]
                                : store.freeWindows.where((w) => w != p.window).toList(),
                          ),
                        ),
                      for (final w in store.freeWindows)
                        if (!freeWindowPresets.any((p) => p.window == w))
                          InputChip(
                            label: Text(windowLabel(w)),
                            onDeleted: () => store.setFreeWindows(store.freeWindows.where((x) => x != w).toList()),
                          ),
                      ActionChip(
                        avatar: const Icon(Icons.add, size: 18),
                        label: const Text('Saját sáv'),
                        onPressed: _addWindow,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SectionTitle('Meghívások és bökések'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('A barátaim meghívhatnak programokra'),
                  subtitle: const Text('Kikapcsolva csak meghívólinket küldhetnek.'),
                  value: store.allowInvites,
                  onChanged: (v) => store.setPrivacy(allowInvites: v),
                ),
                SwitchListTile(
                  title: const Text('Bökések fogadása'),
                  subtitle: Text('Egy barát naponta legfeljebb ${Nudges.dailyLimit}-at küldhet.'),
                  value: !(_nudges?.off ?? false),
                  onChanged: Nudges.instance.ready && _nudges != null ? (v) => _setNudgesOff(!v) : null,
                ),
                if (_nudges != null && !_nudges!.off && store.friendsCache.isNotEmpty)
                  ListTile(
                    title: const Text('Némítás barátonként'),
                    subtitle: Text(_nudges!.muted.isEmpty ? 'Senki' : _nudges!.muted.map(store.nameOf).join(', ')),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _mute,
                  ),
              ],
            ),
          ),
          const SectionTitle('Névjegyem'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Születésnapom (év nélkül)'),
                  subtitle: Text(
                    store.birthday == null ? 'Előbb add meg a Profilban.' : 'A barátaid emlékeztetőt kaphatnak.',
                  ),
                  value: store.shareBirthday,
                  onChanged: store.birthday == null ? null : (v) => store.setPrivacy(shareBirthday: v),
                ),
                SwitchListTile(
                  title: const Text('Célsorozataim'),
                  subtitle: const Text('Pl. „Edzés · 4 hét”. Maguk a célok és a napjaid nem.'),
                  value: store.shareStreaks,
                  onChanged: (v) => store.setPrivacy(shareStreaks: v),
                ),
              ],
            ),
          ),
          const SectionTitle('Letiltott felhasználók'),
          StreamBuilder<Map<String, String>>(
            stream: _blocked,
            builder: (context, snap) {
              final blocked = snap.data ?? const {};
              if (blocked.isEmpty) {
                return Card(
                  child: ListTile(
                    title: Text('Senkit nem tiltottál le.', style: TextStyle(color: AppColors.textMuted)),
                  ),
                );
              }
              return Card(
                child: Column(
                  children: [
                    for (final e in blocked.entries)
                      ListTile(
                        leading: NameAvatar(e.value),
                        title: Text(e.value),
                        trailing: TextButton(
                          onPressed: () => Friends.instance.unblock(e.key),
                          child: const Text('Feloldás'),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Egy saját sáv kiírása, pl. „H, Sze, P 18:00–21:00”.
String windowLabel(FreeWindow w) {
  const names = ['H', 'K', 'Sze', 'Cs', 'P', 'Szo', 'V'];
  final days = (w.days.toList()..sort()).map((d) => names[d - 1]).join(', ');
  String t(int m) => '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
  return '$days ${t(w.fromMin)}–${t(w.toMin)}';
}

class _WindowEditor extends StatefulWidget {
  const _WindowEditor();

  @override
  State<_WindowEditor> createState() => _WindowEditorState();
}

class _WindowEditorState extends State<_WindowEditor> {
  final Set<int> _days = {1, 2, 3, 4, 5};
  TimeOfDay _from = const TimeOfDay(hour: 18, minute: 0);
  TimeOfDay _to = const TimeOfDay(hour: 21, minute: 0);
  String? _error;

  @override
  Widget build(BuildContext context) {
    const names = ['H', 'K', 'Sze', 'Cs', 'P', 'Szo', 'V'];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Saját sáv', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              children: [
                for (var d = 1; d <= 7; d++)
                  FilterChip(
                    label: Text(names[d - 1]),
                    selected: _days.contains(d),
                    onSelected: (on) => setState(() => on ? _days.add(d) : _days.remove(d)),
                  ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    title: Text(_from.format(context)),
                    subtitle: const Text('Ettől'),
                    onTap: () async {
                      final t = await showTimePicker(context: context, initialTime: _from);
                      if (t != null) setState(() => _from = t);
                    },
                  ),
                ),
                Expanded(
                  child: ListTile(
                    title: Text(_to.format(context)),
                    subtitle: const Text('Eddig'),
                    onTap: () async {
                      final t = await showTimePicker(context: context, initialTime: _to);
                      if (t != null) setState(() => _to = t);
                    },
                  ),
                ),
              ],
            ),
            if (_error != null) Text(_error!, style: TextStyle(color: AppColors.danger)),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                final from = _from.hour * 60 + _from.minute, to = _to.hour * 60 + _to.minute;
                if (_days.isEmpty || to <= from) {
                  setState(
                    () => _error = _days.isEmpty
                        ? 'Válassz legalább egy napot.'
                        : 'A vége legyen később, mint a kezdete.',
                  );
                  return;
                }
                Navigator.pop(context, FreeWindow(days: {..._days}, fromMin: from, toMin: to));
              },
              child: const Text('Hozzáadás'),
            ),
          ],
        ),
      ),
    );
  }
}
