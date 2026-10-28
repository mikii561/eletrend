import 'dart:math';

import 'package:eletrend/calendar_link.dart';
import 'package:eletrend/costs.dart';
import 'package:eletrend/ideas.dart';
import 'package:eletrend/models.dart';
import 'package:eletrend/screens/events_screen.dart';
import 'package:eletrend/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('ismétlődő programok', () {
    final foci = Event(id: '1', title: 'Foci', date: DateTime(2026, 10, 1, 18), repeat: Repeat.weekly); // csütörtök

    test('a következő alkalom a mai naptól, ugyanazon a napon és órában', () {
      expect(foci.nextDate(DateTime(2026, 10, 28, 9)), DateTime(2026, 10, 29, 18));
      expect(foci.nextDate(DateTime(2026, 10, 29, 20)), DateTime(2026, 10, 29, 18)); // ma még látszik
      expect(foci.nextDate(DateTime(2026, 10, 30)), DateTime(2026, 11, 5, 18));
      expect(foci.occursOn(DateTime(2026, 10, 22)), isTrue);
      expect(foci.occursOn(DateTime(2026, 10, 23)), isFalse);
      expect(foci.occursOn(DateTime(2026, 9, 24)), isFalse); // az első alkalom előtt
    });

    test('havonta: rövidebb hónapban az utolsó napra esik', () {
      final e = Event(id: '2', title: 'Klub', date: DateTime(2026, 1, 31, 19), repeat: Repeat.monthly);
      expect(e.nextDate(DateTime(2026, 2, 10)), DateTime(2026, 2, 28, 19));
      expect(e.nextDate(DateTime(2026, 3, 1)), DateTime(2026, 3, 31, 19));
    });

    test('mentés után is megmarad, és a közelgők között az ismétlődő is ott van', () async {
      SharedPreferences.setMockInitialValues({});
      final store = await AppStore.load();
      store.saveEvent(foci);
      store.saveEvent(Event(id: '3', title: 'Régi', date: DateTime(2020, 1, 1)));
      final reloaded = await AppStore.load();
      expect(reloaded.events.first.repeat, Repeat.weekly);
      expect(reloaded.upcomingEvents.map((e) => e.title), ['Foci']);
    });
  });

  group('költségmegosztás', () {
    test('ki kinek tartozik, a lehető legkevesebb utalással', () {
      final e = Event(id: '1', title: 'Pizza', date: DateTime(2026, 10, 30), invited: ['Anna', 'Bence']);
      e.expenses.addAll([
        Expense(id: 'a', title: 'pizza', amount: 9000, payer: me, shares: [me, 'Anna', 'Bence']),
        Expense(id: 'b', title: 'üdítő', amount: 1500, payer: 'Anna', shares: [me, 'Anna', 'Bence']),
      ]);
      final split = CostSplit(e);
      expect(split.total, 10500);
      expect(split.balances(), {me: 5500, 'Anna': -2000, 'Bence': -3500});
      final t = split.settle();
      expect(t.map((x) => '${x.from}->${x.to}:${x.amount}'), ['Bence->Én:3500', 'Anna->Én:2000']);
    });

    test('kerekítés: a végösszeg pontosan nulla', () {
      final e = Event(id: '1', title: 'Mozi', date: DateTime(2026, 10, 30), invited: ['Anna', 'Bence']);
      e.expenses.add(Expense(id: 'a', title: '', amount: 1000, payer: 'Anna', shares: [me, 'Anna', 'Bence']));
      final b = CostSplit(e).balances();
      expect(b.values.reduce((a, c) => a + c), 0);
      expect(CostSplit(e).settle().fold(0, (s, t) => s + t.amount), 667);
      expect(formatFt(12500), '12 500 Ft'); // nem törhető szóköz
    });
  });

  test('ötletadó: a szűrőknek megfelelő, és nem ugyanaz kétszer', () {
    final random = Random(1);
    final first = randomIdea({IdeaTag.outside, IdeaTag.cheap}, random: random)!;
    expect(first.tags, containsAll([IdeaTag.outside, IdeaTag.cheap]));
    for (var i = 0; i < 20; i++) {
      expect(randomIdea({IdeaTag.outside, IdeaTag.cheap}, not: first, random: random), isNot(first));
    }
    expect(randomIdea({...IdeaTag.values}), isNull);
  });

  testWidgets('képernyők: ötletből program, kiadás felírása, elszámolás', (tester) async {
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await initializeDateFormatting('hu');
    SharedPreferences.setMockInitialValues({'onboarded': true});
    final store = await AppStore.load();
    store.addFriend('Anna');

    await tester.pumpWidget(StoreScope(store: store, child: const MaterialApp(home: EventsScreen())));
    await tester.tap(find.text('🎲 Ötletet kérek'));
    await tester.pumpAndSettle();
    expect(find.text('Mit csináljunk?'), findsOneWidget);
    await tester.tap(find.text('Ezt szervezem!'));
    await tester.pumpAndSettle();
    expect(find.text('Új program'), findsOneWidget);
    await tester.tap(find.text('Anna'));
    await tester.tap(find.text('Mentés'));
    await tester.pumpAndSettle();
    expect(store.events.single.invited, ['Anna']);

    await tester.tap(find.byType(EventCard));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Ki mit fizetett? Írd fel!'), 200);
    await tester.ensureVisible(find.text('Ki mit fizetett? Írd fel!'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ki mit fizetett? Írd fel!'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'jegyek');
    await tester.enterText(find.byType(TextField).at(1), '4000');
    await tester.tap(find.text('Mentés').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Elszámolás'), 200);
    expect(find.text('Anna'), findsWidgets);
    expect(find.text('2 000 Ft'), findsOneWidget);
    expect((await AppStore.load()).events.single.expenses.single.amount, 4000);
  });

  test('naptár link: UTC idő, 2 óra, helyszín, heti ismétlődés', () {
    final link = googleCalendarLink(
      title: 'Foci',
      start: DateTime.utc(2026, 11, 5, 17),
      place: 'Margitsziget',
      repeat: Repeat.weekly,
    );
    expect(link.host, 'calendar.google.com');
    expect(link.queryParameters['dates'], '20261105T170000Z/20261105T190000Z');
    expect(link.queryParameters['location'], 'Margitsziget');
    expect(link.queryParameters['recur'], 'RRULE:FREQ=WEEKLY');
    expect(googleCalendarLink(title: 'x', start: DateTime.utc(2026)).queryParameters.containsKey('recur'), isFalse);
  });
}
