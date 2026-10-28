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
