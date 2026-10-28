import 'package:flutter/material.dart';

import '../models.dart';
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
              leading: const IconTile(Icons.insights_outlined, color: AppColors.accent),
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
