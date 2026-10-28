import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../stats.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/tag_icon.dart';

/// Heti összefoglaló: célok, hangulat, hála, programok; hetek között lapozható.
class WeekSummaryScreen extends StatefulWidget {
  const WeekSummaryScreen({super.key, this.day});

  /// A hét bármelyik napja (alapból a mostani hét).
  final DateTime? day;

  @override
  State<WeekSummaryScreen> createState() => _WeekSummaryScreenState();
}

class _WeekSummaryScreenState extends State<WeekSummaryScreen> {
  late DateTime _day = widget.day ?? DateTime.now();

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final w = WeekSummary(store, _day);
    final isCurrent = dayKey(w.monday) == dayKey(WeekSummary(store, DateTime.now()).monday);
    String fmt(double v) => v.toStringAsFixed(1).replaceAll('.', ',');
    final range = '${DateFormat('MMM d.', 'hu').format(w.monday)} – ${DateFormat('MMM d.', 'hu').format(w.sunday)}';
    final days = [for (var i = 0; i < 7; i++) addDays(w.monday, i)];
    final gratitudes = [
      for (final e in w.entries)
        if (e.gratitude.isNotEmpty) e,
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Heti összefoglaló')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Előző hét',
                icon: const Icon(Icons.chevron_left),
                onPressed: () => setState(() => _day = addDays(w.monday, -7)),
              ),
              Expanded(
                child: Text(range, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
              ),
              IconButton(
                tooltip: 'Következő hét',
                icon: const Icon(Icons.chevron_right),
                onPressed: isCurrent ? null : () => setState(() => _day = addDays(w.monday, 7)),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(w.headline, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
          ),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Stat(value: w.goalPercent == null ? '–' : '${w.goalPercent}%', label: 'cél teljesítve'),
                _Stat(
                  value: w.average == null ? '–' : fmt(w.average!),
                  label: w.average != null && w.previousAverage != null
                      ? 'hangulat (${w.average! >= w.previousAverage! ? '+' : ''}${fmt(w.average! - w.previousAverage!)})'
                      : 'átlagos hangulat',
                ),
                _Stat(value: '${w.entries.length}/7', label: 'napló'),
                _Stat(value: '${w.events}', label: 'program'),
              ],
            ),
          ),

          // Hangulat napról napra
          const SectionTitle('Hangulat'),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  for (final d in days)
                    Column(
                      children: [
                        Text(
                          DateFormat.E('hu').format(d),
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 30,
                          child: switch (store.entryFor(d)) {
                            final e? => EntryFace(e, size: 28),
                            null => Icon(Icons.remove, color: AppColors.divider),
                          },
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),

          // Célok
          if (store.habits.isNotEmpty) ...[
            SectionTitle('Célok', trailing: '${w.goalsDone}/${w.goalsPossible}'),
            Card(
              child: Column(
                children: [
                  for (final h in store.habits)
                    ListTile(
                      title: Text(h.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                        h.isWeekly
                            ? '${days.where(h.isDoneOn).length}/${h.perWeek} ezen a héten'
                            : '${days.where(h.isDoneOn).length}/${w.elapsed} nap',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final d in days)
                            Container(
                              width: 10,
                              height: 10,
                              margin: const EdgeInsets.only(left: 4),
                              decoration: BoxDecoration(
                                color: h.isDoneOn(d) ? AppColors.primary : AppColors.divider,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            if (w.bestGoal != null && w.bestGoalDays > 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
                child: Text(
                  'A legkitartóbb: ${w.bestGoal!.name} (${w.bestGoalDays} nap)',
                  style: TextStyle(color: AppColors.textMuted),
                ),
              ),
          ],

          // Hála
          if (gratitudes.isNotEmpty) ...[
            const SectionTitle('Amiért hálás voltál'),
            Card(
              child: Column(
                children: [
                  for (final e in gratitudes)
                    ListTile(
                      leading: Text(
                        DateFormat.E('hu').format(e.date),
                        style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600),
                      ),
                      title: Text(e.gratitude),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Card(
      margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Column(
          children: [
            FittedBox(
              child: Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
          ],
        ),
      ),
    ),
  );
}
