import 'package:eletrend/models.dart';
import 'package:eletrend/notifications.dart';
import 'package:eletrend/screens/habits_screen.dart';
import 'package:eletrend/screens/today_screen.dart' show habitProgress;
import 'package:eletrend/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<AppStore> emptyStore() async {
    SharedPreferences.setMockInitialValues({});
    return AppStore.load();
  }

  test('mennyiségi cél: 8 pohár víz, a nyolcadiknál kész; visszavonható', () async {
    final store = await emptyStore();
    store.addHabit('Víz', target: 8, unit: 'pohár');
    final h = store.habits.single;
    final day = DateTime(2026, 10, 28, 9);
    for (var i = 0; i < 7; i++) {
      store.toggleHabit(h, day);
    }
    expect(h.isDoneOn(day), isFalse);
    expect(habitProgress(h, day), '7/8 pohár');
    expect(Notifications.habitReminderBody(h, day), 'Még 1 pohár van hátra mára. 💪');
    store.toggleHabit(h, day);
    expect(h.isDoneOn(day), isTrue);
    store.decrementHabit(h, day);
    expect(h.isDoneOn(day), isFalse);
    expect(h.countOn(day), 7);
    // Kész napon a koppintás nulláz
    store.toggleHabit(h, day);
    store.toggleHabit(h, day);
    expect(h.countOn(day), 0);

    final reloaded = await AppStore.load();
    expect(reloaded.habits.single.target, 8);
    expect(reloaded.habits.single.unit, 'pohár');
  });

  test('heti cél: hetente 3×; a sorozat hetekben számol; a hét többi napján nem „marad el”', () async {
    final store = await emptyStore();
    store.addHabit('Edzés', perWeek: 3, reminderMinutes: 18 * 60);
    final h = store.habits.single;
    // 2026.10.19 (hétfő) hete: 3 edzés; 10.26 hete: 3 edzés (hétfő, kedd, szerda)
    for (final d in [19, 21, 23, 26, 27, 28]) {
      h.doneDays.add(dayKey(DateTime(2026, 10, d)));
    }
    final thursday = DateTime(2026, 10, 29, 12);
    expect(h.doneInWeek(thursday), 3);
    expect(h.isSatisfiedOn(thursday), isTrue); // csütörtökön már nem kell
    expect(h.streak(thursday), 2);
    expect(h.streakUnit, 'hét');
    expect(habitProgress(h, thursday), '3/3 ezen a héten');

    // A következő héten (hétfőn) még nincs meg, de a sorozat nem nullázódik
    final nextMonday = DateTime(2026, 11, 2, 12);
    expect(h.isSatisfiedOn(nextMonday), isFalse);
    expect(h.streak(nextMonday), 2);
    expect(Notifications.habitReminderBody(h, nextMonday), 'Ezen a héten még 3× van hátra. 💪');

    final reloaded = await AppStore.load();
    expect(reloaded.habits.single.perWeek, 3);
    expect(reloaded.habits.single.reminderMinutes, 18 * 60);
  });

  test('régi (egyszerű) cél változatlanul működik', () async {
    final store = await emptyStore();
    store.addHabit('Olvasás');
    final h = store.habits.single;
    store.toggleHabit(h, DateTime(2026, 10, 28));
    expect(h.isDoneOn(DateTime(2026, 10, 28)), isTrue);
    expect(habitProgress(h, DateTime(2026, 10, 28)), isNull);
    expect(Habit.fromJson({'id': 'x', 'name': 'Régi', 'doneDays': ['2026-10-01']}).target, 1);
  });

  testWidgets('cél-szerkesztő: heti, mennyiségi; a + gomb számol', (tester) async {
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await initializeDateFormatting('hu');
    final store = (await tester.runAsync(emptyStore))!;
    await tester.pumpWidget(StoreScope(store: store, child: const MaterialApp(home: HabitsScreen())));

    await tester.tap(find.text('Új cél'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Név'), 'Víz');
    await tester.tap(find.text('Mennyiség naponta'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Egység'), 'pohár');
    await tester.ensureVisible(find.text('Mentés'));
    await tester.tap(find.text('Mentés'));
    await tester.pumpAndSettle();
    expect(store.habits.single.target, 8);
    expect(find.text('0/8 pohár'), findsOneWidget);

    await tester.tap(find.byTooltip('Még egy'));
    await tester.tap(find.byTooltip('Még egy'));
    await tester.pump();
    expect(find.text('2/8 pohár'), findsOneWidget);

    // Szerkesztés: hetente 3×
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Szerkesztés'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hetente'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Mentés'));
    await tester.tap(find.text('Mentés'));
    await tester.pumpAndSettle();
    expect(store.habits.single.perWeek, 3);
    expect(find.textContaining('ezen a héten'), findsOneWidget);
  });

  testWidgets('sablon: egy koppintással felvehető, kétszer nem duplikál', (tester) async {
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await initializeDateFormatting('hu');
    final store = (await tester.runAsync(emptyStore))!;
    await tester.pumpWidget(StoreScope(store: store, child: const MaterialApp(home: HabitsScreen())));

    Future<void> addFirstPack() async {
      await tester.tap(find.text('Sablonok'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Felvétel').first);
      await tester.pumpAndSettle();
    }

    await addFirstPack();
    expect(store.habits.length, 4);
    expect(store.habits.first.name, contains('víz'));
    await addFirstPack();
    expect(store.habits.length, 4);
    expect(find.text('Ezek már mind megvannak. 🙂'), findsOneWidget);
  });

  testWidgets('légzőgyakorlat: 1 perc után kész, és kipipálja a meditációt', (tester) async {
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await initializeDateFormatting('hu');
    final store = (await tester.runAsync(emptyStore))!;
    store.addHabit('🧘 5 perc meditáció');
    await tester.pumpWidget(StoreScope(store: store, child: const MaterialApp(home: HabitsScreen())));
    await tester.tap(find.byTooltip('Légzőgyakorlat'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('1 perc'));
    await tester.pump();
    await tester.scrollUntilVisible(find.text('Indítás'), 300);
    await tester.tap(find.text('Indítás'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Belégzés'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Tartsd'), findsOneWidget);
    await tester.pump(const Duration(seconds: 56));
    await tester.pump();
    expect(find.text('Kész! Szép munka.'), findsOneWidget);
    expect(store.habits.single.isDoneOn(DateTime.now()), isTrue);
  });
}
