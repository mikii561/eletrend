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

/// Hangulat-statisztikák számolása a naplóból és a szokásokból.
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

    // Szokások: jobb-e a hangulat azokon a napokon, amikor teljesítetted?
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

    // A legerősebb összefüggések elöl, legfeljebb [maxInsights] darab.
    result.sort((a, b) => b.strength.compareTo(a.strength));
    return result.take(maxInsights).toList();
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

    // Melyik szokást teljesítetted a legtöbb napon.
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
