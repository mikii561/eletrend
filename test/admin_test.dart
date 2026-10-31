import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eletrend/admin.dart';
import 'package:eletrend/screens/admin_screen.dart';
import 'package:eletrend/models.dart';
import 'package:eletrend/store.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('adatlap: darabszámok, tartalom nélkül; statisztika', () async {
    final db = FakeFirebaseFirestore();
    final admin = Admin(db: db);
    SharedPreferences.setMockInitialValues({});
    final store = await AppStore.load();
    store.setMyName('Gabi');
    store.addHabit('Séta');
    store.saveTask(TaskItem(id: 't', title: 'titkos teendő'));
    await admin.updateProfile(
      uid: 'u1',
      email: 'gabi@pelda.hu',
      store: store,
      createdAt: DateTime(2026, 10, 1),
      force: true,
    );

    final doc = await db.collection('profiles').doc('u1').get();
    expect(doc.data()!.toString(), isNot(contains('titkos')));
    final users = await admin.users();
    expect(users.single.name, 'Gabi');
    expect(users.single.counts, {'events': 0, 'tasks': 1, 'habits': 1});

    // Óránként csak egyszer frissít (kíméli a kvótát)
    store.addHabit('Olvasás');
    await admin.updateProfile(uid: 'u1', email: 'gabi@pelda.hu', store: store);
    expect((await admin.users()).single.counts['habits'], 1);

    final now = DateTime.now();
    final s = AdminStats(
      [
        UserProfile(
          uid: 'a',
          name: 'A',
          email: '',
          lastSeen: now.subtract(const Duration(days: 2)),
          createdAt: now,
          platform: 'web',
          counts: const {'tasks': 3},
        ),
        UserProfile(
          uid: 'b',
          name: 'B',
          email: '',
          lastSeen: now.subtract(const Duration(days: 20)),
          platform: 'android',
          counts: const {'tasks': 2, 'habits': 4},
        ),
        const UserProfile(uid: 'c', name: 'C', email: ''),
      ],
      sharedEvents: 1,
      openFeedback: 2,
      errors24h: 0,
      now: now,
    );
    expect([s.total, s.active7, s.active30, s.newThisWeek], [3, 1, 2, 1]);
    expect(s.totals, {'events': 0, 'tasks': 5, 'habits': 4});
    expect(s.platforms, {'web': 1, 'android': 1, '?': 1});
  });

  test('hibajelentés: csak élesben, ugyanazt egyszer; visszajelzés, felfüggesztés, adattörlés', () async {
    final db = FakeFirebaseFirestore();
    final admin = Admin(db: db);

    Admin.reportingEnabled = false;
    await admin.reportError(StateError('teszt'), StackTrace.current);
    expect((await db.collection('errors').get()).docs, isEmpty);

    Admin.reportingEnabled = true;
    Admin.currentUid = 'u1';
    await admin.reportError(StateError('elszállt'), StackTrace.current);
    await admin.reportError(StateError('elszállt'), StackTrace.current);
    Admin.reportingEnabled = false;
    final errors = await admin.errors();
    expect(errors.single.message, contains('elszállt'));
    expect(errors.single.uid, 'u1');
    await admin.deleteErrorsLike(errors.single.message);
    expect(await admin.errors(), isEmpty);

    await admin.sendFeedback(uid: 'u1', name: 'Gabi', email: 'g@p.hu', text: 'A naptár nem görget');
    final fb = await admin.feedback();
    expect(fb.single.done, isFalse);
    await admin.setFeedbackDone(fb.single.id, true);
    expect((await admin.feedback()).single.done, isTrue);

    expect(await admin.isBanned('u2'), isFalse);
    await admin.setBanned('u2', true);
    expect(await admin.isBanned('u2'), isTrue);
    await db.collection('profiles').doc('u2').set({'name': 'Rossz', 'email': ''});
    expect((await admin.users()).single.banned, isTrue);

    await db.collection('users').doc('u2').collection('journal').doc('x').set({'mood': 1});
    await admin.deleteUserData('u2');
    expect((await db.collection('users').doc('u2').collection('journal').get()).docs, isEmpty);
    expect(await admin.users(), isEmpty);

    expect(await admin.isAdmin('u1'), isFalse);
    await db.collection('admins').doc('u1').set({});
    expect(await admin.isAdmin('u1'), isTrue);
  });

  test('idősor: oszlopok a szűrő szerint, az előző időszakhoz képest +/−, egy felhasználó oszloponként egyszer', () {
    final now = DateTime(2030, 3, 15, 12);
    DateTime daysAgo(int n) => DateTime(2030, 3, 15 - n, 9);

    final week = TrendSeries.build(
      [
        [daysAgo(0)],
        [daysAgo(0)],
        [daysAgo(2)],
        [daysAgo(8)], // az előző héten
        [daysAgo(9)],
        [daysAgo(10)],
        [daysAgo(20)], // régebbi: sehol nem számít
      ],
      StatRange.week,
      now,
    );
    expect(week.counts, [0, 0, 0, 0, 1, 0, 2]);
    expect([week.total, week.previous, week.delta], [3, 3, 0]);

    // Aktív felhasználó: ugyanaz egy napon belül kétszer is csak egyszer számít, két napon kétszer az összegben egyszer.
    final active = TrendSeries.build(
      [
        [daysAgo(0), DateTime(2030, 3, 15, 18), daysAgo(1)],
      ],
      StatRange.week,
      now,
    );
    expect(active.counts, [0, 0, 0, 0, 0, 1, 1]);
    expect(active.total, 1);

    expect(TrendSeries.bucketStarts(StatRange.month, now), hasLength(30));
    expect(TrendSeries.bucketStarts(StatRange.quarter, now), hasLength(13));
    final months = TrendSeries.bucketStarts(StatRange.year, now);
    expect([months.first, months.last], [DateTime(2029, 4), DateTime(2030, 3)]);

    final trends = Trends(
      [
        UserProfile(
          uid: 'a',
          name: 'A',
          email: '',
          createdAt: daysAgo(1),
          activeDays: const ['2030-03-14', '2030-03-15'],
        ),
        UserProfile(uid: 'b', name: 'B', email: '', createdAt: daysAgo(40), lastSeen: daysAgo(3)),
      ],
      errorTimes: [daysAgo(0), daysAgo(1), daysAgo(1), daysAgo(9)],
    );
    expect(trends.of(TrendKind.newUsers, StatRange.week, now: now).total, 1);
    expect(trends.of(TrendKind.active, StatRange.week, now: now).total, 2);
    final errors = trends.of(TrendKind.errors, StatRange.week, now: now);
    expect([errors.total, errors.previous, errors.delta], [3, 1, 2]);
  });

  testWidgets('admin áttekintés: szűrő, zöld + / piros − és diagramok', (tester) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await initializeDateFormatting('hu');
    final db = FakeFirebaseFirestore();
    Admin.instance = Admin(db: db);
    final now = DateTime.now();
    await db.collection('profiles').doc('u1').set({
      'name': 'Új Elek',
      'email': '',
      'createdAt': Timestamp.fromDate(now.subtract(const Duration(days: 1))),
      'lastSeen': Timestamp.fromDate(now),
    });
    await db.collection('errors').add({'message': 'baj', 'at': Timestamp.fromDate(now)});
    await tester.pumpWidget(const MaterialApp(home: AdminScreen()));
    await tester.pumpAndSettle();

    expect(find.text('A változás az előző 7 naphoz képest.'), findsOneWidget);
    // Egy új felhasználó és egy hiba: a felhasználók +1 (zöld), a hiba +1 (piros, mert a több a rossz).
    final plusOnes = tester.widgetList<Text>(find.text('+1')).toList();
    expect(plusOnes, isNotEmpty);
    final colors = {for (final t in plusOnes) t.style!.color};
    expect(colors, hasLength(2));
    expect(find.text('Új felhasználók'), findsOneWidget);
    expect(find.text('Hibák száma'), findsOneWidget);

    await tester.tap(find.text('30 nap'));
    await tester.pumpAndSettle();
    expect(find.text('A változás az előző 30 naphoz képest.'), findsOneWidget);
    await tester.tap(find.text('1 év'));
    await tester.pumpAndSettle();
    expect(find.text('A változás az előző 1 évhez képest.'), findsOneWidget);
  });

  testWidgets('admin felület: minden fül megnyílik, felhasználó felfüggeszthető', (tester) async {
    tester.view.physicalSize = const Size(400, 1700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await initializeDateFormatting('hu');
    final db = FakeFirebaseFirestore();
    Admin.instance = Admin(db: db);
    await db.collection('profiles').doc('u1').set({
      'name': 'Teszt Elek',
      'email': 'elek@pelda.hu',
      'platform': 'web',
      'version': appVersion,
      'lastSeen': Timestamp.now(),
      'counts': {'events': 1, 'tasks': 3, 'habits': 2},
    });
    await db.collection('feedback').add({
      'uid': 'u1',
      'name': 'Teszt Elek',
      'email': 'elek@pelda.hu',
      'text': 'Jó az app!',
      'done': false,
      'at': Timestamp.now(),
    });

    await tester.pumpWidget(const MaterialApp(home: AdminScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Felhasználó'), findsOneWidget); // áttekintés csempe
    expect(find.text('Feladat'), findsOneWidget);

    await tester.tap(find.text('Felhasználók'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Teszt Elek'));
    await tester.pumpAndSettle();
    expect(find.text('1 bejegyzés • 3 feladat • 2 cél'), findsOneWidget);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(await Admin.instance.isBanned('u1'), isTrue);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Visszajelzések'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Visszajelzések'));
    await tester.pumpAndSettle();
    expect(find.text('Jó az app!'), findsOneWidget);
    await tester.ensureVisible(find.text('Hibák'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hibák'));
    await tester.pumpAndSettle();
    expect(find.text('Nincs bejelentett hiba.'), findsOneWidget);
    await tester.ensureVisible(find.text('Programok'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Programok'));
    await tester.pumpAndSettle();
    expect(find.text('Nincs megosztott program.'), findsOneWidget);

    // Jelentés egy felhasználóról: az admin látja, és kezeltnek jelölheti.
    await tester.runAsync(
      () => db.collection('reports').add({
        'reporterUid': 'u7',
        'userUid': 'u1',
        'reason': 'Kéretlen üzenetek',
        'at': Timestamp.now(),
      }),
    );
    await tester.ensureVisible(find.text('Jelentések'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jelentések'));
    await tester.pumpAndSettle();
    expect(find.text('Kéretlen üzenetek'), findsOneWidget);
    await tester.tap(find.byTooltip('Kezelve (törlés)'));
    await tester.pumpAndSettle();
    expect(find.text('Nincs jelentés.'), findsOneWidget);
  });
}
