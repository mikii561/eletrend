import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eletrend/account.dart';
import 'package:eletrend/admin.dart';
import 'package:eletrend/screens/admin_screen.dart';
import 'package:eletrend/l10n/l10n.dart';
import 'package:eletrend/main.dart';
import 'package:eletrend/friends.dart';
import 'package:eletrend/screens/challenges_screen.dart';
import 'package:eletrend/screens/event_detail_screen.dart';
import 'package:eletrend/screens/event_editor.dart';
import 'package:eletrend/screens/find_time_screen.dart';
import 'package:eletrend/screens/friends_screen.dart';
import 'package:eletrend/screens/google_calendar_screen.dart';
import 'package:eletrend/screens/habit_editor.dart';
import 'package:eletrend/screens/habits_screen.dart';
import 'package:eletrend/screens/missed_tasks.dart';
import 'package:eletrend/screens/nudge_screens.dart';
import 'package:eletrend/screens/privacy_screen.dart';
import 'package:eletrend/screens/profile_screen.dart';
import 'package:eletrend/screens/home_screen.dart';
import 'package:eletrend/screens/social_widgets.dart';
import 'package:eletrend/screens/status_sheet.dart';
import 'package:eletrend/screens/task_editor.dart';
import 'package:eletrend/widgets/common.dart';
import 'package:eletrend/widgets/pickers.dart';
import 'package:eletrend/models.dart';
import 'package:eletrend/screens/verify_email_screen.dart';
import 'package:eletrend/store.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';
import 'widget_test.dart' show phone, stopServices;

final _accents = RegExp('[áéíóöőúüűÁÉÍÓÖŐÚÜŰ]');

/// Minden látható szöveg (Text, tooltip, beviteli mezők címkéi) az éppen megjelenő képernyőn.
Set<String> visibleTexts(WidgetTester tester) {
  final out = <String>{};
  for (final w in tester.widgetList<Text>(find.byType(Text))) {
    final s = w.data ?? w.textSpan?.toPlainText();
    if (s != null && s.trim().isNotEmpty) out.add(s);
  }
  for (final w in tester.widgetList<Tooltip>(find.byType(Tooltip))) {
    if (w.message != null) out.add(w.message!);
  }
  for (final w in tester.widgetList<TextField>(find.byType(TextField))) {
    final d = w.decoration;
    for (final s in [d?.labelText, d?.hintText, d?.helperText, d?.errorText]) {
      if (s != null) out.add(s);
    }
  }
  return out;
}

void main() {
  setUp(signInFakeAccount);
  qaMore();
  qaSheets();
  qaAdmin();

  testWidgets('angol módban a fő képernyők szövegei le vannak fordítva (nincs magyar ékezetes szöveg)', (tester) async {
    phone(tester);
    // A tesztbetűtípus szélesebb, ezért egy-egy lapon túlcsordulás jelezhet; itt a szövegeket nézzük.
    final onError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains("overflowed")) return;
      onError?.call(details);
    };
    addTearDown(() => FlutterError.onError = onError);
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});
    final store = (await tester.runAsync(AppStore.load))!;
    final now = DateTime.now();
    DateTime at(int day, int hour, [int minute = 0]) => DateTime(now.year, now.month, now.day + day, hour, minute);
    store
      ..finishOnboarding(name: 'Gabi')
      ..setTourDone(false)
      ..setLanguage(AppLanguage.en)
      ..saveEvent(
        Event(id: 'a', title: 'Team meeting', start: at(0, 9, 30), durationMin: 60, category: EventCategory.work),
      )
      ..saveEvent(
        Event(
          id: 'b',
          title: 'Workout',
          start: at(0, 17),
          durationMin: 90,
          place: 'Gym',
          category: EventCategory.health,
        ),
      )
      ..saveEvent(Event(id: 'c', title: 'Pizza night', start: at(1, 20), durationMin: 120, repeat: Repeat.weekly))
      ..saveTask(TaskItem(id: 't1', title: 'Pay the bill', due: at(0, 12)))
      ..saveTask(TaskItem(id: 't2', title: 'Old task', due: at(-3, 12)))
      ..saveTask(TaskItem(id: 't3', title: 'Write report', scheduled: at(0, 14), durationMin: 90));
    store.addHabit('Water', target: 8, unit: 'glass');
    store.addHabit('Run', perWeek: 3);

    final report = <String, Set<String>>{};
    Future<void> dump(String name, {bool settle = true}) async {
      if (settle) {
        await tester.pumpAndSettle();
      } else {
        await tester.pump(const Duration(milliseconds: 300));
      }
      report[name] = visibleTexts(tester);
    }

    await tester.pumpWidget(LifeupApp(store: store));
    await tester.pumpAndSettle();

    // Bemutató: minden lépés.
    for (var i = 0; i < 10; i++) {
      await dump('tour $i', settle: false);
      final next = find.widgetWithText(FilledButton, 'Next');
      if (next.evaluate().isEmpty) break;
      await tester.tap(next);
      for (var f = 0; f < 4; f++) {
        await tester.pump(const Duration(milliseconds: 300));
      }
    }
    final start = find.widgetWithText(FilledButton, 'Let us start!');
    if (start.evaluate().isNotEmpty) await tester.tap(start);
    await tester.pumpAndSettle();
    store.setTourDone(true);
    await tester.pumpAndSettle();

    await dump('home');
    await tester.drag(find.byType(ListView).first, const Offset(0, -700));
    await dump('home 2');
    await tester.drag(find.byType(ListView).first, const Offset(0, -700));
    await dump('home 3');

    // Elmaradt teendők
    if (find.text('Yes').evaluate().isNotEmpty) {
      await tester.drag(find.byType(ListView).first, const Offset(0, 2000));
      await tester.pumpAndSettle();
    }

    Future<void> nav(String tab) async {
      // Ha valami (lap, ablak) takarja az alsó menüt, előbb bezárjuk.
      for (var i = 0; i < 4 && find.text(tab).evaluate().isEmpty; i++) {
        if (find.byType(BackButton).evaluate().isNotEmpty) {
          await tester.tap(find.byType(BackButton).first);
        } else {
          await tester.tapAt(const Offset(200, 20));
        }
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text(tab).last);
      await tester.pumpAndSettle();
    }

    await nav('Calendar');
    for (final v in ['Day', 'Week', 'Month', 'List']) {
      if (find.text(v).evaluate().isNotEmpty) {
        await tester.tap(find.text(v));
        await dump('calendar $v');
      }
    }
    await nav('Friends');
    await dump('friends');
    await nav('Profile');
    await dump('profile');

    final report2 = StringBuffer();
    final bad = <String>[];
    report.forEach((screen, texts) {
      report2.writeln('== $screen');
      for (final t in texts.toList()..sort()) {
        report2.writeln('  $t');
        if (_accents.hasMatch(t.replaceAll('Balatonfüred', ''))) bad.add('$screen: $t');
      }
    });
    final path = Platform.environment['ELETREND_QA'];
    if (path != null) File(path).writeAsStringSync(report2.toString());

    // --- További képernyők: minden lépés védett, ha egy elem nem található, csak jelezzük ---
    final skipped = <String>[];
    Future<bool> tapText(String text, {bool last = true, bool scroll = true}) async {
      var f = find.text(text);
      if (f.evaluate().isEmpty) {
        skipped.add('nincs: $text');
        return false;
      }
      f = last ? f.last : f.first;
      if (scroll) await tester.ensureVisible(f);
      await tester.tap(f, warnIfMissed: false);
      await tester.pumpAndSettle();
      return true;
    }

    Future<void> back() async {
      if (find.byType(BackButton).evaluate().isNotEmpty) {
        await tester.tap(find.byType(BackButton).first);
      } else {
        await tester.tapAt(const Offset(200, 20));
      }
      await tester.pumpAndSettle();
    }

    // Létrehozás menü és szerkesztők
    for (final option in [
      'Entry',
      'Task',
      'Shared event',
      'Find a common time',
      'Goal',
      'Challenge',
      'Add Google Calendar',
    ]) {
      await nav('Create');
      if (option == 'Entry') await dump('create sheet');
      if (await tapText(option)) {
        await dump('create → $option');
        if (find.byType(Scrollable).evaluate().isNotEmpty) {
          await tester.drag(find.byType(Scrollable).first, const Offset(0, -600), warnIfMissed: false);
        }
        await dump('create → $option 2');
        await back();
        if (find.text('Create').evaluate().isEmpty) await back();
      }
    }

    await nav('Home');
    // Állapot, elmaradt teendők, esemény részletei
    if (await tapText('Free', last: false)) {
      await dump('status sheet');
      await back();
    }
    await nav('Home');
    if (await tapText('Team meeting', last: false)) {
      await dump('event detail');
      await back();
    }

    // Barátok fül
    await nav('Friends');
    for (final b in ['Add friend', 'Groups', 'New group']) {
      if (await tapText(b, last: false)) {
        await dump('friends → $b');
        await back();
      }
    }

    // Profil és aloldalai
    await nav('Profile');
    for (final tile in [
      'My goals',
      'Challenges',
      'Nudges received',
      'Privacy',
      'Notifications',
      'Customise Home',
      'Appearance',
      'Language',
      'Google Calendar',
    ]) {
      await nav('Profile');
      if (await tapText(tile, scroll: true)) {
        await dump('profile → $tile');
        if (find.byType(Scrollable).evaluate().isNotEmpty) {
          await tester.drag(find.byType(Scrollable).first, const Offset(0, -600), warnIfMissed: false);
        }
        await dump('profile → $tile 2');
        await back();
      }
    }
    await nav('Profile');
    await tester.drag(find.byType(ListView).first, const Offset(0, -1500));
    await dump('profile bottom');

    final report3 = StringBuffer();
    report.forEach((screen, texts) {
      report3.writeln('== $screen');
      for (final t in texts.toList()..sort()) {
        report3.writeln('  $t');
        if (_accents.hasMatch(t.replaceAll('Balatonfüred', ''))) bad.add('$screen: $t');
      }
    });
    report3.writeln('== kihagyott: $skipped');
    final path2 = Platform.environment['ELETREND_QA2'];
    if (path2 != null) File(path2).writeAsStringSync(report3.toString());

    if (L10n.missing.isNotEmpty) bad.add('hiányzó fordítás: ${L10n.missing.toList()}');
    for (final b in bad) {
      // ignore: avoid_print
      print("HIBA: $b");
    }
    expect(bad, isEmpty);
    stopServices();
  });
}

/// Egy képernyő (vagy lap) szövegei: ékezetes (magyar) szöveget jelez.
List<String> hungarianIn(String screen, Set<String> texts) => [
  for (final t in texts)
    if (_accents.hasMatch(t.replaceAll('Balatonfüred', ''))) '$screen: $t',
];

void qaMore() {
  Future<AppStore> englishStore(WidgetTester tester, {bool onboarding = false}) async {
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});
    final store = (await tester.runAsync(AppStore.load))!;
    if (onboarding) {
      store.beginOnboarding();
    } else {
      store
        ..finishOnboarding(name: 'Gabi')
        ..setTourDone(true)
        ..setTipsOn(true);
    }
    store.setLanguage(AppLanguage.en);
    return store;
  }

  void ignoreOverflow() {
    final onError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('overflowed')) return;
      onError?.call(details);
    };
    addTearDown(() => FlutterError.onError = onError);
  }

  testWidgets('angol mód: az első belépés minden oldala', (tester) async {
    phone(tester);
    ignoreOverflow();
    final store = await englishStore(tester, onboarding: true);
    await tester.pumpWidget(LifeupApp(store: store));
    await tester.pumpAndSettle();
    final bad = <String>[];
    final report = StringBuffer();
    for (var i = 0; i < 7; i++) {
      final texts = visibleTexts(tester);
      report.writeln('== onboarding $i\n${(texts.toList()..sort()).map((t) => '  $t').join('\n')}');
      // A nyelvválasztó oldal szándékosan kétnyelvű.
      if (i != 1) bad.addAll(hungarianIn('onboarding $i', texts));
      final next = find.widgetWithText(FilledButton, 'Next');
      if (next.evaluate().isEmpty) break;
      await tester.tap(next);
      await tester.pumpAndSettle();
    }
    final path = Platform.environment['ELETREND_QA3'];
    if (path != null) File(path).writeAsStringSync(report.toString());
    expect(bad, isEmpty);
    stopServices();
  });

  testWidgets('angol mód: bejelentkezés és regisztráció, megerősítő oldal', (tester) async {
    phone(tester);
    ignoreOverflow();
    final store = await englishStore(tester);
    // Kijelentkezett állapot
    Account.instance = Account(auth: MockFirebaseAuth(), db: FakeFirebaseFirestore());
    await tester.pumpWidget(LifeupApp(store: store));
    await tester.pumpAndSettle();
    final bad = <String>[];
    final report = StringBuffer();
    void collect(String name) {
      final t = visibleTexts(tester);
      report.writeln('== $name\n${(t.toList()..sort()).map((x) => '  $x').join('\n')}');
      bad.addAll(hungarianIn(name, t));
    }

    collect('auth register');
    await tester.tap(find.text('Sign in').first);
    await tester.pumpAndSettle();
    collect('auth login');
    if (find.text('I forgot my password').evaluate().isNotEmpty) {
      await tester.tap(find.text('I forgot my password'));
      await tester.pumpAndSettle();
      collect('auth forgot');
    }
    await tester.tap(find.widgetWithText(FilledButton, "Sign in"));
    await tester.pumpAndSettle();
    collect("auth errors");
    await tester.pumpWidget(
      MaterialApp(
        home: VerifyEmailScreen(email: 'a@b.hu', onVerified: () {}, pollEvery: const Duration(hours: 1)),
      ),
    );
    await tester.pump();
    collect('verify');
    await tester.pumpWidget(MaterialApp(home: RegistrationSuccessScreen(onContinue: () {})));
    await tester.pump();
    collect('registration success');
    final path = Platform.environment['ELETREND_QA4'];
    if (path != null) File(path).writeAsStringSync(report.toString());
    expect(bad, isEmpty);
  });
}

void qaSheets() {
  testWidgets('angol mód: lapok, szerkesztők és ablakok szövegei', (tester) async {
    phone(tester);
    L10n.lang = AppLanguage.en; // itt nincs LifeupApp, ami beállítaná
    final onError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('overflowed')) return;
      onError?.call(details);
    };
    addTearDown(() => FlutterError.onError = onError);
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});
    final store = (await tester.runAsync(AppStore.load))!;
    final now = DateTime.now();
    store
      ..finishOnboarding(name: 'Gabi')
      ..setTourDone(true)
      ..setLanguage(AppLanguage.en)
      ..saveEvent(
        Event(
          id: 'e1',
          title: 'Dinner',
          start: DateTime(now.year, now.month, now.day + 1, 19),
          durationMin: 90,
          place: 'Home',
          repeat: Repeat.weekly,
        ),
      )
      ..saveTask(TaskItem(id: 't1', title: 'Write report', due: DateTime(now.year, now.month, now.day + 1)))
      ..saveTask(TaskItem(id: 't2', title: 'Old task', due: DateTime(now.year, now.month, now.day - 4)));
    store.addHabit('Read', perWeek: 3);
    store.addHabit('Water', target: 8, unit: 'glass');
    store.setFriendsCache(const [FriendInfo(uid: 'f1', name: 'Anna', birthday: '12-24')]);

    final report = StringBuffer();
    final bad = <String>[];
    var host = const SizedBox.shrink();
    late BuildContext hostContext;
    await tester.pumpWidget(
      StoreScope(
        store: store,
        child: MaterialApp(
          locale: const Locale('en'),
          home: Builder(
            builder: (context) {
              hostContext = context;
              return Scaffold(body: host);
            },
          ),
        ),
      ),
    );
    // Ha valami végtelen animáció fut (töltésjelző), néhány képkocka után továbblépünk.
    Future<void> settleSafe() async {
      try {
        await tester.pumpAndSettle(
          const Duration(milliseconds: 100),
          EnginePhase.sendSemanticsUpdate,
          const Duration(seconds: 2),
        );
      } catch (_) {}
    }

    Future<void> check(
      String name,
      Future<void> Function(BuildContext) open, {
      bool scroll = true,
      bool settle = true,
    }) async {
      unawaited(open(hostContext));
      if (settle) {
        await settleSafe();
      } else {
        await tester.pump(const Duration(milliseconds: 600));
      }
      var t = visibleTexts(tester);
      if (scroll && find.byType(Scrollable).evaluate().isNotEmpty) {
        await tester.drag(find.byType(Scrollable).last, const Offset(0, -500), warnIfMissed: false);
        await settleSafe();
        t = {...t, ...visibleTexts(tester)};
      }
      report.writeln('== $name\n${(t.toList()..sort()).map((x) => '  $x').join('\n')}');
      bad.addAll(hungarianIn(name, t));
      // bezárás
      for (var i = 0; i < 3 && find.byType(ModalBarrier).evaluate().length > 1; i++) {
        await tester.tapAt(const Offset(200, 15));
        await tester.pump(const Duration(milliseconds: 600));
      }
      for (var i = 0; i < 3 && find.byType(BackButton).evaluate().isNotEmpty; i++) {
        await tester.tap(find.byType(BackButton).first);
        await settleSafe();
      }
    }

    await check('task editor', (c) => showTaskEditor(c, due: DateTime.now()));
    await check('habit editor', (c) => showHabitEditor(c));
    await check('habit templates', showHabitTemplates);
    await check('status sheet', showStatusSheet);
    await check('missed tasks', showMissedTasks);
    await check('nudge composer', (c) => showNudgeComposer(c, to: {'f1': 'Anna'}, eventTitle: 'Dinner'));
    await check('language sheet', showLanguageSheet);
    await check('text input', (c) => showTextInputSheet(c, title: 'Name', hint: 'x'));
    await check('friend picker', (c) => showFriendPicker(c));
    await check('poll editor', (c) => showPollEditor(c, [DateTime.now()]));
    await check('friend sheet', (c) => showFriendSheet(c, const Friend(uid: 'f1', name: 'Anna', birthday: '12-24')));
    await check('group editor', showGroupEditor);
    await check('memories example', showMemoriesExample, scroll: false, settle: false);
    await check('time picker', (c) async => pickTime(c, initial: const TimeOfDay(hour: 9, minute: 0)));
    await check('birthday picker', (c) async => pickBirthday(c));
    await check('confirm dialog', (c) => confirm(c, title: 'Sure?', text: 'This cannot be undone.'));
    for (final entry in <String, Widget>{
      'event editor': const EventEditor(),
      'shared event editor': const EventEditor(social: true),
      'event detail': const EventDetailScreen(eventId: 'e1'),
      'find time': const FindTimeScreen(),
      'privacy': const PrivacyScreen(),
      'notification settings': const NotificationSettingsScreen(),
      'home cards': const HomeCardsScreen(),
      'goals': const HabitsScreen(),
      'google calendar': const GoogleCalendarScreen(),
      'challenges': const ChallengesScreen(),
      'nudge inbox': const NudgeInboxScreen(),
    }.entries) {
      await check(entry.key, (c) => Navigator.of(c).push(MaterialPageRoute<void>(builder: (_) => entry.value)));
    }

    final path = Platform.environment['ELETREND_QA5'];
    if (path != null) File(path).writeAsStringSync(report.toString());
    for (final b in bad) {
      // ignore: avoid_print
      print('HIBA: $b');
    }
    expect(bad, isEmpty);
    stopServices();
  });
}

void qaAdmin() {
  testWidgets('angol mód: az admin felület fülei', (tester) async {
    phone(tester);
    L10n.lang = AppLanguage.en;
    final onError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('overflowed')) return;
      onError?.call(details);
    };
    addTearDown(() => FlutterError.onError = onError);
    final db = FakeFirebaseFirestore();
    Admin.instance = Admin(db: db);
    await db.collection('profiles').doc('u1').set({
      'name': 'Anna',
      'email': 'a@b.hu',
      'platform': 'web',
      'lastSeen': Timestamp.now(),
      'createdAt': Timestamp.now(),
    });
    await db.collection('errors').add({'message': 'boom', 'at': Timestamp.now(), 'platform': 'web'});
    await db.collection('feedback').add({
      'uid': 'u1',
      'name': 'Anna',
      'email': 'a@b.hu',
      'text': 'Great',
      'done': false,
      'at': Timestamp.now(),
    });
    await db.collection('reports').add({'reporterUid': 'u1', 'userUid': 'u2', 'reason': 'spam', 'at': Timestamp.now()});
    await tester.pumpWidget(const MaterialApp(locale: Locale('en'), home: AdminScreen()));
    await tester.pumpAndSettle();
    final bad = <String>[];
    final report = StringBuffer();
    for (final tab in ['Overview', 'Users', 'Errors', 'Feedback', 'Events', 'Reports']) {
      if (find.text(tab).evaluate().isEmpty) {
        bad.add('hiányzik a fül: $tab');
        continue;
      }
      await tester.tap(find.text(tab).first);
      await tester.pumpAndSettle();
      final t = visibleTexts(tester);
      report.writeln('== admin $tab\n${(t.toList()..sort()).map((x) => '  $x').join('\n')}');
      bad.addAll(hungarianIn('admin $tab', t));
    }
    final path = Platform.environment['ELETREND_QA6'];
    if (path != null) File(path).writeAsStringSync(report.toString());
    for (final b in bad) {
      // ignore: avoid_print
      print('HIBA: $b');
    }
    expect(bad, isEmpty);
  });
}
