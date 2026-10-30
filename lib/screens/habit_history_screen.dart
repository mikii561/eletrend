import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';

/// Egy cél előzményei havi naptárban vagy éves áttekintésben, statisztikával.
class HabitHistoryScreen extends StatefulWidget {
  const HabitHistoryScreen({super.key, required this.habitId});

  final String habitId;

  @override
  State<HabitHistoryScreen> createState() => _HabitHistoryScreenState();
}

class _HabitHistoryScreenState extends State<HabitHistoryScreen> {
  bool _year = false;
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  void _shift(int by) => setState(
    () => _month = _year ? DateTime(_month.year + by, _month.month) : DateTime(_month.year, _month.month + by),
  );

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final h = store.habits.where((h) => h.id == widget.habitId).firstOrNull;
    if (h == null) return Scaffold(appBar: AppBar());
    final now = DateTime.now();
    final from = _year ? DateTime(_month.year, 1, 1) : _month;
    final to = _year ? DateTime(_month.year, 12, 31) : DateTime(_month.year, _month.month + 1, 0);
    final isCurrent = _year ? _month.year == now.year : _month.year == now.year && _month.month == now.month;

    return Scaffold(
      appBar: AppBar(title: Text(h.name)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: false, label: Text('Hónap')),
              ButtonSegment(value: true, label: Text('Év')),
            ],
            selected: {_year},
            onSelectionChanged: (s) => setState(() => _year = s.first),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              IconButton(tooltip: 'Előző', icon: const Icon(Icons.chevron_left), onPressed: () => _shift(-1)),
              Expanded(
                child: Text(
                  _year ? '${_month.year}' : DateFormat('y. MMMM', 'hu').format(_month),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: 'Következő',
                icon: const Icon(Icons.chevron_right),
                onPressed: isCurrent ? null : () => _shift(1),
              ),
            ],
          ),
          const SizedBox(height: 4),
          _Stats(habit: h, from: from, to: to),
          const SizedBox(height: 8),
          if (_year)
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 0.9,
              children: [
                for (var m = 1; m <= 12; m++)
                  _MiniMonth(
                    habit: h,
                    month: DateTime(_month.year, m),
                    onTap: () => setState(() {
                      _month = DateTime(_month.year, m);
                      _year = false;
                    }),
                  ),
              ],
            )
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: _MonthGrid(habit: h, month: _month, onTap: (d) => store.toggleHabit(h, d)),
              ),
            ),
          if (!_year)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Koppints egy napra a pótláshoz vagy javításhoz.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }
}

/// Az időszak számai: teljesített napok, arány, jelenlegi és leghosszabb sorozat.
class _Stats extends StatelessWidget {
  const _Stats({required this.habit, required this.from, required this.to});

  final Habit habit;
  final DateTime from;
  final DateTime to;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final end = to.isAfter(today) ? today : to;
    final done = habit.doneBetween(from, to);
    // Az arány az első teljesítés napjától számít, hogy egy új cél ne induljon sok „elmulasztott” nappal.
    final firstKey = habit.doneDays.isEmpty ? null : (habit.doneDays.toList()..sort()).first;
    final firstDay = firstKey == null ? today : DateTime.parse(firstKey);
    final start = firstDay.isAfter(from) ? firstDay : from;
    // Az eltelt napok (jövőbeli napok nem számítanak bele az arányba).
    final elapsed = end.isBefore(start) ? 0 : end.difference(start).inDays + 1;
    final String rate;
    if (habit.isWeekly) {
      var weeks = 0, met = 0;
      for (var m = addDays(start, 1 - start.weekday); !m.isAfter(end); m = addDays(m, 7)) {
        weeks++;
        if (habit.doneInWeek(m) >= habit.perWeek!) met++;
      }
      rate = '$met/$weeks hét';
    } else {
      rate = elapsed == 0 ? '–' : '${(done * 100 / elapsed).round()}%';
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Stat(value: '$done', label: 'nap kész'),
          _Stat(value: rate, label: habit.isWeekly ? 'heti cél' : 'teljesítés'),
          _Stat(value: '${habit.streak()}', label: 'sorozat'),
          _Stat(value: '${habit.longestStreak()}', label: 'rekord'),
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
      margin: const EdgeInsets.symmetric(horizontal: 3),
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

/// Egy hónap naptára (hétfővel kezdve); a kész napok kitöltve.
class _MonthGrid extends StatelessWidget {
  const _MonthGrid({required this.habit, required this.month, required this.onTap});

  final Habit habit;
  final DateTime month;
  final void Function(DateTime day) onTap;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final first = DateTime(month.year, month.month, 1, 12);
    final count = DateTime(month.year, month.month + 1, 0).day;
    final lead = first.weekday - 1;
    final weekdays = [for (var i = 0; i < 7; i++) DateFormat.E('hu').format(DateTime(2024, 1, 1 + i))];
    return Column(
      children: [
        Row(
          children: [
            for (final w in weekdays)
              Expanded(
                child: Text(
                  w,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 7,
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          children: [
            for (var i = 0; i < lead; i++) const SizedBox(),
            for (var d = 1; d <= count; d++) _cell(DateTime(month.year, month.month, d, 12), now),
          ],
        ),
      ],
    );
  }

  Widget _cell(DateTime day, DateTime now) {
    final done = habit.isDoneOn(day);
    final isToday = dayKey(day) == dayKey(now);
    final future = day.isAfter(now) && !isToday;
    final partial = !done && habit.isCounted && habit.countOn(day) > 0;
    return GestureDetector(
      onTap: future ? null : () => onTap(day),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: done ? AppColors.primary : AppColors.background,
          border: isToday && !done
              ? Border.all(color: AppColors.primary, width: 2)
              : partial
              ? Border.all(color: AppColors.primary.withValues(alpha: 0.5), width: 2)
              : null,
        ),
        child: Text(
          '${day.day}',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: done
                ? AppColors.onPrimary
                : future
                ? AppColors.divider
                : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

/// Éves nézet egy hónapja: apró pöttyök és a kész napok száma.
class _MiniMonth extends StatelessWidget {
  const _MiniMonth({required this.habit, required this.month, required this.onTap});

  final Habit habit;
  final DateTime month;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final count = DateTime(month.year, month.month + 1, 0).day;
    final lead = DateTime(month.year, month.month, 1).weekday - 1;
    final done = habit.doneBetween(month, DateTime(month.year, month.month, count));
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      DateFormat.MMM('hu').format(month),
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                  Text('$done', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 6),
              Expanded(
                child: GridView.count(
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 7,
                  mainAxisSpacing: 2,
                  crossAxisSpacing: 2,
                  children: [
                    for (var i = 0; i < lead; i++) const SizedBox(),
                    for (var d = 1; d <= count; d++)
                      Container(
                        decoration: BoxDecoration(
                          color: habit.isDoneOn(DateTime(month.year, month.month, d))
                              ? AppColors.primary
                              : AppColors.divider,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
