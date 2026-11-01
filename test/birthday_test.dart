import 'package:eletrend/screens/profile_screen.dart';
import 'package:eletrend/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

void main() {
  setUp(signInFakeAccount);
  setUpAll(() => initializeDateFormatting('hu'));

  testWidgets('profil: a születésnap kerekekkel adható meg, beírni semmit nem kell', (tester) async {
    tester.view.physicalSize = const Size(400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});
    final store = (await tester.runAsync(AppStore.load))!;
    await tester.pumpWidget(
      StoreScope(
        store: store,
        child: const MaterialApp(home: ProfileScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Születésnap megadása'));
    await tester.pumpAndSettle();
    expect(find.text('Mikor van a születésnapod?'), findsOneWidget);
    expect(find.byType(TextField), findsNothing); // nincs beírandó mező, így formátum sem kell
    await tester.tap(find.text('Kész'));
    await tester.pumpAndSettle();
    expect(store.birthday, '2000-01-01');
    expect(find.text('2000. január 1.'), findsOneWidget);

    // Mégse: nem változik.
    await tester.tap(find.text('2000. január 1.'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mégse'));
    await tester.pumpAndSettle();
    expect(store.birthday, '2000-01-01');
  });
}
