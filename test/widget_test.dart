import 'package:eletrend/account.dart';
import 'package:eletrend/challenges.dart';
import 'package:eletrend/friends.dart';
import 'package:eletrend/main.dart';
import 'package:eletrend/models.dart';
import 'package:eletrend/screens/today_screen.dart';
import 'package:eletrend/store.dart';
import 'package:eletrend/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

void main() {
  setUp(signInFakeAccount);

  setUpAll(() => initializeDateFormatting('hu'));

  test('sorozat számolása tegnaptól, ha ma még nincs kész', () {
    final now = DateTime(2026, 10, 27);
    final h = Habit(id: '1', name: 'Víz', doneDays: {'2026-10-25', '2026-10-26'});
    expect(h.streak(now), 2);
    h.doneDays.add('2026-10-27');
    expect(h.streak(now), 3);
  });

  test('emlékeztető beállítások megmaradnak újraindítás után', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await AppStore.load();
    expect(store.dailyReminder, isTrue);
    expect(store.reminderTime, const TimeOfDay(hour: 20, minute: 0));

    store.setReminders(daily: false, time: const TimeOfDay(hour: 21, minute: 30), events: false);
    final reloaded = await AppStore.load();
    expect(reloaded.dailyReminder, isFalse);
    expect(reloaded.reminderTime, const TimeOfDay(hour: 21, minute: 30));
    expect(reloaded.eventReminders, isFalse);
  });

  testWidgets('a főoldal betölt és a cél kipipálható', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = await AppStore.load();
    store.addHabit('Olvasás');

    await tester.pumpWidget(EletrendApp(store: store));
    await tester.pumpAndSettle(); // a fiók adatainak betöltése
    expect(find.text('Mai célok'), findsOneWidget);
    expect(find.text('Olvasás'), findsOneWidget);

    await tester.ensureVisible(find.byType(CheckCircle));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CheckCircle));
    await tester.pump();
    expect(store.habits.first.isDoneOn(DateTime.now()), isTrue);

    // Gyors hangulat a főoldalon
    // (a „Hogy vagy most?” kártyán is vannak arcok, ezért a napi hangulat gombjait keressük)
    await tester.ensureVisible(find.byType(MoodButton).at(3));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(MoodButton).at(3));
    await tester.pump();
    expect(store.entryFor(DateTime.now())?.mood, 4);

    await tester.tap(find.text('Napló'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Bejegyzések'), findsOneWidget);
    Account.instance.sync?.stop(); // a késleltetett mentés ne maradjon függőben
    Friends.instance.stop();
    Challenges.instance.stop();
  });

  testWidgets('első indításkor bemutató, a kiválasztott célok felkerülnek', (tester) async {
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final store = await AppStore.load();
    await tester.pumpWidget(EletrendApp(store: store));
    await tester.pumpAndSettle(); // a fiók adatainak betöltése
    expect(find.text('Üdv az Életrendben!'), findsOneWidget);

    await tester.tap(find.text('📖 10 perc olvasás'));
    await tester.pump();
    await tester.tap(find.text('Tovább 3 céllal'));
    await tester.pumpAndSettle();
    expect(find.text('Egy perc este'), findsOneWidget);
    await tester.tap(find.text('Tovább'));
    await tester.pumpAndSettle();
    // A harmadik lépésben kikapcsolt funkció eltűnik az appból.
    await tester.tap(find.text('Időjárás'));
    await tester.pump();
    expect(store.shows(Feature.weather), isFalse);
    await tester.tap(find.text('Kezdjük!'));
    await tester.pumpAndSettle();

    expect(find.text('Mai célok'), findsOneWidget);
    expect(store.habits.map((h) => h.name), ['💧 2 liter víz', '🚶 10 perc séta', '📖 10 perc olvasás']);
    expect((await AppStore.load()).onboarded, isTrue);
    Account.instance.sync?.stop(); // a késleltetett mentés ne maradjon függőben
    Friends.instance.stop();
    Challenges.instance.stop();
  });

  testWidgets('sötét mód bekapcsolása azonnal átszínezi az appot', (tester) async {
    SharedPreferences.setMockInitialValues({'onboarded': true});
    final store = await AppStore.load();
    await tester.pumpWidget(EletrendApp(store: store));
    await tester.pumpAndSettle(); // a fiók adatainak betöltése
    expect(AppColors.dark, isFalse);

    store.setThemeMode(ThemeMode.dark);
    await tester.pumpAndSettle();
    expect(AppColors.dark, isTrue);
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).last);
    expect(Theme.of(tester.element(find.byWidget(scaffold))).brightness, Brightness.dark);

    store.setThemeMode(ThemeMode.light);
    await tester.pumpAndSettle();
    expect(AppColors.dark, isFalse);
    Account.instance.sync?.stop(); // a késleltetett mentés ne maradjon függőben
    Friends.instance.stop();
    Challenges.instance.stop();
  });

  testWidgets('alsó sáv: a Barátok külön fül', (tester) async {
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({'onboarded': true});
    final store = await AppStore.load();
    await tester.pumpWidget(EletrendApp(store: store));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Barátok'));
    await tester.pumpAndSettle();
    expect(find.text('Kapott bumpok'), findsOneWidget);
    await tester.dragUntilVisible(find.text('Csak név szerint'), find.byType(ListView).first, const Offset(0, -300));
    expect(find.text('Csak név szerint'), findsOneWidget);
    Account.instance.sync?.stop();
    Friends.instance.stop();
    Challenges.instance.stop();
  });

  testWidgets('jelvények: a már meglévők miatt nincs ünneplés az első indításkor', (tester) async {
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({'onboarded': true});
    final store = await AppStore.load();
    store.addHabit('Olvasás');
    store.saveEntry(JournalEntry(id: '1', date: DateTime(2026, 10, 1), mood: 4));
    await tester.pumpWidget(EletrendApp(store: store));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.textContaining('Új jelvény'), findsNothing);
    expect(store.seenBadges, containsAll(['first_entry', 'first_habit']));
    Account.instance.sync?.stop();
    Friends.instance.stop();
    Challenges.instance.stop();
  });
}
