import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/tag_icon.dart';
import 'events_screen.dart';
import 'journal_screen.dart';
import 'settings_screen.dart';

/// Főoldal: mai hangulat, mai szokások és a következő programok.
class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key, required this.onNavigate});

  final ValueChanged<int> onNavigate;

  String _greeting(int hour) {
    if (hour < 10) return 'Jó reggelt! ☀️';
    if (hour < 18) return 'Szép napot! 🌿';
    return 'Jó estét! 🌙';
  }

  void _quickMood(BuildContext context, int mood) {
    final store = StoreScope.of(context);
    final now = DateTime.now();
    final existing = store.entryFor(now);
    store.saveEntry((existing ?? JournalEntry(id: newId(), date: now, mood: mood))..mood = mood);
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final now = DateTime.now();
    final entry = store.entryFor(now);
    final upcoming = store.upcomingEvents.take(3).toList();
    final total = store.habits.length;
    final done = store.habits.where((h) => h.isDoneOn(now)).length;

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _Header(
            greeting: _greeting(now.hour),
            date: DateFormat('MMMM d., EEEE', 'hu').format(now),
            done: done,
            total: total,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Hangulat
                Transform.translate(
                  offset: const Offset(0, -28),
                  child: Card(
                    elevation: 6,
                    shadowColor: Colors.black12,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(entry == null ? 'Milyen napod van?' : 'Mai hangulat: ${StoreScope.of(context).moodFace(entry.mood).name}',
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              for (var i = 1; i <= 5; i++)
                                MoodButton(mood: i, selected: entry?.mood == i, onTap: () => _quickMood(context, i)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => JournalEditor(date: now, existing: entry)),
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                children: [
                                  const Text('🙏', style: TextStyle(fontSize: 18)),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      entry == null || entry.gratitude.isEmpty
                                          ? 'Miért vagy ma hálás?'
                                          : entry.gratitude,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: entry == null || entry.gratitude.isEmpty ? AppColors.textMuted : null,
                                      ),
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right, color: AppColors.textMuted),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Szokások
                Transform.translate(
                  offset: const Offset(0, -28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SectionTitle('Mai szokások', trailing: total == 0 ? null : '$done/$total', onMore: () => onNavigate(2)),
                      if (store.habits.isEmpty)
                        EmptyState(
                          emoji: '🌱',
                          text: 'Még nincs szokásod. Kezdd egy aprósággal!',
                          action: 'Szokás felvétele',
                          onAction: () => onNavigate(2),
                        )
                      else
                        for (final h in store.habits)
                          Card(
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                              leading: CheckCircle(done: h.isDoneOn(now), onTap: () => store.toggleHabit(h)),
                              title: Text(
                                h.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  decoration: h.isDoneOn(now) ? TextDecoration.lineThrough : null,
                                  color: h.isDoneOn(now) ? AppColors.textMuted : null,
                                ),
                              ),
                              trailing: StreakChip(h.streak(now)),
                              onTap: () => store.toggleHabit(h),
                            ),
                          ),

                      // Programok
                      SectionTitle('Következő programok', onMore: () => onNavigate(1)),
                      if (upcoming.isEmpty)
                        EmptyState(
                          emoji: '🎉',
                          text: 'Nincs tervezett program. Szervezz valamit a barátaiddal!',
                          action: 'Program szervezése',
                          onAction: () => onNavigate(1),
                        )
                      else
                        for (final e in upcoming) EventCard(event: e),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.greeting, required this.date, required this.done, required this.total});

  final String greeting;
  final String date;
  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.fromLTRB(20, top + 20, 20, 52),
      decoration: const BoxDecoration(
        gradient: AppColors.headerGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(date, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
                    ),
                    IconButton(
                      tooltip: 'Beállítások',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.settings_outlined, color: Colors.white),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SettingsScreen()),
                      ),
                    ),
                  ],
                ),
                Text(greeting,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white)),
              ],
            ),
          ),
          if (total > 0)
            SizedBox(
              width: 64,
              height: 64,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: done / total,
                    strokeWidth: 6,
                    backgroundColor: Colors.white24,
                    color: Colors.white,
                    strokeCap: StrokeCap.round,
                  ),
                  Center(
                    child: Text('${(done / total * 100).round()}%',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Nagy, kerek pipa gomb a szokásokhoz.
class CheckCircle extends StatelessWidget {
  const CheckCircle({super.key, required this.done, required this.onTap, this.size = 36});

  final bool done;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: done ? AppColors.headerGradient : null,
          border: done ? null : Border.all(color: const Color(0xFFD5D3E3), width: 2.5),
        ),
        child: done ? Icon(Icons.check_rounded, color: Colors.white, size: size * 0.6) : null,
      ),
    );
  }
}

class StreakChip extends StatelessWidget {
  const StreakChip(this.days, {super.key});

  final int days;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: days > 0 ? AppColors.accent.withValues(alpha: 0.15) : AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text('🔥 $days', style: const TextStyle(fontWeight: FontWeight.w800)),
    );
  }
}

/// Egy hangulat emoji gombként, kiválasztva kiemelve.
class MoodButton extends StatelessWidget {
  const MoodButton({super.key, required this.mood, required this.selected, required this.onTap, this.size = 52});

  final int mood;
  final bool selected;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.moods[mood - 1];
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected ? color.withValues(alpha: 0.25) : AppColors.background,
          border: Border.all(color: selected ? color : Colors.transparent, width: 2.5),
        ),
        child: AnimatedScale(
          scale: selected ? 1.15 : 1,
          duration: const Duration(milliseconds: 180),
          // A saját kép kitölti a kört, az emoji kisebb.
          child: MoodFace(mood, size: StoreScope.of(context).moodFace(mood).image != null ? size - 6 : size * 0.62),
        ),
      ),
    );
  }
}
