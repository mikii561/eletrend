import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../challenges.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'habit_editor.dart';
import 'habit_history_screen.dart';
import 'shared_goal_widgets.dart';
import '../widgets/goal_widgets.dart';

/// Célok listája az elmúlt 7 nap teljesítésével.
class HabitsScreen extends StatelessWidget {
  const HabitsScreen({super.key});

  Future<void> _addHabit(BuildContext context) => showHabitEditor(context);

  void _openHistory(BuildContext context, Habit h) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => HabitHistoryScreen(habitId: h.id)));

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final today = DateTime.now();
    final days = List.generate(7, (i) => addDays(today, i - 6));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Célok'),
        actions: [
          TextButton.icon(
            onPressed: () => showHabitTemplates(context),
            icon: const Icon(Icons.auto_awesome_outlined),
            label: const Text('Sablonok'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addHabit(context),
        icon: const Icon(Icons.add),
        label: const Text('Új cél', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
        children: [
          const SharedGoalInvites(),
          if (store.habits.isEmpty)
            EmptyState(
              emoji: '🌱',
              text: 'Vegyél fel egy célt, amit követni szeretnél: naponta, hetente párszor, vagy mennyiséggel (pl. 8 pohár víz).',
              action: 'Cél felvétele',
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
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _openHistory(context, h),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(h.name, style: Theme.of(context).textTheme.titleMedium),
                                if (habitProgress(h, today) != null || h.reminderMinutes != null)
                                  Text(
                                    [
                                      ?habitProgress(h, today),
                                      if (h.reminderMinutes != null)
                                        '⏰ ${(h.reminderMinutes! ~/ 60).toString().padLeft(2, '0')}:${(h.reminderMinutes! % 60).toString().padLeft(2, '0')}',
                                    ].join(' · '),
                                    style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        StreakChip(h.streak(today), unit: h.streakUnit),
                        PopupMenuButton<String>(
                          icon: Icon(Icons.more_vert, color: AppColors.textMuted),
                          onSelected: (v) => switch (v) {
                            'edit' => showHabitEditor(context, habit: h),
                            'history' => _openHistory(context, h),
                            'share' => showShareGoalSheet(context, h),
                            'unshare' => stopSharedGoal(context, sharedGoalIdOf(store, h)!),
                            _ => store.removeHabit(h),
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(value: 'history', child: Text('Előzmények')),
                            if (Challenges.instance.ready)
                              sharedGoalIdOf(store, h) == null
                                  ? const PopupMenuItem(value: 'share', child: Text('Közös cél egy baráttal'))
                                  : const PopupMenuItem(value: 'unshare', child: Text('Közös cél leállítása')),
                            const PopupMenuItem(value: 'edit', child: Text('Szerkesztés')),
                            const PopupMenuItem(value: 'delete', child: Text('Törlés')),
                          ],
                        ),
                      ],
                    ),
                    // Mennyiségi célnál: egy adaggal kevesebb / több.
                    if (h.isCounted)
                      Padding(
                        padding: const EdgeInsets.only(top: 10, right: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: h.countOn(today) / h.target,
                                  minHeight: 10,
                                  backgroundColor: AppColors.background,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.outlined(
                              tooltip: 'Egy kevesebb',
                              onPressed: h.countOn(today) > 0 ? () => store.decrementHabit(h) : null,
                              icon: const Icon(Icons.remove),
                            ),
                            IconButton.filled(
                              tooltip: 'Még egy',
                              onPressed: h.countOn(today) < h.target ? () => store.toggleHabit(h) : null,
                              icon: const Icon(Icons.add),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          for (final d in days)
                            _DayDot(
                              day: d,
                              isToday: d.day == today.day,
                              done: h.isDoneOn(d),
                              onTap: () => store.toggleHabit(h, d),
                            ),
                        ],
                      ),
                    ),
                    if (sharedGoalIdOf(store, h) case final id? when Challenges.instance.ready)
                      SharedGoalRow(key: ValueKey(id), challengeId: id),
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
                : Text(
                    '${day.day}',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textMuted),
                  ),
          ),
        ],
      ),
    );
  }
}
