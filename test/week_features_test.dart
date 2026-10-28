import 'package:eletrend/models.dart';
import 'package:eletrend/screens/settings_screen.dart';
import 'package:eletrend/screens/week_summary_screen.dart';
import 'package:eletrend/stats.dart';
import 'package:eletrend/store.dart';
import 'package:eletrend/widgets/nudge_cards.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

void main() {
  setUpAll(() => initializeDateFormatting('hu'));

  test('heti összefoglaló: célok, hangulat, előző hét', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await AppStore.load();
    store.addHabit('Séta');
    store.addHabit('Edzés', perWeek: 2);
    final monday = DateTime(2026, 10, 19, 12); // egy lezárt hét
    for (var i = 0; i < 5; i++) {
      store.toggleHabit(store.habits[0], addDays(monday, i));
    }
    for (var i = 0; i < 3; i++) {
      store.toggleHabit(store.habits[1], addDays(monday, i)); // 3, de a cél csak 2
    }
    store.saveEntry(JournalEntry(id: 'a', date: monday, mood: 4));
    store.saveEntry(JournalEntry(id: 'b', date: addDays(monday, 1), mood: 5));
    store.saveEntry(JournalEntry(id: 'c', date: addDays(monday, -3), mood: 2)); // előző hét

    final w = WeekSummary(store, addDays(monday, 3));
    expect(dayKey(w.monday), '2026-10-19');
    expect(w.elapsed, 7);
    expect(w.goalsDone, 5 + 2);
    expect(w.goalsPossible, 7 + 2);
    expect(w.goalPercent, 78);
    expect(w.average, 4.5);
    expect(w.previousAverage, 2);
    expect(w.bestGoal!.name, 'Séta');
    expect(w.entries.length, 2);
  });

  testWidgets('esti kártya csak a beállított idő után és napló nélkül', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = await AppStore.load();
    Widget app(DateTime now) => StoreScope(
          store: store,
          child: MaterialApp(home: Scaffold(body: TodayNudges(now: now))),
        );

    await tester.pumpWidget(app(DateTime(2026, 10, 28, 19, 59)));
    expect(find.text('Este van: írd meg a mai naplót'), findsNothing);
    await tester.pumpWidget(app(DateTime(2026, 10, 28, 20, 1)));
    expect(find.text('Este van: írd meg a mai naplót'), findsOneWidget);

    store.saveEntry(JournalEntry(id: 'x', date: DateTime(2026, 10, 28, 12), mood: 3));
    await tester.pump();
    expect(find.text('Este van: írd meg a mai naplót'), findsNothing);
  });

  testWidgets('heti kártya vasárnap este, bezárható, megnyitja az összefoglalót', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = await AppStore.load();
    store.addHabit('Séta');
    final sunday = DateTime(2026, 10, 25, 18);
    store.toggleHabit(store.habits[0], sunday);
    // Az esti napló-kártya ne zavarjon.
    store.setReminders(daily: false);

    await tester.pumpWidget(
      StoreScope(store: store, child: MaterialApp(home: Scaffold(body: TodayNudges(now: sunday)))),
    );
    expect(find.text('Így ment a heted'), findsOneWidget);
    await tester.tap(find.text('Így ment a heted'));
    await tester.pumpAndSettle();
    expect(find.byType(WeekSummaryScreen), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Bezárás'));
    await tester.pump();
    expect(find.text('Így ment a heted'), findsNothing);

    // Szerdán nincs kártya.
    store.closeWeekCard('');
    await tester.pumpWidget(
      StoreScope(
        store: store,
        child: MaterialApp(home: Scaffold(body: TodayNudges(now: DateTime(2026, 10, 28, 18)))),
      ),
    );
    expect(find.text('Így ment a heted'), findsNothing);
  });

  testWidgets('beállítások: csoportok, funkció kikapcsolása megmarad', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    signInFakeAccount();
    SharedPreferences.setMockInitialValues({});
    final store = await AppStore.load();
    await tester.pumpWidget(StoreScope(store: store, child: const MaterialApp(home: SettingsScreen())));
    await tester.pumpAndSettle();

    expect(find.text('Értesítések'), findsOneWidget);
    await tester.tap(find.text('Funkciók'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Közös kihívások'));
    await tester.pump();
    expect(store.shows(Feature.challenges), isFalse);
    expect((await AppStore.load()).shows(Feature.challenges), isFalse);
    expect(store.cloudSettings()['hiddenFeatures'], ['challenges']);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('${Feature.values.length - 1}/${Feature.values.length} bekapcsolva · azt lásd, amit használsz'),
        findsOneWidget);
  });

  testWidgets('heti összefoglaló képernyő lapozható, nem lép a jövőbe', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final store = await AppStore.load();
    store.addHabit('Olvasás');
    store.toggleHabit(store.habits[0]);
    store.saveEntry(JournalEntry(id: 'g', date: DateTime.now(), mood: 4, gratitude: 'A napsütés'));

    await tester.pumpWidget(StoreScope(store: store, child: const MaterialApp(home: WeekSummaryScreen())));
    expect(find.text('A napsütés'), findsOneWidget);
    expect(tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.chevron_right)).onPressed, isNull);
    await tester.tap(find.byTooltip('Előző hét'));
    await tester.pumpAndSettle();
    expect(find.text('A napsütés'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
