import 'package:eletrend/models.dart';
import 'package:eletrend/screens/habit_history_screen.dart';
import 'package:eletrend/screens/habits_screen.dart';
import 'package:eletrend/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('leghosszabb sorozat és időszakos számolás', () {
    final h = Habit(id: '1', name: 'Séta', doneDays: {
      '2026-01-30', '2026-01-31', '2026-02-01', // 3 nap hónapváltáson át
      '2026-03-10', '2026-03-11', '2026-03-12', '2026-03-13', // 4 nap
      '2026-05-01',
    });
    expect(h.longestStreak(), 4);
    expect(h.doneBetween(DateTime(2026, 1, 1), DateTime(2026, 1, 31)), 2);
    expect(h.doneBetween(DateTime(2026, 1, 1), DateTime(2026, 12, 31)), 8);
    expect(Habit(id: '2', name: 'x').longestStreak(), 0);

    // Heti cél: hetente 2×; két egymást követő héten megvolt, utána egy héten nem.
    final w = Habit(id: '3', name: 'Edzés', perWeek: 2, doneDays: {
      '2026-10-05', '2026-10-07', // hétfő, szerda
      '2026-10-13', '2026-10-18', // kedd, vasárnap
      '2026-10-20', // csak egy
    });
    expect(w.longestStreak(), 2);
  });

  testWidgets('előzmények: havi naptár, pótlás koppintással, éves nézet', (tester) async {
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await initializeDateFormatting('hu');
    SharedPreferences.setMockInitialValues({'onboarded': true});
    final store = await AppStore.load();
    store.addHabit('Séta');
    final h = store.habits.first;
    final now = DateTime.now();
    final first = DateTime(now.year, now.month, 1, 12);
    store.toggleHabit(h, first);

    await tester.pumpWidget(StoreScope(store: store, child: const MaterialApp(home: HabitsScreen())));
    await tester.tap(find.text('Séta'));
    await tester.pumpAndSettle();
    expect(find.byType(HabitHistoryScreen), findsOneWidget);
    expect(find.text('nap kész'), findsOneWidget);
    expect(find.text('1'), findsWidgets);

    // A hónap 1-jére koppintva visszavonja, aztán újra kipipálja.
    final day1 = find.descendant(of: find.byType(GridView), matching: find.text('1'));
    await tester.tap(day1.first);
    await tester.pumpAndSettle();
    expect(h.isDoneOn(first), isFalse);
    await tester.tap(day1.first);
    await tester.pumpAndSettle();
    expect(h.isDoneOn(first), isTrue);

    // Éves nézet, aztán vissza egy hónapra.
    await tester.tap(find.text('Év'));
    await tester.pumpAndSettle();
    expect(find.text('${now.year}'), findsOneWidget);
    await tester.tap(find.byTooltip('Előző'));
    await tester.pumpAndSettle();
    expect(find.text('${now.year - 1}'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
