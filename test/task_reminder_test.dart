import 'package:eletrend/main.dart';
import 'package:eletrend/models.dart';
import 'package:eletrend/notifications.dart';
import 'package:eletrend/screens/task_editor.dart';
import 'package:eletrend/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';
import 'widget_test.dart' show phone, readyStore, stopServices;

void main() {
  setUp(signInFakeAccount);
  setUpAll(() => initializeDateFormatting('hu'));

  test('feladat értesítése: választott idővel előtte; „Nincs értesítés” esetén semmi; határidősnél 9-kor', () async {
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});
    final store = await AppStore.load();
    final now = DateTime(2030, 3, 5, 8);
    store
      ..saveTask(TaskItem(id: 'a', title: 'Beadandó', scheduled: DateTime(2030, 3, 5, 14), durationMin: 90, reminderMin: 60))
      ..saveTask(TaskItem(id: 'b', title: 'Csendes', scheduled: DateTime(2030, 3, 5, 16), reminderMin: null))
      ..saveTask(TaskItem(id: 'c', title: 'Számla', due: DateTime(2030, 3, 6, 12)))
      ..saveTask(TaskItem(id: 'd', title: 'Nem kell szólni', due: DateTime(2030, 3, 6, 12), reminderMin: null));
    final plan = {for (final p in Notifications.plan(store, now)) p.title: p};
    expect(plan['1 óra múlva: Beadandó']!.when, DateTime(2030, 3, 5, 13));
    expect(plan['1 óra múlva: Beadandó']!.body, contains('14:00-kor'));
    expect(plan['Ma a határidő: Számla']!.when, DateTime(2030, 3, 6, 9));
    expect(plan.keys.where((k) => k.contains('Csendes') || k.contains('Nem kell szólni')), isEmpty);

    // Régebbi (mező nélküli) feladat: a korábbi viselkedés marad, a kezdéskor szól.
    final old = TaskItem.fromJson({'id': 'x', 'title': 'Régi', 'scheduled': '2030-03-05T10:00:00.000'});
    expect(old.reminderMin, 0);
    expect(TaskItem.fromJson(store.tasks.firstWhere((t) => t.id == 'b').toJson()).reminderMin, isNull);
  });

  testWidgets('Főoldal: a következő program akkor is látszik (perc múlva), ha nem kér értesítést', (tester) async {
    phone(tester);
    final store = (await tester.runAsync(readyStore))!;
    final now = DateTime.now();
    store.saveEvent(Event(id: 'e', title: 'Fogorvos', start: now.add(const Duration(minutes: 41)), reminderMin: null));
    await tester.pumpWidget(LifeupApp(store: store));
    await tester.pumpAndSettle();
    expect(find.text('Következő'), findsOneWidget);
    expect(find.text('Fogorvos'), findsWidgets);
    expect(find.textContaining('perc múlva'), findsOneWidget);
    stopServices();
  });

  testWidgets('Főoldal: a beosztott feladat is lehet a „Következő”, ha az jön előbb', (tester) async {
    phone(tester);
    final store = (await tester.runAsync(readyStore))!;
    final now = DateTime.now();
    store
      ..saveEvent(Event(id: 'e', title: 'Edzés', start: now.add(const Duration(hours: 3))))
      ..saveTask(TaskItem(id: 't', title: 'Beadandó írása', scheduled: now.add(const Duration(minutes: 20)), reminderMin: null));
    await tester.pumpWidget(LifeupApp(store: store));
    await tester.pumpAndSettle();
    final card = find.ancestor(of: find.text('Következő'), matching: find.byType(Card));
    expect(find.descendant(of: card, matching: find.text('Beadandó írása')), findsOneWidget);
    expect(find.descendant(of: card, matching: find.textContaining('perc múlva')), findsOneWidget);
    stopServices();
  });

  testWidgets('feladat-szerkesztő: beosztott feladatnál választható a „Nincs értesítés”', (tester) async {
    phone(tester);
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});
    final store = (await tester.runAsync(AppStore.load))!;
    final task = TaskItem(id: 't', title: 'Beadandó', scheduled: DateTime(2030, 3, 5, 14), reminderMin: 30);
    store.saveTask(task);
    await tester.pumpWidget(
      StoreScope(
        store: store,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(onPressed: () => showTaskEditor(context, task: task), child: const Text('Nyit')),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Nyit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('30 perccel előtte'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nincs értesítés').last);
    await tester.pumpAndSettle();
    expect(find.text('A Főoldalon így is látszik, csak nem jön értesítés.'), findsOneWidget);
    await tester.tap(find.text('Mentés'));
    await tester.pumpAndSettle();
    expect(store.tasks.single.reminderMin, isNull);
  });
}
