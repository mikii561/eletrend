import 'package:eletrend/main.dart';
import 'package:eletrend/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'helpers.dart';
import 'widget_test.dart' show phone, readyStore, stopServices;

void main() {
  setUp(signInFakeAccount);
  setUpAll(() => initializeDateFormatting('hu'));

  final today = DateTime.now();
  DateTime day(int offset, [int hour = 0]) => DateTime(today.year, today.month, today.day + offset, hour);

  test('elmaradt: nem kész és a napja elmúlt (határidő vagy beosztás); a mai és a kész nem', () {
    expect(TaskItem(id: 'a', title: 'A', due: day(-1)).isMissed(), isTrue);
    expect(TaskItem(id: 'b', title: 'B', scheduled: day(-2, 10)).isMissed(), isTrue);
    expect(TaskItem(id: 'c', title: 'C', due: day(0)).isMissed(), isFalse);
    expect(TaskItem(id: 'd', title: 'D', scheduled: day(0, 0)).isMissed(), isFalse);
    expect(TaskItem(id: 'e', title: 'E', due: day(-3), done: true).isMissed(), isFalse);
    expect(TaskItem(id: 'f', title: 'F').isMissed(), isFalse);

    // Áttételnél a beosztás órája marad, a lejárt határidő az új napra kerül.
    final t = TaskItem(id: 'g', title: 'G', scheduled: day(-2, 14), due: day(-2));
    t.moveToDay(day(1));
    expect(t.scheduled, day(1, 14));
    expect(t.due, day(1));
    expect(t.isMissed(), isFalse);
  });

  testWidgets('Főoldal: „Van elmaradt teendőd” → Igen: áttétel Holnapra, kész, törlés; a lap magától bezárul', (
    tester,
  ) async {
    phone(tester);
    final store = (await tester.runAsync(readyStore))!
      ..saveTask(TaskItem(id: 'a', title: 'Számla', due: day(-3)))
      ..saveTask(TaskItem(id: 'b', title: 'Beadandó', scheduled: day(-1, 14)))
      ..saveTask(TaskItem(id: 'c', title: 'Fogorvos időpont', due: day(-1)));
    await tester.pumpWidget(LifeupApp(store: store));
    await tester.pumpAndSettle();

    expect(find.text('Van 3 elmaradt teendőd'), findsOneWidget);
    expect(find.text('Szeretnéd folytatni?'), findsOneWidget);
    await tester.tap(find.text('Igen'));
    await tester.pumpAndSettle();
    expect(find.text('Elmaradt teendők'), findsOneWidget);

    // Az elsőt (a legrégebbit: Számla) holnapra tesszük.
    await tester.tap(find.text('Holnap').first);
    await tester.pumpAndSettle();
    expect(store.tasks.firstWhere((t) => t.id == 'a').due, day(1));
    expect(store.missedTasks(), hasLength(2));

    // A másodikat késznek jelöljük, a harmadikat töröljük: a lap bezárul.
    await tester.tap(find.byTooltip('Kész').first);
    await tester.pumpAndSettle();
    expect(store.missedTasks(), hasLength(1));
    await tester.tap(find.byTooltip('Törlés').first);
    await tester.pumpAndSettle();
    expect(store.missedTasks(), isEmpty);
    expect(find.text('Elmaradt teendők'), findsNothing);
    expect(find.textContaining('elmaradt teendőd'), findsNothing);
    stopServices();
  });

  testWidgets('Főoldal: Nem → megerősítés után az elmaradtak törlődnek, a többi marad', (tester) async {
    phone(tester);
    final store = (await tester.runAsync(readyStore))!
      ..saveTask(TaskItem(id: 'a', title: 'Régi', due: day(-5)))
      ..saveTask(TaskItem(id: 'b', title: 'Mai', due: day(0)));
    await tester.pumpWidget(LifeupApp(store: store));
    await tester.pumpAndSettle();

    expect(find.text('Van egy elmaradt teendőd'), findsOneWidget);
    await tester.tap(find.text('Nem, töröld'));
    await tester.pumpAndSettle();
    // Mégse: marad.
    await tester.tap(find.text('Mégse'));
    await tester.pumpAndSettle();
    expect(store.tasks, hasLength(2));

    await tester.tap(find.text('Nem, töröld'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Törlés'));
    await tester.pumpAndSettle();
    expect(store.tasks.map((t) => t.id), ['b']);
    expect(find.textContaining('elmaradt teendőd'), findsNothing);
    stopServices();
  });
}
