import 'package:eletrend/nudges.dart';
import 'package:eletrend/screens/nudge_screens.dart';
import 'package:eletrend/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

class _PushCounter extends NavigatorObserver {
  int pushes = 0;

  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute != null) pushes++;
  }
}

void main() {
  setUp(signInFakeAccount);
  setUpAll(() => initializeDateFormatting('hu'));

  testWidgets('bökés megnyitása: akárhányszor koppintasz egymás után, az oldal csak egyszer nyílik meg', (
    tester,
  ) async {
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});
    final store = (await tester.runAsync(AppStore.load))!;
    Nudges.instance.start('teszt', (_) {});
    final observer = _PushCounter();
    const nudge = Nudge(id: 'x_20261103_0', text: 'Szia', fromName: 'Anna');
    await tester.pumpWidget(
      StoreScope(
        store: store,
        child: MaterialApp(
          navigatorObservers: [observer],
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                // Öt gyors koppintás ugyanabban a pillanatban.
                onPressed: () {
                  for (var i = 0; i < 5; i++) {
                    openNudge(context, nudge);
                  }
                },
                child: const Text('Megnyitom'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Megnyitom'));
    await tester.pumpAndSettle();
    expect(find.byType(NudgeInboxScreen), findsOneWidget);
    expect(observer.pushes, 1); // az első után a többi koppintást figyelmen kívül hagyja

    // Egyetlen visszalépés elég: nem maradt mögötte több ugyanolyan oldal.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(NudgeInboxScreen), findsNothing);
    expect(find.text('Megnyitom'), findsOneWidget);

    // Bezárás után újra megnyitható.
    await tester.tap(find.text('Megnyitom'));
    await tester.pumpAndSettle();
    expect(find.byType(NudgeInboxScreen), findsOneWidget);
    Nudges.instance.stop();
  });
}
