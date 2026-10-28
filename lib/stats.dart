import 'package:intl/intl.dart';

import 'models.dart';
import 'store.dart';

/// Egy felfedezett összefüggés a statisztika képernyőn.
class Insight {
  const Insight(this.emoji, this.text, this.strength, {this.tag});

  final String emoji;
  final String text;

  /// Mennyire erős az összefüggés (pontkülönbség); ez alapján rendezünk.
  final double strength;

  /// Ha címkéhez tartozik, az ő ikonja jelenik meg (lehet saját kép is).
  final MoodTag? tag;
}

class TagStat {
  const TagStat(this.tag, this.count, this.average);

  final String tag;
  final int count;
  final double average;
}

/// Hangulat-statisztikák számolása a naplóból és a célokból.
class MoodStats {
  MoodStats(this.store);

  final AppStore store;

  /// Legalább ennyi nap kell mindkét oldalon egy összefüggéshez.
  static const minSamples = 3;

  /// Ekkora (pontban mért) különbség alatt nem szólunk.
  static const minDiff = 0.3;

  static const maxInsights = 5;

  Iterable<JournalEntry> entriesBetween(DateTime from, DateTime to) =>
      store.journal.where((j) => !j.date.isBefore(from) && j.date.isBefore(to));

  static double? average(Iterable<JournalEntry> entries) {
    if (entries.isEmpty) return null;
    return entries.map((e) => e.mood).reduce((a, b) => a + b) / entries.length;
  }

  double? monthAverage(DateTime month) => average(entriesBetween(
        DateTime(month.year, month.month),
        DateTime(month.year, month.month + 1),
      ));

  int monthCount(DateTime month) => entriesBetween(
        DateTime(month.year, month.month),
        DateTime(month.year, month.month + 1),
      ).length;

  /// Hány egymást követő napon írtál naplót (ma még nem kötelező).
  int journalStreak([DateTime? now]) {
    var day = now ?? DateTime.now();
    if (store.entryFor(day) == null) day = addDays(day, -1);
    var count = 0;
    while (store.entryFor(day) != null) {
      count++;
      day = addDays(day, -1);
    }
    return count;
  }

  /// Az elmúlt [days] nap bejegyzései napi bontásban (null, ha nem írtál).
  List<JournalEntry?> lastDays(int days, [DateTime? now]) {
    final today = now ?? DateTime.now();
    return [for (var i = days - 1; i >= 0; i--) store.entryFor(addDays(today, -i))];
  }

  List<Insight> insights() {
    final result = <Insight>[];
    final entries = store.journal;

    // Célok: jobb-e a hangulat azokon a napokon, amikor teljesítetted?
    for (final h in store.habits) {
      final done = entries.where((e) => h.isDoneOn(e.date)).toList();
      final notDone = entries.where((e) => !h.isDoneOn(e.date)).toList();
      if (done.length < minSamples || notDone.length < minSamples) continue;
      final diff = average(done)! - average(notDone)!;
      if (diff.abs() < minDiff) continue;
      result.add(diff > 0
          ? Insight('✨', 'Azokon a napokon, amikor teljesítetted ezt: „${h.name}”, átlagosan ${_fmt(diff)} ponttal jobb volt a hangulatod.', diff)
          : Insight('🤔', 'Azokon a napokon, amikor teljesítetted ezt: „${h.name}”, átlagosan ${_fmt(-diff)} ponttal rosszabb volt a hangulatod.', -diff));
    }

    // Programok: milyen a hangulat azokon a napokon, amikor volt program?
    bool hadEvent(JournalEntry j) => store.events.any((e) => e.occursOn(j.date));
    final withEvent = entries.where(hadEvent).toList();
    final withoutEvent = entries.where((j) => !hadEvent(j)).toList();
    if (withEvent.length >= minSamples && withoutEvent.length >= minSamples) {
      final diff = average(withEvent)! - average(withoutEvent)!;
      if (diff >= minDiff) {
        result.add(Insight('🎉', 'Amikor programod van a barátaiddal, átlagosan ${_fmt(diff)} ponttal jobb a hangulatod.', diff));
      }
    }

    // Címkék: melyik érzés jár együtt jobb vagy rosszabb nappal?
    final overall = average(entries);
    for (final t in tagStats()) {
      if (t.count < minSamples || overall == null) continue;
      final diff = t.average - overall;
      if (diff.abs() < 0.5) continue;
      final tag = store.tagFor(t.tag);
      result.add(Insight(
        tag.emoji,
        diff > 0
            ? 'Amikor „${tag.name}” vagy, átlagosan ${_fmt(diff)} ponttal jobb a napod.'
            : 'Amikor „${tag.name}” vagy, átlagosan ${_fmt(-diff)} ponttal rosszabb a napod. Érdemes figyelni rá.',
        diff.abs(),
        tag: tag,
      ));
    }

    // A hét legjobb napja
    final byWeekday = <int, List<JournalEntry>>{};
    for (final e in entries) {
      byWeekday.putIfAbsent(e.date.weekday, () => []).add(e);
    }
    final usable = byWeekday.entries.where((w) => w.value.length >= 2).toList();
    if (usable.length >= 3) {
      usable.sort((a, b) => average(b.value)!.compareTo(average(a.value)!));
      final best = usable.first;
      final name = DateFormat.EEEE('hu').format(_dateForWeekday(best.key));
      result.add(Insight('📅', 'A hét legjobb napja nálad: $name (átlag ${_fmt(average(best.value)!)}).', 0.6));
    }

    // Napszakok (a napközbeni gyors hangulatokból)
    final parts = moodByPartOfDay();
    if (parts.length >= 2) {
      final sortedParts = parts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      final best = sortedParts.first;
      final worst = sortedParts.last;
      if (best.value - worst.value >= 0.5) {
        result.add(Insight('🕐',
            '${best.key[0].toUpperCase()}${best.key.substring(1)} a legjobb a kedved (${_fmt(best.value)}), '
            '${worst.key} a legrosszabb (${_fmt(worst.value)}).', best.value - worst.value));
      }
    }

    // A legerősebb összefüggések elöl, legfeljebb [maxInsights] darab.
    result.sort((a, b) => b.strength.compareTo(a.strength));
    return result.take(maxInsights).toList();
  }

  /// Átlagos hangulat napszakonként a gyors hangulatokból (csak ahol legalább [minSamples] van).
  Map<String, double> moodByPartOfDay() {
    final byPart = <String, List<int>>{};
    for (final c in store.checkIns) {
      byPart.putIfAbsent(partOfDay(c.at), () => []).add(c.mood);
    }
    return {
      for (final p in partsOfDay)
        if ((byPart[p]?.length ?? 0) >= minSamples) p: byPart[p]!.reduce((a, b) => a + b) / byPart[p]!.length,
    };
  }

  /// Címkénként: hányszor használtad és milyen volt átlagosan a hangulat. Gyakoriság szerint.
  List<TagStat> tagStats() {
    final byTag = <String, List<JournalEntry>>{};
    for (final e in store.journal) {
      for (final t in e.tags) {
        byTag.putIfAbsent(t, () => []).add(e);
      }
    }
    return [
      for (final t in byTag.entries) TagStat(t.key, t.value.length, average(t.value)!),
    ]..sort((a, b) => b.count.compareTo(a.count));
  }

  static String _fmt(double v) => v.toStringAsFixed(1).replaceAll('.', ',');

  /// Egy tetszőleges dátum a megadott hétköznapra (1 = hétfő), a napnév kiírásához.
  static DateTime _dateForWeekday(int weekday) => DateTime(2024, 1, weekday); // 2024.01.01 hétfő volt
}

/// Egy hónap összefoglalója: hány napot írtál, milyen volt a hangulat, mi volt a legjobb nap.
class MonthSummary {
  MonthSummary(this.store, DateTime month) : month = DateTime(month.year, month.month) {
    final stats = MoodStats(store);
    final next = DateTime(month.year, month.month + 1);
    entries = stats.entriesBetween(this.month, next).toList()..sort((a, b) => a.date.compareTo(b.date));
    average = MoodStats.average(entries);
    previousAverage = stats.monthAverage(DateTime(month.year, month.month - 1));
    daysInMonth = DateTime(month.year, month.month + 1, 0).day;

    // Legjobb nap: a legmagasabb hangulat, egyenlőségnél amelyiknél többet írtál.
    final sorted = [...entries]..sort((a, b) {
        final byMood = b.mood.compareTo(a.mood);
        if (byMood != 0) return byMood;
        return (b.gratitude.length + b.note.length).compareTo(a.gratitude.length + a.note.length);
      });
    best = sorted.firstOrNull;
    gratitudes = [for (final e in sorted) if (e.gratitude.isNotEmpty) e.gratitude].take(3).toList();

    final tagCounts = <String, int>{};
    for (final e in entries) {
      for (final t in e.tags) {
        tagCounts[t] = (tagCounts[t] ?? 0) + 1;
      }
    }
    topTags = (tagCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).take(3).toList();

    // Melyik célt teljesítetted a legtöbb napon.
    final days = [for (var d = 1; d <= daysInMonth; d++) DateTime(month.year, month.month, d, 12)];
    for (final h in store.habits) {
      final n = days.where(h.isDoneOn).length;
      if (n > topHabitDays) {
        topHabit = h;
        topHabitDays = n;
      }
    }

    // A hónapon belüli leghosszabb naplósorozat.
    var run = 0;
    for (final d in days) {
      run = store.entryFor(d) == null ? 0 : run + 1;
      if (run > longestStreak) longestStreak = run;
    }
  }

  final AppStore store;
  final DateTime month;
  late final List<JournalEntry> entries;
  late final double? average;
  late final double? previousAverage;
  late final int daysInMonth;
  late final JournalEntry? best;
  late final List<String> gratitudes;
  late final List<MapEntry<String, int>> topTags;
  Habit? topHabit;
  int topHabitDays = 0;
  int longestStreak = 0;

  bool get isEmpty => entries.isEmpty;

  /// Pl. „októberben” (a hónap neve -ban/-ben raggal).
  String get monthIn {
    final name = DateFormat.MMMM('hu').format(month);
    const back = {'január', 'február', 'március', 'április', 'május', 'június', 'július', 'augusztus'};
    return back.contains(name) ? '${name}ban' : '${name}ben';
  }
}

/// „az októberi”, „a szeptemberi”: a hónap mellékneve névelővel.
String monthAdjective(DateTime month) {
  final name = '${DateFormat.MMMM('hu').format(month)}i';
  return '${'aáeéiíoóöőuúüű'.contains(name[0]) ? 'az' : 'a'} $name';
}

/// Ékezetek nélküli kisbetűs alak, hogy a keresésnél a „halas” a „hálás”-t is megtalálja.
String foldAccents(String s) {
  const from = 'áéíóöőúüűÁÉÍÓÖŐÚÜŰ';
  const to = 'aeiooouuuAEIOOOUUU';
  final b = StringBuffer();
  for (final ch in s.toLowerCase().split('')) {
    final i = from.indexOf(ch);
    b.write(i < 0 ? ch : to[i].toLowerCase());
  }
  return b.toString();
}

/// Illeszkedik-e a bejegyzés a keresésre (hála, jegyzet, napi kérdés és válasz, címkék).
/// Több szónál mindegyiknek szerepelnie kell valahol.
bool entryMatches(JournalEntry e, String query, AppStore store) {
  final words = foldAccents(query).split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  if (words.isEmpty) return true;
  final text = foldAccents([
    e.gratitude,
    e.note,
    e.question,
    e.answer,
    for (final t in e.tags) store.tagFor(t).name,
    store.moodFace(e.mood).name,
  ].join(' '));
  return words.every(text.contains);
}

/// Egy régi bejegyzés felidézéshez: egy éve, fél éve vagy egy hónapja ezen a napon (az első, ami van).
({String label, JournalEntry entry})? memoryFor(AppStore store, DateTime now) {
  for (final (label, months) in [('Egy éve ezen a napon', 12), ('Fél éve ezen a napon', 6), ('Egy hónapja ezen a napon', 1)]) {
    final target = DateTime(now.year, now.month - months, now.day, 12);
    // Ha a hónap rövidebb (pl. március 31. → február), azt a napot kihagyjuk, ne csússzon el.
    if (target.day != now.day) continue;
    final e = store.entryFor(target);
    if (e != null && (e.gratitude.isNotEmpty || e.note.isNotEmpty || e.answer.isNotEmpty || e.moodImage != null)) {
      return (label: label, entry: e);
    }
  }
  return null;
}

/// Év végi visszatekintés: számok, a legjobb hónap és napok, a célok, a fotók.
class YearReview {
  YearReview(this.store, this.year) {
    entries = store.journal.where((e) => e.date.year == year).toList()..sort((a, b) => a.date.compareTo(b.date));
    average = MoodStats.average(entries);
    monthAverages = [
      for (var m = 1; m <= 12; m++) MoodStats.average(entries.where((e) => e.date.month == m)),
    ];
    final usable = [
      for (var m = 1; m <= 12; m++)
        if (entries.where((e) => e.date.month == m).length >= 5) (m, monthAverages[m - 1]!),
    ]..sort((a, b) => b.$2.compareTo(a.$2));
    bestMonth = usable.firstOrNull?.$1;

    bestDays = ([...entries]..sort((a, b) {
            final byMood = b.mood.compareTo(a.mood);
            return byMood != 0 ? byMood : (b.gratitude.length + b.note.length).compareTo(a.gratitude.length + a.note.length);
          }))
        .where((e) => e.gratitude.isNotEmpty || e.note.isNotEmpty)
        .take(5)
        .toList();

    final tagCounts = <String, int>{};
    for (final e in entries) {
      for (final t in e.tags) {
        tagCounts[t] = (tagCounts[t] ?? 0) + 1;
      }
    }
    topTags = (tagCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).take(5).toList();

    habitDays = [
      for (final h in store.habits) (h, h.doneDays.where((d) => d.startsWith('$year-')).length),
    ]..sort((a, b) => b.$2.compareTo(a.$2));
    habitDays.removeWhere((h) => h.$2 == 0);

    photos = entries.where((e) => e.moodImage != null || e.photoPath != null).toList();
    gratitudes = entries.where((e) => e.gratitude.isNotEmpty).length;
    events = store.events.where((e) => e.date.year == year).length;

    var run = 0;
    for (var d = DateTime(year, 1, 1, 12); d.year == year; d = addDays(d, 1)) {
      run = store.entryFor(d) == null ? 0 : run + 1;
      if (run > longestStreak) longestStreak = run;
    }
  }

  final AppStore store;
  final int year;
  late final List<JournalEntry> entries;
  late final double? average;
  late final List<double?> monthAverages;
  late final int? bestMonth;
  late final List<JournalEntry> bestDays;
  late final List<MapEntry<String, int>> topTags;
  late final List<(Habit, int)> habitDays;
  late final List<JournalEntry> photos;
  late final int gratitudes;
  late final int events;
  int longestStreak = 0;

  bool get isEmpty => entries.isEmpty;
}

/// Egy hét (hétfőtől vasárnapig) összefoglalója: célok, hangulat, napló, programok.
class WeekSummary {
  WeekSummary(this.store, DateTime day) : monday = addDays(day, 1 - day.weekday) {
    final now = DateTime.now();
    final days = [for (var i = 0; i < 7; i++) addDays(monday, i)];
    // Csak a már eltelt napok számítanak (vasárnap estig mind a 7).
    final past = days.where((d) => !DateTime(d.year, d.month, d.day).isAfter(now)).toList();
    elapsed = past.length;

    for (final h in store.habits) {
      final done = past.where(h.isDoneOn).length;
      final possible = h.isWeekly ? h.perWeek! : past.length;
      goalsDone += h.isWeekly ? (done > possible ? possible : done) : done;
      goalsPossible += possible;
      if (done > bestGoalDays) {
        bestGoal = h;
        bestGoalDays = done;
      }
    }

    entries = [for (final d in days) ?store.entryFor(d)];
    average = MoodStats.average(entries);
    final prev = [for (var i = 0; i < 7; i++) ?store.entryFor(addDays(monday, i - 7))];
    previousAverage = MoodStats.average(prev);
    events = store.events.where((e) => days.any((d) => dayKey(d) == dayKey(e.date))).length;
  }

  final AppStore store;
  final DateTime monday;
  late final int elapsed;
  int goalsDone = 0;
  int goalsPossible = 0;
  Habit? bestGoal;
  int bestGoalDays = 0;
  late final List<JournalEntry> entries;
  late final double? average;
  late final double? previousAverage;
  late final int events;

  DateTime get sunday => addDays(monday, 6);

  /// A célok teljesítése százalékban (null, ha nincs cél).
  int? get goalPercent => goalsPossible == 0 ? null : (goalsDone * 100 / goalsPossible).round();

  bool get isEmpty => goalsPossible == 0 && entries.isEmpty;

  /// Egy mondat a hétről.
  String get headline {
    final p = goalPercent;
    if (p != null && p >= 80) return 'Nagyon erős heted volt! 💪';
    if (average != null && previousAverage != null && average! > previousAverage! + 0.3) {
      return 'Jobb kedved volt, mint az előző héten. 🙂';
    }
    if (p != null && p >= 50) return 'Szép munka, tartsd a tempót!';
    if (entries.isEmpty && goalsDone == 0) return 'Csendes hét volt. Új hét, új lendület!';
    return 'Minden nap számít, a jövő héten még jobb lesz.';
  }
}
