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
  test('adatlap: darabszámok, napló tartalma nélkül; statisztika', () async {
    final db = FakeFirebaseFirestore();
    final admin = Admin(db: db);
    SharedPreferences.setMockInitialValues({});
    final store = await AppStore.load();
    store.setMyName('Gabi');
    store.addHabit('Séta');
    store.saveEntry(JournalEntry(id: 'j', date: DateTime(2026, 10, 28), mood: 5, note: 'titkos gondolat'));
    await admin.updateProfile(uid: 'u1', email: 'gabi@pelda.hu', store: store, createdAt: DateTime(2026, 10, 1), force: true);

    final doc = await db.collection('profiles').doc('u1').get();
    expect(doc.data()!.toString(), isNot(contains('titkos')));
    final users = await admin.users();
    expect(users.single.name, 'Gabi');
    expect(users.single.counts, {'journal': 1, 'habits': 1, 'events': 0});

    // Óránként csak egyszer frissít (kíméli a kvótát)
    store.addHabit('Olvasás');
    await admin.updateProfile(uid: 'u1', email: 'gabi@pelda.hu', store: store);
    expect((await admin.users()).single.counts['habits'], 1);

    final now = DateTime.now();
    final s = AdminStats([
      UserProfile(uid: 'a', name: 'A', email: '', lastSeen: now.subtract(const Duration(days: 2)), createdAt: now, platform: 'web', counts: const {'journal': 3}),
      UserProfile(uid: 'b', name: 'B', email: '', lastSeen: now.subtract(const Duration(days: 20)), platform: 'android', counts: const {'journal': 2, 'habits': 4}),
      const UserProfile(uid: 'c', name: 'C', email: ''),
    ], sharedEvents: 1, openFeedback: 2, errors24h: 0, now: now);
    expect([s.total, s.active7, s.active30, s.newThisWeek], [3, 1, 2, 1]);
    expect(s.totals, {'journal': 5, 'habits': 4, 'events': 0});
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

  testWidgets('admin felület: minden fül megnyílik, felhasználó felfüggeszthető', (tester) async {
    tester.view.physicalSize = const Size(400, 860);
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
      'counts': {'journal': 3, 'habits': 2, 'events': 1},
    });
    await db.collection('feedback').add({'uid': 'u1', 'name': 'Teszt Elek', 'email': 'elek@pelda.hu', 'text': 'Jó az app!', 'done': false, 'at': Timestamp.now()});

    await tester.pumpWidget(const MaterialApp(home: AdminScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Felhasználó'), findsOneWidget); // áttekintés csempe
    expect(find.text('Naplóbejegyzés'), findsOneWidget);

    await tester.tap(find.text('Felhasználók'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Teszt Elek'));
    await tester.pumpAndSettle();
    expect(find.text('3 napló • 2 cél • 1 program'), findsOneWidget);
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
  });
}
