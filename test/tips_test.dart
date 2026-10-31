import 'package:eletrend/main.dart';
import 'package:eletrend/tips.dart';
import 'package:eletrend/widgets/memories_demo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';
import 'widget_test.dart' show phone, readyStore, stopServices;

void main() {
  setUp(signInFakeAccount);
  setUpAll(() => initializeDateFormatting('hu'));

  test('tipp: kétnaponta másik, a bezárt nem jön vissza, bezárás után szünet', () {
    final day = DateTime(2026, 11, 10, 9);
    final a = pickTip(closed: const {}, now: day)!;
    expect(pickTip(closed: const {}, now: day.add(const Duration(hours: 10)))!.id, a.id); // aznap ugyanaz
    final ids = {for (var d = 0; d < tips.length * tipEveryDays; d++) pickTip(closed: const {}, now: day.add(Duration(days: d)))!.id};
    expect(ids.length, tips.length); // idővel mindegyik sorra kerül
    expect(pickTip(closed: {a.id}, now: day)!.id, isNot(a.id));
    expect(pickTip(closed: const {}, snoozeUntil: DateTime(2026, 11, 12), now: day), isNull);
    expect(pickTip(closed: {for (final t in tips) t.id}, now: day), isNull);
  });

  testWidgets('a Főoldalon megjelenik egy tipp, és bezárható; kikapcsolva nincs', (tester) async {
    phone(tester);
    final store = (await tester.runAsync(readyStore))!..setTipsOn(true);
    await tester.pumpWidget(LifeupApp(store: store));
    await tester.pumpAndSettle();
    expect(find.text('Tudtad?'), findsOneWidget);
    await tester.tap(find.byTooltip('Tipp bezárása'));
    await tester.pumpAndSettle();
    expect(find.text('Tudtad?'), findsNothing); // bezárás után két napig nincs újabb
    expect(store.closedTips, hasLength(1));

    SharedPreferences.resetStatic();
    store.setTipsOn(false);
    expect(store.tipsOn, isFalse);
    stopServices();
  });

  testWidgets('az emlékek animált példája egy teljes körön át hiba nélkül fut', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Center(child: SizedBox(width: 300, child: MemoriesDemo())))));
    for (var ms = 0; ms <= MemoriesDemo.loop.inMilliseconds; ms += 250) {
      await tester.pump(const Duration(milliseconds: 250));
      expect(tester.takeException(), isNull);
    }
    expect(find.text('Balatoni hétvége'), findsWidgets);
  });

  testWidgets('a fotófeltöltés animált példája végigmegy: kiválasztás, beállítás, feltöltés, kész', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Center(child: SizedBox(width: 300, child: PhotoUploadDemo())))));
    final seen = <String>{};
    for (var ms = 0; ms <= PhotoUploadDemo.loop.inMilliseconds; ms += 200) {
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
      for (final text in ['Képek kiválasztása', 'Hozzáadás (3)', '3 fotó feltöltése', 'Feltöltés: 2 / 3', 'Feltöltve: 3 fotó.']) {
        if (find.text(text).evaluate().isNotEmpty) seen.add(text);
      }
    }
    expect(seen, {'Képek kiválasztása', 'Hozzáadás (3)', '3 fotó feltöltése', 'Feltöltés: 2 / 3', 'Feltöltve: 3 fotó.'});
  });
}
