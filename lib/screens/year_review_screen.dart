import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../photos.dart';
import '../stats.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/tag_icon.dart';

/// Év végi visszatekintés.
class YearReviewScreen extends StatelessWidget {
  const YearReviewScreen({super.key, required this.year});

  final int year;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final r = YearReview(store, year);
    String fmt(double v) => v.toStringAsFixed(1).replaceAll('.', ',');
    final hasYearBefore = store.journal.any((e) => e.date.year == year - 1);

    return Scaffold(
      appBar: AppBar(
        title: Text('$year visszatekintés'),
        actions: [
          if (hasYearBefore)
            IconButton(
              tooltip: '${year - 1}',
              icon: const Icon(Icons.chevron_left),
              onPressed: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => YearReviewScreen(year: year - 1)),
              ),
            ),
        ],
      ),
      body: r.isEmpty
          ? const Padding(padding: EdgeInsets.all(16), child: EmptyState(emoji: '📖', text: 'Ebben az évben még nincs bejegyzésed.'))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              children: [
                // Fejléc
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(gradient: AppColors.headerGradient, borderRadius: BorderRadius.circular(24)),
                  child: Column(
                    children: [
                      Text('$year', style: const TextStyle(color: Colors.white, fontSize: 44, fontWeight: FontWeight.w900)),
                      Text('${r.entries.length} napot írtál le', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(
                        [
                          if (r.average != null) 'átlagos hangulat ${fmt(r.average!)}',
                          if (r.longestStreak >= 3) 'leghosszabb sorozat ${r.longestStreak} nap',
                        ].join(' · '),
                        style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(children: [
                  _Big('🙏', '${r.gratitudes}', 'hála'),
                  _Big('🎉', '${r.events}', 'program'),
                  _Big('📸', '${r.photos.length}', 'fotó'),
                ]),

                // Hónapok
                const SectionTitle('Hónapról hónapra'),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
                    child: SizedBox(
                      height: 130,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          for (var m = 1; m <= 12; m++)
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  if (m == r.bestMonth) const Text('⭐', style: TextStyle(fontSize: 12)),
                                  Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 3),
                                    height: r.monthAverages[m - 1] == null ? 4 : 16 + r.monthAverages[m - 1]! * 18,
                                    decoration: BoxDecoration(
                                      color: r.monthAverages[m - 1] == null
                                          ? AppColors.divider
                                          : AppColors.moods[r.monthAverages[m - 1]!.round() - 1],
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(DateFormat.MMM('hu').format(DateTime(year, m)).substring(0, 3),
                                      style: TextStyle(fontSize: 9, color: AppColors.textMuted)),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (r.bestMonth != null)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      '⭐ A legjobb hónapod: ${DateFormat.MMMM('hu').format(DateTime(year, r.bestMonth!))} '
                      '(átlag ${fmt(r.monthAverages[r.bestMonth! - 1]!)})',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),

                // Szokások
                if (r.habitDays.isNotEmpty) ...[
                  const SectionTitle('A legerősebb szokásaid'),
                  Card(
                    child: Column(children: [
                      for (final (h, days) in r.habitDays.take(5))
                        ListTile(
                          title: Text(h.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                          trailing: Text('$days nap', style: const TextStyle(fontWeight: FontWeight.w800)),
                        ),
                    ]),
                  ),
                ],

                // Érzések
                if (r.topTags.isNotEmpty) ...[
                  const SectionTitle('Amit a legtöbbször éreztél'),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final t in r.topTags)
                        Chip(label: TagLabel(store.tagFor(t.key), style: const TextStyle(fontWeight: FontWeight.w700)), avatar: null),
                    ],
                  ),
                ],

                // Legjobb napok
                if (r.bestDays.isNotEmpty) ...[
                  const SectionTitle('A legszebb napjaid'),
                  for (final e in r.bestDays)
                    Card(
                      child: ListTile(
                        leading: EntryFace(e, size: 34),
                        title: Text(DateFormat('MMMM d.', 'hu').format(e.date), style: const TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: Text(e.gratitude.isNotEmpty ? '🙏 ${e.gratitude}' : e.note, maxLines: 2, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                ],

                // Fotók
                if (r.photos.isNotEmpty) ...[
                  const SectionTitle('Az év képekben'),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 4,
                    mainAxisSpacing: 4,
                    crossAxisSpacing: 4,
                    children: [
                      for (final e in r.photos.take(40))
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: e.photoPath != null && !kIsWeb
                              ? Image.file(File(e.photoPath!), fit: BoxFit.cover, cacheWidth: 200,
                                  errorBuilder: (_, _, _) => EntryFace(e, size: 80))
                              : Image.memory(TagImages.decode(e.moodImage!), fit: BoxFit.cover, gaplessPlayback: true),
                        ),
                    ],
                  ),
                ],
              ],
            ),
    );
  }
}

class _Big extends StatelessWidget {
  const _Big(this.emoji, this.value, this.label);

  final String emoji;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(children: [
              Text(emoji, style: const TextStyle(fontSize: 22)),
              Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              Text(label, style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            ]),
          ),
        ),
      );
}
