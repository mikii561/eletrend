import 'package:eletrend/main.dart';
import 'package:eletrend/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'helpers.dart';
import 'widget_test.dart' show phone, readyStore, stopServices;

void main() {
  setUp(signInFakeAccount);
  setUpAll(() => initializeDateFormatting('hu'));

  testWidgets('Főoldal: „Teendők mára”, külön a mai és a holnapi, mellette „1 ma · 2 holnap”', (tester) async {
    phone(tester);
    final store = (await tester.runAsync(readyStore))!;
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1, 12);
    store
      ..saveTask(TaskItem(id: 'a', title: 'Számla befizetése', due: DateTime(now.year, now.month, now.day, 12)))
      ..saveTask(TaskItem(id: 'b', title: 'Ajándék Anyunak', due: tomorrow))
      ..saveTask(TaskItem(id: 'c', title: 'Edzőterem bérlet', due: tomorrow))
      ..saveTask(TaskItem(id: 'd', title: 'Valamikor', due: DateTime(now.year, now.month, now.day + 5, 12)));

    await tester.pumpWidget(LifeupApp(store: store));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Teendők mára'), 200);
    await tester.pumpAndSettle();
    expect(find.text('1 ma · 2 holnap'), findsOneWidget);
    expect(find.text('Ma'), findsWidgets);
    expect(find.text('Holnap'), findsOneWidget);
    expect(find.text('Ajándék Anyunak'), findsOneWidget);
    expect(find.text('Valamikor'), findsNothing); // 5 nap múlva: nem ide tartozik

    // A mai kész: már csak a holnapiak számítanak.
    store.toggleTask(store.tasks.firstWhere((t) => t.id == 'a'));
    await tester.pumpAndSettle();
    expect(find.text('2 holnap'), findsOneWidget);
    stopServices();
  });
}
