import 'package:flutter/material.dart';

import '../formatting.dart';
import '../google_calendar.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Google Naptár összekapcsolása: egy gomb → a Google engedélyező ablaka → naptárak kiválasztása → kész.
class GoogleCalendarScreen extends StatefulWidget {
  const GoogleCalendarScreen({super.key});

  @override
  State<GoogleCalendarScreen> createState() => _GoogleCalendarScreenState();
}

class _GoogleCalendarScreenState extends State<GoogleCalendarScreen> {
  bool _busy = false;
  String? _error;

  /// Az engedélyezés után: a választható naptárak (null, amíg nem választ).
  List<GoogleCalendarInfo>? _choices;
  final Set<String> _picked = {};

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on GoogleCalendarException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Valami hiba történt: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 1. lépés: a Google ablaka, aztán a naptárak listája.
  Future<void> _connect() => _run(() async {
        await GoogleCalendar.instance.connect();
        final list = await GoogleCalendar.instance.calendars();
        if (!mounted) return;
        final store = StoreScope.of(context);
        setState(() {
          _choices = list;
          _picked
            ..clear()
            ..addAll(store.googleConnected ? store.googleCalendars.keys : list.where((c) => c.primary).map((c) => c.id));
        });
      });

  /// 2. lépés: a kiválasztott naptárak eseményei bekerülnek.
  Future<void> _save() => _run(() async {
        final store = StoreScope.of(context);
        final messenger = ScaffoldMessenger.of(context);
        store.setGoogleCalendars(
          {for (final c in _choices!) if (_picked.contains(c.id)) c.id: c.name},
          email: GoogleCalendar.instance.email,
        );
        final n = await syncGoogleCalendars(store);
        if (!mounted) return;
        setState(() => _choices = null);
        messenger.showSnackBar(SnackBar(content: Text('Kész! $n esemény került át a Google Naptárból.')));
      });

  /// Frissítés: ha lejárt a hozzáférés, előbb újra a Google ablaka (egy koppintás).
  Future<void> _refresh() => _run(() async {
        final store = StoreScope.of(context);
        final messenger = ScaffoldMessenger.of(context);
        if (!GoogleCalendar.instance.hasAccess) await GoogleCalendar.instance.connect();
        final n = await syncGoogleCalendars(store);
        messenger.showSnackBar(SnackBar(content: Text('Frissítve: $n esemény.')));
      });

  Future<void> _disconnect() async {
    final store = StoreScope.of(context);
    final ok = await confirm(
      context,
      title: 'Leválasztod a Google Naptárt?',
      text: 'A Google-ből jött események lekerülnek innen. A Google Naptáradban minden megmarad.',
      action: 'Leválasztás',
      danger: true,
    );
    if (!ok) return;
    GoogleCalendar.instance.disconnect();
    store.disconnectGoogle();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final choices = _choices;
    return Scaffold(
      appBar: AppBar(title: const Text('Google Naptár')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          if (choices != null)
            ..._chooser(choices)
          else if (!store.googleConnected)
            ..._intro()
          else
            ..._connected(store),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_error!, style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600)),
            ),
          if (_busy) const LoadingState(),
        ],
      ),
    );
  }

  List<Widget> _intro() => [
        const SizedBox(height: 16),
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: AppColors.card, shape: BoxShape.circle, border: Border.all(color: AppColors.divider)),
            child: Icon(Icons.calendar_month, size: 36, color: AppColors.primary),
          ),
        ),
        const SizedBox(height: 16),
        Text('Hozd át a Google Naptáradat', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          'Az eseményeid itt is megjelennek, a naptárban és a Főoldalon. A barátaid csak annyit látnak belőlük, '
          'hogy foglalt vagy (ha megosztod), a részleteket nem.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textMuted),
        ),
        const SizedBox(height: 24),
        for (final (n, text) in [
          (1, 'Koppints a gombra: megnyílik a Google ablaka.'),
          (2, 'Válaszd ki a Google-fiókodat, és engedélyezd a naptár megtekintését.'),
          (3, 'Pipáld be, melyik naptáraid jöjjenek át. Kész!'),
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                  child: Text('$n', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(text)),
              ],
            ),
          ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _busy ? null : _connect,
          icon: const Icon(Icons.add_link),
          label: const Text('Google Naptár hozzáadása'),
        ),
        const SizedBox(height: 8),
        Text(
          'Csak olvassuk: a Google Naptáradba semmit nem írunk, és bármikor leválaszthatod.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
      ];

  List<Widget> _chooser(List<GoogleCalendarInfo> choices) => [
        const SizedBox(height: 8),
        Text('Melyik naptáraid jöjjenek át?', style: Theme.of(context).textTheme.titleLarge),
        if (GoogleCalendar.instance.email != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(GoogleCalendar.instance.email!, style: TextStyle(color: AppColors.textMuted)),
          ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              if (choices.isEmpty) const ListTile(title: Text('Ebben a Google-fiókban nincs naptár.')),
              for (final c in choices)
                CheckboxListTile(
                  secondary: CategoryDot(c.color != null ? Color(c.color!) : AppColors.primary, size: 14),
                  title: Text(c.primary ? '${c.name} (fő naptár)' : c.name),
                  value: _picked.contains(c.id),
                  onChanged: (on) => setState(() => on == true ? _picked.add(c.id) : _picked.remove(c.id)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _busy || _picked.isEmpty ? null : _save,
          child: Text(_picked.isEmpty ? 'Válassz legalább egy naptárt' : 'Hozzáadás (${_picked.length})'),
        ),
        TextButton(onPressed: _busy ? null : () => setState(() => _choices = null), child: const Text('Mégse')),
      ];

  List<Widget> _connected(AppStore store) {
    final synced = store.googleSyncedAt;
    final count = store.events.where((e) => e.source?.startsWith('google:') ?? false).length;
    return [
      Card(
        child: ListTile(
          leading: Icon(Icons.check_circle, color: AppColors.status(AvailabilityStatus.available)),
          title: const Text('Összekapcsolva', style: TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text([
            ?store.googleEmail,
            '$count esemény',
            if (synced != null) 'frissítve: ${formatDay(synced)} ${formatTime(synced)}',
          ].join(' · ')),
        ),
      ),
      const SectionTitle('Naptárak'),
      Card(
        child: Column(
          children: [
            for (final name in store.googleCalendars.values) ListTile(leading: const Icon(Icons.calendar_today_outlined), title: Text(name)),
            ListTile(
              leading: Icon(Icons.tune, color: AppColors.primary),
              title: Text('Naptárak módosítása', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
              onTap: _busy ? null : _connect,
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      FilledButton.icon(
        onPressed: _busy ? null : _refresh,
        icon: const Icon(Icons.sync),
        label: const Text('Frissítés most'),
      ),
      const SizedBox(height: 4),
      Text(
        'Ha egy ideje nem frissült, a gomb egy koppintással újra engedélyt kér a Google-től (biztonsági okból '
        'a hozzáférés kb. egy óráig érvényes).',
        style: TextStyle(color: AppColors.textMuted, fontSize: 12),
      ),
      const SizedBox(height: 16),
      TextButton.icon(
        onPressed: _busy ? null : _disconnect,
        icon: Icon(Icons.link_off, color: AppColors.danger),
        label: Text('Leválasztás', style: TextStyle(color: AppColors.danger)),
      ),
    ];
  }
}

