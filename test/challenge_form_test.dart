import 'package:eletrend/challenges.dart';
import 'package:eletrend/friends.dart';
import 'package:eletrend/screens/challenges_screen.dart';
import 'package:eletrend/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

void main() {
  setUp(signInFakeAccount);
  setUpAll(() => initializeDateFormatting('hu'));

  testWidgets('új kihívás: ötletek mellett saját név, emoji és napszám', (tester) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});
    final store = (await tester.runAsync(AppStore.load))!..setMyName('Gabi');
    Challenges.instance.start('teszt', store);
    await tester.runAsync(() => Friends.instance.start('teszt', store));
    await tester.pumpWidget(
      StoreScope(
        store: store,
        child: const MaterialApp(home: ChallengesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Új kihívás'));
    await tester.pumpAndSettle();
    // Az ötletek megvannak, mellettük a saját kép és emoji.
    expect(find.text('🏋️ 30 nap edzés'), findsOneWidget);
    expect(find.text('Kép a galériából'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Név (vagy írj sajátot)'), 'Saját futás');
    await tester.enterText(find.widgetWithText(TextField, 'Emoji'), '🏃');
    await tester.enterText(find.widgetWithText(TextField, 'Vagy írd be a napok számát'), '100');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Kihívás indítása'));
    await tester.tap(find.text('Kihívás indítása'));
    await tester.pumpAndSettle();

    final c = (await tester.runAsync(() => Challenges.instance.watchMine().first))!.single;
    expect([c.title, c.emoji, c.days, c.image], ['Saját futás', '🏃', 100, '']);
    Challenges.instance.stop();
    Friends.instance.stop();
  });

  testWidgets('új kihívás: 0 vagy túl sok nap nem indul el', (tester) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});
    final store = (await tester.runAsync(AppStore.load))!..setMyName('Gabi');
    Challenges.instance.start('teszt', store);
    await tester.runAsync(() => Friends.instance.start('teszt', store));
    await tester.pumpWidget(
      StoreScope(
        store: store,
        child: const MaterialApp(home: ChallengesScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Új kihívás'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Vagy írd be a napok számát'), '0');
    await tester.ensureVisible(find.text('Kihívás indítása'));
    await tester.tap(find.text('Kihívás indítása'));
    await tester.pump();
    expect(find.textContaining('1 és $maxChallengeDays'), findsOneWidget);
    expect(await tester.runAsync(() => Challenges.instance.watchMine().first), isEmpty);
    Challenges.instance.stop();
    Friends.instance.stop();
  });
}
