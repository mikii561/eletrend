import 'package:flutter/material.dart';

import '../account.dart';
import '../models.dart';
import '../push.dart';
import '../screens/journal_screen.dart';
import '../screens/pin_screen.dart';
import '../screens/week_summary_screen.dart';
import '../stats.dart';
import '../store.dart';
import '../theme.dart';
import 'common.dart';

/// A Ma képernyő tetején: esti napló-emlékeztető és a heti összefoglaló.
/// Böngészőben ezek helyettesítik az értesítéseket, telefonon kiegészítik.
class TodayNudges extends StatelessWidget {
  const TodayNudges({super.key, this.now});

  /// Csak tesztekhez.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final now = this.now ?? DateTime.now();
    final minutes = now.hour * 60 + now.minute;
    final t = store.reminderTime;

    // Este, a beállított időpont után, ha még nincs mai bejegyzés.
    final journalDue = store.dailyReminder && minutes >= t.hour * 60 + t.minute && store.entryFor(now) == null;

    // Vasárnap délutántól hétfő estig, ha még nem zárta be.
    final showWeek =
        store.weeklySummary && (now.weekday == DateTime.sunday && now.hour >= 17 || now.weekday == DateTime.monday);
    final week = WeekSummary(store, now.weekday == DateTime.monday ? addDays(now, -1) : now);
    final weekKey = dayKey(week.monday);
    final weekDue = showWeek && !week.isEmpty && store.weekCardClosed != weekKey;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const InstallAndPushCard(),
        if (journalDue)
          Card(
            child: ListTile(
              leading: const IconTile(Icons.nightlight_outlined),
              title: const Text('Este van: írd meg a mai naplót'),
              subtitle: const Text('Egy perc az egész: hangulat és egy dolog, amiért hálás vagy.'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                if (!await JournalLock.ensureUnlocked(context) || !context.mounted) return;
                await Navigator.of(context).push(MaterialPageRoute(builder: (_) => JournalEditor(date: now)));
              },
            ),
          ),
        if (weekDue)
          Card(
            child: ListTile(
              leading: IconTile(Icons.insights_outlined, color: AppColors.accent),
              title: const Text('Így ment a heted'),
              subtitle: Text(
                [
                  if (week.goalPercent != null) '${week.goalPercent}% cél',
                  '${week.entries.length}/7 napló',
                  week.headline,
                ].join(' · '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: IconButton(
                tooltip: 'Bezárás',
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => store.closeWeekCard(weekKey),
              ),
              onTap: () =>
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => WeekSummaryScreen(day: week.monday))),
            ),
          ),
      ],
    );
  }
}

/// Böngészőben: „Tedd a kezdőképernyőre” (iPhone), utána „Kapcsold be az értesítéseket”.
class InstallAndPushCard extends StatefulWidget {
  const InstallAndPushCard({super.key});

  @override
  State<InstallAndPushCard> createState() => _InstallAndPushCardState();
}

class _InstallAndPushCardState extends State<InstallAndPushCard> {
  bool _busy = false;
  String? _message;

  Future<void> _enable() async {
    final uid = Account.instance.user?.uid;
    if (uid == null) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final ok = await Push.register(uid, ask: true);
      if (!mounted) return;
      setState(
        () => _message = ok
            ? null
            : Push.permission == 'denied'
            ? 'Le vannak tiltva. A telefon Beállítások → Értesítések menüjében engedélyezheted.'
            : 'Nem sikerült bekapcsolni. Próbáld újra.',
      );
    } catch (e) {
      if (mounted) setState(() => _message = 'Nem sikerült bekapcsolni: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    if (Push.needsInstall && !store.hintClosed('install')) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const IconTile(Icons.add_to_home_screen),
                  const SizedBox(width: 12),
                  Expanded(child: Text('Tedd a kezdőképernyőre', style: Theme.of(context).textTheme.titleMedium)),
                  IconButton(
                    tooltip: 'Bezárás',
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => store.closeHint('install'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Így saját ikonnal, teljes képernyőn indul, internet nélkül is megnyílik, '
                'és értesítést is kaphatsz a bumpokról, meghívókról.',
                style: TextStyle(color: AppColors.textMuted),
              ),
              const SizedBox(height: 10),
              const _Step(n: 1, text: 'Koppints a Megosztás gombra (négyzet felfelé nyíllal).'),
              const _Step(n: 2, text: 'Válaszd: „Főképernyőhöz adás”.'),
              const _Step(n: 3, text: 'Nyisd meg az Életrendet az új ikonról.'),
            ],
          ),
        ),
      );
    }
    if (Push.configured && Push.supported && Push.permission == 'default' && !store.hintClosed('push')) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const IconTile(Icons.notifications_active_outlined),
                  const SizedBox(width: 12),
                  Expanded(child: Text('Értesítések bekapcsolása', style: Theme.of(context).textTheme.titleMedium)),
                  IconButton(
                    tooltip: 'Bezárás',
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => store.closeHint('push'),
                  ),
                ],
              ),
              Text(
                'Bumpok, meghívók, üzenetek, esti emlékeztető és heti összefoglaló, akkor is, ha az app be van zárva.',
                style: TextStyle(color: AppColors.textMuted),
              ),
              if (_message != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(_message!, style: TextStyle(color: Colors.red.shade400)),
                ),
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8, right: 8),
                  child: FilledButton(
                    style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                    onPressed: _busy ? null : _enable,
                    child: Text(_busy ? 'Bekapcsolás…' : 'Bekapcsolom'),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.n, required this.text});

  final int n;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 10,
          backgroundColor: AppColors.primary.withValues(alpha: 0.12),
          child: Text(
            '$n',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    ),
  );
}
