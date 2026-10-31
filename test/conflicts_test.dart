import 'package:eletrend/models.dart';
import 'package:eletrend/screens/event_editor.dart';
import 'package:eletrend/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

Future<AppStore> storeWithMeeting() async {
  SharedPreferences.resetStatic();
  SharedPreferences.setMockInitialValues({});
  final store = await AppStore.load();
  store.saveEvent(Event(id: 'm', title: 'Megbeszélés', start: DateTime(2030, 3, 5, 13), durationMin: 60));
  return store;
}

void main() {
  setUp(signInFakeAccount);
  setUpAll(() => initializeDateFormatting('hu'));

  test('ütközés: átfedő bejegyzés és beosztott feladat igen; érintkező, egész napos, saját maga nem', () async {
    final store = await storeWithMeeting();
    store
      ..saveTask(TaskItem(id: 't', title: 'Beadandó', scheduled: DateTime(2030, 3, 5, 13, 45), durationMin: 30))
      ..saveEvent(Event(id: 's', title: 'Szülinap', start: DateTime(2030, 3, 5), allDay: true, durationMin: 1440));

    final c = store.conflictsFor(start: DateTime(2030, 3, 5, 13, 30), durationMin: 60);
    expect(c.map((x) => x.title), ['Megbeszélés', 'Beadandó']);
    expect(c.last.task, isTrue);

    expect(store.conflictsFor(start: DateTime(2030, 3, 5, 14, 15), durationMin: 60), isEmpty); // minden véget ért már (a feladat 14:15-kor)
    expect(store.conflictsFor(start: DateTime(2030, 3, 5, 12), durationMin: 60), isEmpty); // 13:00-kor ér véget
    expect(store.conflictsFor(start: DateTime(2030, 3, 5, 13), durationMin: 60, allDay: true), isEmpty);
    expect(store.conflictsFor(start: DateTime(2030, 3, 5, 13), durationMin: 60, ignoreEventId: 'm').map((x) => x.title), ['Beadandó']);
    expect(store.conflictsFor(start: DateTime(2030, 3, 5, 13, 50), durationMin: 30, ignoreTaskId: 't').map((x) => x.title), ['Megbeszélés']);

    // Ismétlődő új bejegyzés: egy későbbi alkalma is ütközhet.
    final weekly = store.conflictsFor(
      start: DateTime(2030, 2, 26, 13, 15),
      durationMin: 30,
      repeat: Repeat.weekly,
      now: DateTime(2030, 2, 20),
    );
    expect(weekly.single.title, 'Megbeszélés');
  });

  testWidgets('új bejegyzés foglalt időpontra: figyelmeztet, és mentés előtt rákérdez', (tester) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = (await tester.runAsync(storeWithMeeting))!;
    await tester.pumpWidget(
      StoreScope(store: store, child: MaterialApp(home: EventEditor(initialStart: DateTime(2030, 3, 5, 13, 30)))),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ebben az időpontban már van programod'), findsOneWidget);
    expect(find.textContaining('Megbeszélés'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Ebéd Annával');
    await tester.tap(find.text('Mentés'));
    await tester.pumpAndSettle();
    expect(find.text('Biztosan hozzáadod így is?'), findsOneWidget);

    // Időpont módosítása: nem ment, marad a szerkesztőben.
    await tester.tap(find.text('Időpont módosítása'));
    await tester.pumpAndSettle();
    expect(store.events, hasLength(1));

    await tester.tap(find.text('Mentés'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mégis hozzáadom'));
    await tester.pumpAndSettle();
    expect(store.events.map((e) => e.title), contains('Ebéd Annával'));
  });

  testWidgets('szabad időpontnál nincs figyelmeztetés, és nem kérdez rá', (tester) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = (await tester.runAsync(storeWithMeeting))!;
    await tester.pumpWidget(
      StoreScope(store: store, child: MaterialApp(home: EventEditor(initialStart: DateTime(2030, 3, 5, 15)))),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ebben az időpontban már van programod'), findsNothing);
    await tester.enterText(find.byType(TextField).first, 'Edzés');
    await tester.tap(find.text('Mentés'));
    await tester.pumpAndSettle();
    expect(find.text('Biztosan hozzáadod így is?'), findsNothing);
    expect(store.events, hasLength(2));
  });
}
