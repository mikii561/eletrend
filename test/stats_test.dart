import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:eletrend/models.dart';
import 'package:eletrend/photos.dart';
import 'package:eletrend/questions.dart';
import 'package:eletrend/stats.dart';
import 'package:eletrend/screens/year_review_screen.dart';
import 'package:eletrend/store.dart';
import 'package:flutter/material.dart';
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

  test('saját címke: átnevezés, elrejtés, sorrend és törlés megmarad', () async {
    final store = await emptyStore();
    expect(store.moodTags.length, defaultMoodTags.length);
    final own = store.addTag(name: 'kalandvágyó', emoji: '🧗', image: 'AAEC');
    expect(store.tagNameTaken('Kalandvágyó'), isTrue);
    expect(store.tagNameTaken('kalandvágyó', except: own), isFalse);

    store.saveEntry(entry(DateTime(2026, 10, 27), 5)..tags = ['nyugodt', own.id]);
    store.updateTag(store.tagFor('nyugodt')
      ..name = 'zen'
      ..visible = false);
    store.moveTag(store.moodTags.indexOf(own), 0);

    final reloaded = await AppStore.load();
    expect(reloaded.moodTags.first.name, 'kalandvágyó');
    expect(reloaded.moodTags.first.imageBytes, [0, 1, 2]);
    expect(reloaded.tagFor('nyugodt').name, 'zen');
    expect(reloaded.visibleTags.any((t) => t.id == 'nyugodt'), isFalse);
    // Átnevezés után is a régi bejegyzéshez tartozik.
    expect(reloaded.entryFor(DateTime(2026, 10, 27))!.tags, contains('nyugodt'));

    final mine = reloaded.tagFor(own.id);
    expect(reloaded.tagUsage(mine), 1);
    reloaded.removeTag(mine);
    expect(reloaded.entryFor(DateTime(2026, 10, 27))!.tags, ['nyugodt']);
  });

  test('saját hangulatarc: megmarad, és visszaállítható', () async {
    final store = await emptyStore();
    expect(store.moodFace(4).emoji, moodEmojis[3]);
    store.updateTag(store.moodFace(5)
      ..name = 'Szuper nap'
      ..image = 'AAEC');
    final reloaded = await AppStore.load();
    expect(reloaded.moodFace(5).name, 'Szuper nap');
    expect(reloaded.moodFace(5).imageBytes, [0, 1, 2]);
    reloaded.resetMoodFace(5);
    expect(reloaded.moodFace(5).name, moodLabels[4]);
    expect(reloaded.moodFace(5).image, isNull);
  });

  testWidgets('kép kicsinyítése négyzetre; olvashatatlan képnél érthető hiba', (tester) async {
    await tester.runAsync(() async {
      // 300×200-as kép készítése
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder).drawRect(const ui.Rect.fromLTWH(0, 0, 300, 200), ui.Paint()..color = const ui.Color(0xFF5B5BD6));
      final big = await recorder.endRecording().toImage(300, 200);
      final png = (await big.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();

      final thumb = await TagImages.squareThumbnail(png);
      final decoded = (await (await ui.instantiateImageCodec(thumb)).getNextFrame()).image;
      expect([decoded.width, decoded.height], [TagImages.size, TagImages.size]);

      await expectLater(TagImages.squareThumbnail(Uint8List.fromList([1, 2, 3, 4])), throwsA(isA<UnsupportedImage>()));
    });
  });

  test('havi összefoglaló: napok, sorozat, legjobb nap, szokás, magyar ragok', () async {
    final store = await emptyStore();
    store.addHabit('Séta');
    for (var d = 1; d <= 5; d++) {
      store.saveEntry(entry(DateTime(2026, 10, d, 12), d == 3 ? 5 : 3)..gratitude = d == 3 ? 'születésnap' : '');
      store.habits.first.doneDays.add(dayKey(DateTime(2026, 10, d)));
    }
    store.saveEntry(entry(DateTime(2026, 10, 20, 12), 4));
    store.saveEntry(entry(DateTime(2026, 9, 10, 12), 2));

    final s = MonthSummary(store, DateTime(2026, 10));
    expect(s.entries.length, 6);
    expect(s.longestStreak, 5);
    expect(s.best!.gratitude, 'születésnap');
    expect(s.topHabitDays, 5);
    expect(s.previousAverage, 2);
    expect(s.monthIn, 'októberben');
    expect(MonthSummary(store, DateTime(2026, 3)).monthIn, 'márciusban');
    expect(MonthSummary(store, DateTime(2026, 3)).isEmpty, isTrue);
    expect(monthAdjective(DateTime(2026, 10)), 'az októberi');
    expect(monthAdjective(DateTime(2026, 9)), 'a szeptemberi');
  });

  test('napló keresés: ékezet nélkül is, több szóval, címkére is', () async {
    final store = await emptyStore();
    final e = entry(DateTime(2026, 10, 28), 4)
      ..gratitude = 'Hálás vagyok a napsütésért'
      ..note = 'Fociztunk Bencével'
      ..tags = ['nyugodt'];
    expect(entryMatches(e, 'halas', store), isTrue);
    expect(entryMatches(e, 'NAPSÜTÉS foci', store), isTrue);
    expect(entryMatches(e, 'nyugodt', store), isTrue);
    expect(entryMatches(e, 'foci eső', store), isFalse);
    expect(entryMatches(e, '  ', store), isTrue);
    expect(foldAccents('Őszi Ünnep'), 'oszi unnep');
  });

  test('emlék: egy éve, ha nincs, fél éve; üres bejegyzés nem számít', () async {
    final store = await emptyStore();
    final now = DateTime(2026, 10, 28);
    expect(memoryFor(store, now), isNull);
    store.saveEntry(entry(DateTime(2026, 4, 28), 4)..gratitude = 'tavaszi séta');
    expect(memoryFor(store, now)!.label, 'Fél éve ezen a napon');
    store.saveEntry(entry(DateTime(2025, 10, 28), 3)); // üres: csak hangulat
    expect(memoryFor(store, now)!.label, 'Fél éve ezen a napon');
    store.saveEntry(entry(DateTime(2025, 10, 28), 5)..note = 'Az első nap az új munkahelyen');
    final m = memoryFor(store, now)!;
    expect(m.label, 'Egy éve ezen a napon');
    expect(m.entry.note, contains('munkahely'));
  });

  test('napközbeni hangulat: napszakok átlaga, összefüggés, megmarad', () async {
    final store = await emptyStore();
    for (var d = 1; d <= 4; d++) {
      store.addCheckIn(5, DateTime(2026, 10, d, 8, 30)); // reggel jó
      store.addCheckIn(2, DateTime(2026, 10, d, 15)); // délután rossz
    }
    store.addCheckIn(4, DateTime(2026, 10, 5, 20)); // este: kevés adat
    final parts = MoodStats(store).moodByPartOfDay();
    expect(parts, {'reggel': 5.0, 'délután': 2.0});
    final texts = MoodStats(store).insights().map((i) => i.text).join('\n');
    expect(texts, contains('Reggel a legjobb a kedved (5,0), délután a legrosszabb (2,0).'));
    expect((await AppStore.load()).checkIns.length, 9);
    expect(partOfDay(DateTime(2026, 1, 1, 23)), 'éjjel');
  });

  test('év visszatekintés: legjobb hónap, sorozat, szokások, fotók', () async {
    final store = await emptyStore();
    for (var d = 1; d <= 6; d++) {
      store.saveEntry(entry(DateTime(2026, 3, d, 12), 5)..gratitude = 'tavasz $d');
      store.saveEntry(entry(DateTime(2026, 7, d, 12), 3));
    }
    store.saveEntry(entry(DateTime(2026, 8, 1, 12), 4)..moodImage = 'AAEC');
    store.saveEntry(entry(DateTime(2025, 12, 31, 12), 1));
    store.addHabit('Séta');
    store.habits.single.doneDays.addAll(['2026-03-01', '2026-03-02', '2025-12-30']);

    final r = YearReview(store, 2026);
    expect(r.entries.length, 13);
    expect(r.bestMonth, 3);
    expect(r.longestStreak, 6);
    expect(r.habitDays.single.$2, 2);
    expect(r.photos.length, 1);
    expect(r.bestDays.first.gratitude, startsWith('tavasz'));
    expect(YearReview(store, 2024).isEmpty, isTrue);
  });

  testWidgets('év visszatekintés képernyő megnyílik', (tester) async {
    await initializeDateFormatting('hu');
    SharedPreferences.setMockInitialValues({});
    final store = (await tester.runAsync(AppStore.load))!;
    store.saveEntry(entry(DateTime(2026, 3, 1, 12), 5)..gratitude = 'napsütés');
    await tester.pumpWidget(StoreScope(store: store, child: const MaterialApp(home: YearReviewScreen(year: 2026))));
    expect(find.text('2026'), findsOneWidget);
    expect(find.text('1 napot írtál le'), findsOneWidget);
  });
}
