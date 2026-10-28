import 'package:eletrend/account.dart';
import 'package:eletrend/main.dart';
import 'package:eletrend/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

void main() {
  setUp(signInFakeAccount);

  setUpAll(() => initializeDateFormatting('hu'));

  test('PIN: csak hash-ként tárolva, ellenőrizhető, a mentésben nincs benne', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await AppStore.load();
    store.setPin('1234');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('pinHash'), isNot(contains('1234')));
    expect(store.checkPin('1234'), isTrue);
    expect(store.checkPin('4321'), isFalse);
    expect(store.exportBackup(), isNot(contains('pin')));

    final restarted = await AppStore.load();
    expect(restarted.journalLocked, isTrue);
    expect(restarted.journalVisible, isFalse);
  });

  testWidgets('zárolt napló: hibás PIN nem nyitja, jó PIN igen; háttérbe kerülve újra zár', (tester) async {
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({'onboarded': true});
    final store = await AppStore.load();
    store.setPin('2580');
    store.lockJournal();

    await tester.pumpWidget(EletrendApp(store: store));
    await tester.pumpAndSettle(); // a fiók adatainak betöltése
    await tester.tap(find.text('Napló'));
    await tester.pumpAndSettle();
    expect(find.text('A naplód zárolva van'), findsOneWidget);

    await tester.tap(find.text('Feloldás'));
    await tester.pumpAndSettle();
    Future<void> typePin(String pin) async {
      for (final d in pin.split('')) {
        await tester.tap(find.text(d).last);
        await tester.pump();
      }
      await tester.pumpAndSettle();
    }

    await typePin('1111');
    expect(find.text('Hibás PIN-kód'), findsOneWidget);
    await typePin('2580');
    expect(find.text('Bejegyzések'), findsNothing); // üres napló
    expect(find.textContaining('Még nincs bejegyzésed'), findsOneWidget);
    expect(store.journalVisible, isTrue);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    // Visszatérve az appba már a lakat látszik.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('A naplód zárolva van'), findsOneWidget);
    Account.instance.sync?.stop(); // a késleltetett mentés ne maradjon függőben
  });
}
