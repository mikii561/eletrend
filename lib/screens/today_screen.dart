import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../photos.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/check_in_card.dart';
import '../widgets/memory_card.dart';
import '../widgets/tag_icon.dart';
import 'events_screen.dart';
import 'journal_screen.dart';
import 'pin_screen.dart';
import 'settings_screen.dart';

/// Főoldal: mai hangulat, mai célok és a következő programok.
class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key, required this.onNavigate});

  final ValueChanged<int> onNavigate;

  String _greeting(int hour) {
    if (hour < 10) return 'Jó reggelt';
    if (hour < 18) return 'Szép napot';
    return 'Jó estét';
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
    final done = store.habits.where((h) => h.isSatisfiedOn(now)).length;

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
                  offset: Offset.zero,
                  child: Card(
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
                                MoodButton(mood: i, selected: entry?.mood == i, photo: entry?.moodImage, onTap: () => _quickMood(context, i)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () async {
                              if (!await JournalLock.ensureUnlocked(context) || !context.mounted) return;
                              await Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => JournalEditor(date: now, existing: entry)),
                              );
                            },
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
                                  Icon(Icons.chevron_right, color: AppColors.textMuted),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Célok
                Transform.translate(
                  offset: const Offset(0, -28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const CheckInCard(),
                      const MemoryCard(),
                      SectionTitle('Mai célok', trailing: total == 0 ? null : '$done/$total', onMore: () => onNavigate(2)),
                      if (store.habits.isEmpty)
                        EmptyState(
                          emoji: '🌱',
                          text: 'Még nincs célod. Kezdd egy aprósággal!',
                          action: 'Cél felvétele',
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
                              subtitle: habitProgress(h, now) == null ? null : Text(habitProgress(h, now)!),
                              trailing: StreakChip(h.streak(now), unit: h.streakUnit),
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
    final name = StoreScope.of(context).myName;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, top + 16, 12, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  date.toUpperCase(),
                  style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600, fontSize: 12, letterSpacing: 0.8),
                ),
                const SizedBox(height: 2),
                Text(
                  name.isEmpty ? greeting : '$greeting, ${name.split(' ').first}',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ],
            ),
          ),
          if (total > 0)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: SizedBox(
                width: 46,
                height: 46,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: done / total,
                      strokeWidth: 4,
                      backgroundColor: AppColors.divider,
                      color: AppColors.primary,
                      strokeCap: StrokeCap.round,
                    ),
                    Center(
                      child: Text('$done/$total', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ),
          IconButton(
            tooltip: 'Beállítások',
            icon: Icon(Icons.settings_outlined, color: AppColors.textMuted),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
    );
  }
}

/// Nagy, kerek pipa gomb a célokhoz.
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
          border: done ? null : Border.all(color: AppColors.divider, width: 2.5),
        ),
        child: done ? Icon(Icons.check_rounded, color: Colors.white, size: size * 0.6) : null,
      ),
    );
  }
}

class StreakChip extends StatelessWidget {
  const StreakChip(this.days, {super.key, this.unit = 'nap'});

  final int days;

  /// „nap” vagy (heti célnál) „hét”.
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: days > 0 ? AppColors.accent.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_fire_department_rounded, size: 16, color: days > 0 ? AppColors.accent : AppColors.textMuted),
          const SizedBox(width: 2),
          Text(unit == 'nap' ? '$days' : '$days $unit',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: days > 0 ? AppColors.accent : AppColors.textMuted)),
        ],
      ),
    );
  }
}

/// Egy hangulat emoji gombként, kiválasztva kiemelve.
class MoodButton extends StatelessWidget {
  const MoodButton({
    super.key,
    required this.mood,
    required this.selected,
    required this.onTap,
    this.size = 52,
    this.photo,
    this.editing = false,
  });

  final int mood;
  final bool selected;
  final VoidCallback onTap;
  final double size;

  /// A nap saját hangulatfotója (base64); kiválasztva ez látszik az arc helyett.
  final String? photo;

  /// Szerkesztő módban egy kis ceruza jelzi, hogy koppintásra szerkeszthető.
  final bool editing;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.moods[mood - 1];
    final button = GestureDetector(
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
          child: selected && photo != null
              ? ClipOval(
                  child: Image.memory(TagImages.decode(photo!), width: size - 6, height: size - 6, fit: BoxFit.cover),
                )
              // A saját kép kitölti a kört, az emoji kisebb.
              : MoodFace(mood, size: StoreScope.of(context).moodFace(mood).image != null ? size - 6 : size * 0.62),
        ),
      ),
    );
    if (!editing) return button;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        button,
        Positioned(
          right: -2,
          bottom: -2,
          child: IgnorePointer(
            child: CircleAvatar(
              radius: 11,
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.edit, size: 13, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

/// A cél mai állása kiíráshoz: „3/8 pohár”, „2/3 ezen a héten”; egyszerű napi célnál null.
String? habitProgress(Habit h, DateTime day) {
  final parts = [
    if (h.isCounted) '${h.countOn(day)}/${h.target}${h.unit.isEmpty ? '' : ' ${h.unit}'}',
    if (h.isWeekly) '${h.doneInWeek(day)}/${h.perWeek} ezen a héten',
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}
