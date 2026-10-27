import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../stats.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'journal_screen.dart';

/// Hangulat-statisztika: havi naptár, 30 napos trend, összefüggések.
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  void _shiftMonth(int delta) => setState(() => _month = DateTime(_month.year, _month.month + delta));

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final stats = MoodStats(store);
    final avg = stats.monthAverage(_month);
    final insights = stats.insights();
    final tags = stats.tagStats();
    final isCurrentMonth = _month.year == DateTime.now().year && _month.month == DateTime.now().month;

    return Scaffold(
      appBar: AppBar(title: const Text('Statisztika')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Row(
            children: [
              _StatTile(label: 'Bejegyzés\nebben a hónapban', value: '${stats.monthCount(_month)}'),
              const SizedBox(width: 8),
              _StatTile(
                label: 'Átlagos\nhangulat',
                value: avg == null ? '–' : moodEmojis[avg.round() - 1],
                sub: avg?.toStringAsFixed(1).replaceAll('.', ','),
              ),
              const SizedBox(width: 8),
              _StatTile(label: 'Napló-\nsorozat', value: '🔥 ${stats.journalStreak()}'),
            ],
          ),
          const SizedBox(height: 12),

          // Havi naptár
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => _shiftMonth(-1)),
                      Expanded(
                        child: Text(
                          DateFormat('yyyy. MMMM', 'hu').format(_month),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: isCurrentMonth ? null : () => _shiftMonth(1),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  _MoodCalendar(month: _month, store: store),
                  const SizedBox(height: 8),
                  const Text('Koppints egy napra a bejegyzés megnyitásához vagy pótlásához.',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                ],
              ),
            ),
          ),

          // Trend
          const SectionTitle('Az elmúlt 30 nap'),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 16, 16, 12),
              child: SizedBox(height: 180, child: _MoodTrend(days: stats.lastDays(30))),
            ),
          ),

          // Címkék
          if (tags.isNotEmpty) ...[
            const SectionTitle('Leggyakoribb érzéseid'),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    for (final t in tags.take(6))
                      ListTile(
                        dense: true,
                        leading: Text(moodTags[t.tag] ?? '🏷️', style: const TextStyle(fontSize: 24)),
                        title: Text(t.tag, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                        subtitle: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: t.count / tags.first.count,
                            minHeight: 6,
                            backgroundColor: AppColors.background,
                            color: AppColors.moods[t.average.round() - 1],
                          ),
                        ),
                        trailing: Text('${t.count}×  ${moodEmojis[t.average.round() - 1]}',
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                  ],
                ),
              ),
            ),
          ],

          // Összefüggések
          const SectionTitle('Amit észrevettem'),
          if (insights.isEmpty)
            const EmptyState(
              emoji: '🔍',
              text: 'Írj még néhány napig naplót, és itt megmutatom, mi hat a hangulatodra.',
            )
          else
            for (final i in insights)
              Card(
                child: ListTile(
                  leading: Text(i.emoji, style: const TextStyle(fontSize: 26)),
                  title: Text(i.text, style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value, this.sub});

  final String label;
  final String value;
  final String? sub;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          child: Column(
            children: [
              Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
              if (sub != null) Text(sub!, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textMuted)),
              const SizedBox(height: 4),
              Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Hétfővel kezdődő havi naptár, a napok a hangulat színével.
class _MoodCalendar extends StatelessWidget {
  const _MoodCalendar({required this.month, required this.store});

  final DateTime month;
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leading = first.weekday - 1;
    final today = DateTime.now();
    const weekdays = ['H', 'K', 'Sz', 'Cs', 'P', 'Sz', 'V'];

    return Column(
      children: [
        Row(
          children: [
            for (final w in weekdays)
              Expanded(
                child: Text(w,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
              ),
          ],
        ),
        const SizedBox(height: 6),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          children: [
            for (var i = 0; i < leading; i++) const SizedBox(),
            for (var d = 1; d <= daysInMonth; d++)
              Builder(builder: (context) {
                final date = DateTime(month.year, month.month, d);
                final entry = store.entryFor(date);
                final isFuture = date.isAfter(today);
                final isToday = dayKey(date) == dayKey(today);
                return GestureDetector(
                  onTap: isFuture
                      ? null
                      : () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => JournalEditor(date: date, existing: entry)),
                          ),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: entry == null ? AppColors.background : AppColors.moods[entry.mood - 1],
                      border: isToday ? Border.all(color: AppColors.primary, width: 2) : null,
                    ),
                    child: entry == null
                        ? Text('$d',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isFuture ? Colors.black26 : AppColors.textMuted,
                            ))
                        : Text(moodEmojis[entry.mood - 1], style: const TextStyle(fontSize: 18)),
                  ),
                );
              }),
          ],
        ),
      ],
    );
  }
}

/// Egyszerű vonaldiagram a napi hangulatról (1–5).
class _MoodTrend extends StatelessWidget {
  const _MoodTrend({required this.days});

  final List<JournalEntry?> days;

  @override
  Widget build(BuildContext context) {
    if (days.every((d) => d == null)) {
      return const Center(child: Text('Még nincs adat.', style: TextStyle(color: AppColors.textMuted)));
    }
    return Row(
      children: [
        // Bal oldali tengely emojikkal
        Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [for (var m = 5; m >= 1; m--) Text(moodEmojis[m - 1], style: const TextStyle(fontSize: 14))],
        ),
        const SizedBox(width: 8),
        Expanded(child: CustomPaint(painter: _TrendPainter(days), size: Size.infinite)),
      ],
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter(this.days);

  final List<JournalEntry?> days;

  @override
  void paint(Canvas canvas, Size size) {
    double y(int mood) => size.height - (mood - 1) / 4 * size.height;
    double x(int i) => days.length == 1 ? size.width / 2 : i / (days.length - 1) * size.width;

    final grid = Paint()
      ..color = const Color(0xFFE6E4F0)
      ..strokeWidth = 1;
    for (var m = 1; m <= 5; m++) {
      canvas.drawLine(Offset(0, y(m)), Offset(size.width, y(m)), grid);
    }

    final points = <Offset>[];
    final colors = <Color>[];
    for (var i = 0; i < days.length; i++) {
      final e = days[i];
      if (e == null) continue;
      points.add(Offset(x(i), y(e.mood)));
      colors.add(AppColors.moods[e.mood - 1]);
    }

    if (points.length > 1) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (var i = 1; i < points.length; i++) {
        // Lágy görbe a pontok között
        final p0 = points[i - 1];
        final p1 = points[i];
        final mid = (p0.dx + p1.dx) / 2;
        path.cubicTo(mid, p0.dy, mid, p1.dy, p1.dx, p1.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = AppColors.primary
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
    }

    for (var i = 0; i < points.length; i++) {
      canvas.drawCircle(points[i], 6, Paint()..color = Colors.white);
      canvas.drawCircle(points[i], 4.5, Paint()..color = colors[i]);
    }
  }

  @override
  bool shouldRepaint(_TrendPainter old) => old.days != days;
}
