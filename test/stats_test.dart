import 'package:eletrend/models.dart';
import 'package:eletrend/questions.dart';
import 'package:eletrend/stats.dart';
import 'package:eletrend/store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() => initializeDateFormatting('hu'));

  Future<AppStore> emptyStore() async {
    SharedPreferences.setMockInitialValues({});
    return AppStore.load();
  }

  JournalEntry entry(DateTime d, int mood) => JournalEntry(id: dayKey(d), date: d, mood: mood);

  test('szokás-összefüggés: jobb hangulat a teljesített napokon', () async {
    final store = await emptyStore();
    store.addHabit('Edzés');
    final habit = store.habits.first;
    final start = DateTime(2026, 10, 1);
    for (var i = 0; i < 8; i++) {
      final d = start.add(Duration(days: i));
      final trained = i.isEven;
      if (trained) habit.doneDays.add(dayKey(d));
      store.saveEntry(entry(d, trained ? 5 : 3));
    }

    final insights = MoodStats(store).insights();
    expect(insights.any((i) => i.text.contains('Edzés') && i.text.contains('jobb')), isTrue);
  });

  test('címkék: gyakoriság, átlag és összefüggés', () async {
    final store = await emptyStore();
    final start = DateTime(2026, 10, 1);
    for (var i = 0; i < 6; i++) {
      final calm = i < 3;
      store.saveEntry(entry(start.add(Duration(days: i)), calm ? 5 : 2)..tags = [calm ? 'nyugodt' : 'stresszes']);
    }
    store.journal.first.tags.add('fáradt');

    final stats = MoodStats(store);
    final tags = stats.tagStats();
    expect(tags.first.count, 3);
    expect(tags.firstWhere((t) => t.tag == 'nyugodt').average, 5);
    final texts = stats.insights().map((i) => i.text).join('\n');
    expect(texts, contains('„nyugodt” vagy, átlagosan 1,5 ponttal jobb'));
    expect(texts, contains('„stresszes” vagy, átlagosan 1,5 ponttal rosszabb'));
  });

  test('kevés adatnál nincs összefüggés', () async {
    final store = await emptyStore();
    store.addHabit('Olvasás');
    store.saveEntry(entry(DateTime(2026, 10, 1), 4));
    expect(MoodStats(store).insights(), isEmpty);
  });

  test('napi kérdés: naponta állandó, a válasz megmarad mentés után', () async {
    final day = DateTime(2026, 10, 27);
    expect(questionFor(day), questionFor(DateTime(2026, 10, 27, 23)));
    expect(nextQuestion(questionFor(day)), isNot(questionFor(day)));

    final store = await emptyStore();
    store.saveEntry(entry(day, 4)
      ..question = questionFor(day)
      ..answer = 'A kávé');
    final reloaded = await AppStore.load();
    expect(reloaded.entryFor(day)!.answer, 'A kávé');
    expect(reloaded.entryFor(day)!.question, questionFor(day));
  });

  test('sorozat az óraátállítás napján sem számol duplán', () async {
    final store = await emptyStore();
    // 2026.10.25-én ért véget a nyári időszámítás; késő este ellenőrzünk.
    for (var d = 20; d <= 26; d++) {
      store.saveEntry(entry(DateTime(2026, 10, d, 12), 3));
    }
    store.addHabit('Séta');
    for (var d = 20; d <= 26; d++) {
      store.habits.first.doneDays.add(dayKey(DateTime(2026, 10, d)));
    }
    final lateEvening = DateTime(2026, 10, 26, 23, 30);
    expect(MoodStats(store).journalStreak(lateEvening), 7);
    expect(store.habits.first.streak(lateEvening), 7);
  });

  test('havi átlag és napló-sorozat', () async {
    final store = await emptyStore();
    final now = DateTime(2026, 10, 27);
    store.saveEntry(entry(DateTime(2026, 10, 25), 2));
    store.saveEntry(entry(DateTime(2026, 10, 26), 4));
    store.saveEntry(entry(DateTime(2026, 9, 30), 5));

    final stats = MoodStats(store);
    expect(stats.monthAverage(DateTime(2026, 10)), 3);
    expect(stats.monthCount(DateTime(2026, 10)), 2);
    expect(stats.journalStreak(now), 2);
  });
}
