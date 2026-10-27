import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'today_screen.dart' show CheckCircle, StreakChip;

/// Szokások listája az elmúlt 7 nap teljesítésével.
class HabitsScreen extends StatelessWidget {
  const HabitsScreen({super.key});

  Future<void> _addHabit(BuildContext context) async {
    final store = StoreScope.of(context);
    final name = await showTextInputSheet(context, title: 'Új szokás', hint: 'pl. 2 liter víz, 10 perc olvasás', action: 'Hozzáadás');
    if (name != null && name.trim().isNotEmpty) store.addHabit(name);
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final today = DateTime.now();
    final days = List.generate(7, (i) => addDays(today, i - 6));

    return Scaffold(
      appBar: AppBar(title: const Text('Szokások')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addHabit(context),
        icon: const Icon(Icons.add),
        label: const Text('Új szokás', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
        children: [
          if (store.habits.isEmpty)
            EmptyState(
              emoji: '🌱',
              text: 'Vegyél fel egy szokást, amit naponta követni szeretnél.',
              action: 'Szokás felvétele',
              onAction: () => _addHabit(context),
            ),
          for (final h in store.habits)
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 4, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CheckCircle(done: h.isDoneOn(today), onTap: () => store.toggleHabit(h), size: 40),
                        const SizedBox(width: 12),
                        Expanded(child: Text(h.name, style: Theme.of(context).textTheme.titleMedium)),
                        StreakChip(h.streak(today)),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, color: AppColors.textMuted),
                          onSelected: (_) => store.removeHabit(h),
                          itemBuilder: (_) => const [PopupMenuItem(value: 'delete', child: Text('Törlés'))],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          for (final d in days)
                            _DayDot(day: d, isToday: d.day == today.day, done: h.isDoneOn(d), onTap: () => store.toggleHabit(h, d)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DayDot extends StatelessWidget {
  const _DayDot({required this.day, required this.isToday, required this.done, required this.onTap});

  final DateTime day;
  final bool isToday;
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Text(
            DateFormat.E('hu').format(day),
            style: TextStyle(
              fontSize: 12,
              fontWeight: isToday ? FontWeight.w900 : FontWeight.w600,
              color: isToday ? AppColors.primary : AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 6),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: done ? AppColors.headerGradient : null,
              color: done ? null : AppColors.background,
              border: isToday && !done ? Border.all(color: AppColors.primary, width: 2) : null,
            ),
            child: done
                ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
                : Text('${day.day}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
          ),
        ],
      ),
    );
  }
}
