import 'package:eletrend/account.dart';
import 'package:eletrend/availability_service.dart';
import 'package:eletrend/challenges.dart';
import 'package:eletrend/friends.dart';
import 'package:eletrend/main.dart';
import 'package:eletrend/models.dart';
import 'package:eletrend/nudges.dart';
import 'package:eletrend/screens/calendar_screen.dart';
import 'package:eletrend/store.dart';
import 'package:eletrend/theme.dart';
import 'package:eletrend/widgets/goal_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

/// Egy már bevezetőn átesett felhasználó.
Future<AppStore> readyStore() async {
  SharedPreferences.resetStatic();
  SharedPreferences.setMockInitialValues({});
  final store = await AppStore.load();
  store
    ..finishOnboarding(name: 'Gabi')
    ..setTourDone(true)
    ..setTipsOn(false);
  return store;
}

void stopServices() {
  Account.instance.sync?.stop();
  Friends.instance.stop();
  Challenges.instance.stop();
  Nudges.instance.stop();
  AvailabilityService.instance.stop();
}

void phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 860);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  setUp(signInFakeAccount);
  setUpAll(() => initializeDateFormatting('hu'));

  testWidgets('bevezető: üdvözlés, első lépések, születésnap, barátok, név és profilkép, kész, majd a bemutató', (
    tester,
  ) async {
    phone(tester);
    SharedPreferences.setMockInitialValues({});
    final store = (await tester.runAsync(AppStore.load))!..beginOnboarding(); // új regisztráció
    await tester.pumpWidget(LifeupApp(store: store));
    await tester.pumpAndSettle();
    expect(find.text('Üdvözlünk a LIFEUP alkalmazásban!'), findsOneWidget);

    await tester.tap(find.text('Tovább'));
    await tester.pumpAndSettle();
    expect(find.text('Első lépések'), findsOneWidget);
    expect(find.text('Beállítom később'), findsOneWidget);
    await tester.tap(find.text('Tovább'));
    await tester.pumpAndSettle();

    // Születésnap és barátok: kihagyhatók.
    expect(find.text('Mikor van a születésnapod?'), findsOneWidget);
    await tester.tap(find.text('Kihagyom'));
    await tester.pumpAndSettle();
    expect(find.text('Barátok felvétele'), findsOneWidget);
    await tester.tap(find.text('Kihagyom'));
    await tester.pumpAndSettle();

    // Név nélkül nem megy tovább.
    expect(find.text('Profilkép és név'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '');
    await tester.tap(find.text('Tovább'));
    await tester.pump();
    expect(find.textContaining('Hogy szólíthatunk?'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Anna');
    await tester.tap(find.text('Tovább'));
    await tester.pumpAndSettle();

    // Mentve, de a bevezető még a „kész” oldalon áll.
    expect(find.text('Kész is vagyunk!'), findsOneWidget);
    expect(store.myName, 'Anna');
    expect(store.onboarded, isFalse);
    await tester.tap(find.text('Tovább'));
    await tester.pumpAndSettle();
    expect(store.onboarded, isTrue);
    expect(store.shareAvailability, AvailabilityShare.nobody);
    expect(find.text('Főoldal'), findsWidgets); // az alsó menü (és a bemutató)

    // Rögtön jön a bemutató: végig lehet lépkedni rajta.
    expect(find.text('Tovább'), findsOneWidget);
    // (Az Emlékek lépésben végtelenített animáció fut, ezért itt nem várunk teljes megállásra.)
    for (final title in [
      'Főoldal',
      'Az állapotod',
      'Gyors gombok',
      'Naptár',
      'Létrehozás',
      'Barátok',
      'Közös fotók',
      'Emlékek',
      'Profil',
    ]) {
      await tester.tap(find.text('Tovább'));
      // Néhány képkocka, amíg a kártyák közti átúszás lezajlik (a régi kártya csak utána tűnik el).
      for (var f = 0; f < 4; f++) {
        await tester.pump(const Duration(milliseconds: 300));
      }
      expect(find.text(title), findsWidgets);
      expect(tester.takeException(), isNull);
    }
    await tester.tap(find.text('Kezdjük!'));
    await tester.pumpAndSettle();
    expect(store.tourDone, isTrue);
    expect(find.text('Kezdjük!'), findsNothing);
    stopServices();
  });

  testWidgets('bevezető: „Beállítom később” – egyből a kész oldal, név a fiókból, a bemutató jön', (tester) async {
    phone(tester);
    SharedPreferences.setMockInitialValues({});
    final store = (await tester.runAsync(AppStore.load))!..beginOnboarding(); // új regisztráció
    await tester.pumpWidget(LifeupApp(store: store));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tovább'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Beállítom később'));
    await tester.pumpAndSettle();
    expect(find.text('Kész is vagyunk!'), findsOneWidget);
    await tester.tap(find.text('Tovább'));
    await tester.pumpAndSettle();
    expect(store.onboarded, isTrue);
    expect(store.myName, 'Teszt'); // a fiók neve (a Profilban átírható)
    expect(store.tourDone, isFalse);
    expect(find.text('Tovább'), findsOneWidget); // a bemutató első lépése
    await tester.tap(find.text('Kihagyom'));
    await tester.pumpAndSettle();
    expect(store.tourDone, isTrue);
    stopServices();
  });

  testWidgets('bemutató: kihagyható, és a Profilból újraindítható', (tester) async {
    phone(tester);
    final store = (await tester.runAsync(readyStore))!..setTourDone(false);
    await tester.pumpWidget(LifeupApp(store: store));
    await tester.pumpAndSettle();
    expect(find.text('1/10'), findsOneWidget);
    await tester.tap(find.text('Kihagyom'));
    await tester.pumpAndSettle();
    expect(store.tourDone, isTrue);

    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).last, const Offset(0, -1500));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bemutató újra'));
    await tester.pumpAndSettle();
    expect(find.text('1/10'), findsOneWidget);
    expect(find.textContaining(', Gabi'), findsOneWidget); // visszavált a Főoldalra (a köszönés napszakfüggő)
    await tester.tap(find.text('Kihagyom'));
    await tester.pumpAndSettle();
    stopServices();
  });

  testWidgets('főoldal: összefoglaló, következő program, feladat és cél kipipálása', (tester) async {
    phone(tester);
    final store = (await tester.runAsync(readyStore))!;
    final now = DateTime.now();
    store
      ..saveEvent(Event(id: 'e', title: 'Mozi', start: now.add(const Duration(minutes: 40)), durationMin: 120))
      ..saveTask(TaskItem(id: 't', title: 'Számla befizetése', due: now))
      ..addHabit('Olvasás');

    await tester.pumpWidget(LifeupApp(store: store));
    await tester.pumpAndSettle();
    expect(find.textContaining(', Gabi'), findsOneWidget);
    expect(find.text('Következő'), findsOneWidget);
    expect(find.text('Mozi'), findsWidgets);
    expect(find.textContaining('1 teendőd'), findsOneWidget);

    await tester.ensureVisible(find.text('Számla befizetése'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Kész').first);
    await tester.pump();
    expect(store.tasks.single.done, isTrue);

    await tester.ensureVisible(find.byType(CheckCircle).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CheckCircle).first);
    await tester.pump();
    expect(store.habits.single.isDoneOn(DateTime.now()), isTrue);
    stopServices();
  });

  testWidgets('létrehozás: a középső gombból új bejegyzés, ami a naptárban is megjelenik', (tester) async {
    phone(tester);
    final store = (await tester.runAsync(readyStore))!;
    await tester.pumpWidget(LifeupApp(store: store));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Létrehozás'));
    await tester.pumpAndSettle();
    expect(find.text('Közös időpont keresése'), findsOneWidget);
    await tester.tap(find.text('Bejegyzés').last); // a menüben (a Főoldalon is van ilyen gomb)
    await tester.pumpAndSettle();

    // Cím nélkül nem ment
    await tester.tap(find.text('Mentés'));
    await tester.pump();
    expect(find.text('Adj neki címet.'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Edzés');
    await tester.tap(find.text('Egészség, sport'));
    await tester.tap(find.text('Mentés'));
    await tester.pumpAndSettle();
    expect(store.events.single.title, 'Edzés');
    expect(store.events.single.category, EventCategory.health);
    expect(store.events.single.reminderMin, 30);

    await tester.tap(find.text('Naptár'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lista'));
    await tester.pumpAndSettle();
    expect(find.text('Edzés'), findsOneWidget);
    for (final view in ['Nap', 'Hét', 'Hónap']) {
      await tester.tap(find.text(view));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    CalendarScreen.lastView = CalendarView.week;
    stopServices();
  });

  testWidgets('feladat felvétele a Létrehozás menüből, határidővel', (tester) async {
    phone(tester);
    final store = (await tester.runAsync(readyStore))!;
    await tester.pumpWidget(LifeupApp(store: store));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Létrehozás'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Feladat').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Bevásárlás');
    await tester.tap(find.text('Mentés'));
    await tester.pumpAndSettle();
    expect(store.tasks.single.title, 'Bevásárlás');
    expect(sameDay(store.tasks.single.due!, DateTime.now()), isTrue);
    stopServices();
  });

  testWidgets('profil: adatvédelem, főoldal testreszabása, téma', (tester) async {
    phone(tester);
    final store = (await tester.runAsync(readyStore))!;
    await tester.pumpWidget(LifeupApp(store: store));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();
    expect(find.text('Gabi'), findsWidgets);

    await tester.tap(find.text('Adatvédelem'));
    await tester.pumpAndSettle();
    expect(find.text('Mit látnak a barátaid?'), findsOneWidget);
    await tester.tap(find.text('Minden barátom'));
    await tester.pumpAndSettle();
    expect(store.shareAvailability, AvailabilityShare.friends);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Főoldal testreszabása'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(SwitchListTile, 'A heted'));
    await tester.pumpAndSettle();
    expect(store.showsCard(HomeCard.week), isFalse);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    // Megjelenés: bézs, fehér vagy sötét; a fehér a háttérszínt is váltja.
    await tester.ensureVisible(find.text('Megjelenés'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Megjelenés'));
    await tester.pumpAndSettle();
    expect(find.text('Bézs'), findsOneWidget);
    await tester.tap(find.text('Fehér').last);
    await tester.pumpAndSettle();
    expect(store.themeMode, ThemeMode.light);
    expect(store.whiteTheme, isTrue);
    expect(AppColors.background, AppColors.backgroundFor(false, white: true));
    expect(find.text('Fehér'), findsOneWidget);
    await tester.tap(find.text('Megjelenés'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sötét'));
    await tester.pumpAndSettle();
    expect(store.themeMode, ThemeMode.dark);
    expect(AppColors.dark, isTrue);
    store.setThemeMode(ThemeMode.light, white: false);
    await tester.pumpAndSettle();
    stopServices();
  });
}
