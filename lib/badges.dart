import 'models.dart';
import 'store.dart';

/// Egy jelvény és a feltétele.
class Achievement {
  const Achievement(this.id, this.emoji, this.title, this.text, this.earned);

  final String id;
  final String emoji;
  final String title;

  /// Mit kell tenni érte (a még meg nem szerzetteknél is látszik).
  final String text;
  final bool Function(BadgeFacts f) earned;
}

/// A jelvényekhez szükséges számok, egyszer kiszámolva.
class BadgeFacts {
  BadgeFacts(AppStore s)
      : entries = s.journal.length,
        gratitudes = s.journal.where((e) => e.gratitude.isNotEmpty).length,
        photos = s.journal.where((e) => e.moodImage != null || e.photoPath != null).length,
        habits = s.habits.length,
        events = s.events.length,
        shared = s.events.where((e) => e.shareId != null).length,
        bestHabitStreak = s.habits.fold(0, (m, h) => _longestRun(h.doneDays) > m ? _longestRun(h.doneDays) : m),
        bestJournalStreak = _longestRun({for (final e in s.journal) dayKey(e.date)}),
        fullMonth = _hasFullMonth(s);

  final int entries;
  final int gratitudes;
  final int photos;
  final int habits;
  final int events;
  final int shared;
  final int bestHabitStreak;
  final int bestJournalStreak;
  final bool fullMonth;

  /// A leghosszabb egymást követő napsor a napkulcsok között.
  static int _longestRun(Set<String> days) {
    var best = 0;
    for (final key in days) {
      final d = DateTime.parse(key);
      if (days.contains(dayKey(addDays(d, -1)))) continue; // nem egy sor eleje
      var run = 1;
      while (days.contains(dayKey(addDays(d, run)))) {
        run++;
      }
      if (run > best) best = run;
    }
    return best;
  }

  /// Van-e olyan (lezárt) hónap, amelynek minden napján írtál.
  static bool _hasFullMonth(AppStore s) {
    final months = {for (final e in s.journal) DateTime(e.date.year, e.date.month)};
    final now = DateTime.now();
    return months.any((m) {
      if (!m.isBefore(DateTime(now.year, now.month))) return false;
      final days = DateTime(m.year, m.month + 1, 0).day;
      return [for (var d = 1; d <= days; d++) DateTime(m.year, m.month, d, 12)].every((d) => s.entryFor(d) != null);
    });
  }
}

final achievements = <Achievement>[
  Achievement('first_entry', '📔', 'Első oldal', 'Írd meg az első naplóbejegyzésed.', (f) => f.entries >= 1),
  Achievement('first_habit', '🌱', 'Elültetve', 'Vegyél fel egy szokást.', (f) => f.habits >= 1),
  Achievement('habit_7', '🔥', 'Egy hét', 'Tarts meg egy szokást 7 napig egyfolytában.', (f) => f.bestHabitStreak >= 7),
  Achievement('habit_30', '💪', 'Egy hónap', 'Tarts meg egy szokást 30 napig egyfolytában.', (f) => f.bestHabitStreak >= 30),
  Achievement('habit_100', '🏆', 'Százas', 'Tarts meg egy szokást 100 napig egyfolytában.', (f) => f.bestHabitStreak >= 100),
  Achievement('journal_7', '✍️', 'Hét nap, hét oldal', 'Írj naplót 7 napig egymás után.', (f) => f.bestJournalStreak >= 7),
  Achievement('journal_30', '📚', 'Naplóíró', 'Írj naplót 30 napig egymás után.', (f) => f.bestJournalStreak >= 30),
  Achievement('entries_100', '💯', 'Száz nap', 'Gyűjts össze 100 naplóbejegyzést.', (f) => f.entries >= 100),
  Achievement('full_month', '🗓️', 'Teljes hónap', 'Írj egy hónap minden napján.', (f) => f.fullMonth),
  Achievement('gratitude_50', '🙏', 'Hálás szív', 'Írd le 50-szer, miért vagy hálás.', (f) => f.gratitudes >= 50),
  Achievement('photos_10', '📸', 'Fotóalbum', 'Tegyél fotót 10 bejegyzéshez.', (f) => f.photos >= 10),
  Achievement('first_event', '🎉', 'Szervező', 'Szervezz egy programot.', (f) => f.events >= 1),
  Achievement('first_share', '🔗', 'Gyertek!', 'Küldj meghívót a barátaidnak egy programra.', (f) => f.shared >= 1),
];

/// A már megszerzett jelvények azonosítói.
Set<String> earnedBadges(AppStore store) {
  final f = BadgeFacts(store);
  return {for (final a in achievements) if (a.earned(f)) a.id};
}
