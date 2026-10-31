import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eletrend/admin.dart';
import 'package:eletrend/main.dart';
import 'package:eletrend/models.dart';
import 'package:eletrend/nudges.dart';
import 'package:eletrend/screens/nudge_screens.dart';
import 'package:eletrend/store.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';
import 'widget_test.dart' show phone, readyStore, stopServices;

void main() {
  setUpAll(() => initializeDateFormatting('hu'));

  test('bökések: olvasatlanok száma; a lista megnyitásakor mind olvasott; régiekről nem jön újra értesítés', () async {
    final db = FakeFirebaseFirestore();
    final inbox = db.collection('nudges').doc('anna').collection('items');
    // Egy régi, még olvasatlan bökés (az app zárva volt).
    await inbox.doc('gabi_20260101_0').set({
      'fromUid': 'gabi',
      'fromName': 'Gabi',
      'text': 'Régi',
      'seen': false,
      'at': Timestamp.fromDate(DateTime(2026, 1, 1)),
    });
    final shown = <String>[];
    final anna = Nudges(db: db)..start('anna', (n) => shown.add(n.text));
    await pumpEventQueue();
    expect(shown, isEmpty); // a régi nem ugrik fel újra, csak a számláló mutatja
    expect(await anna.watchUnseenCount().first, 1);

    await inbox.doc('gabi_20991231_0').set({'fromUid': 'gabi', 'fromName': 'Gabi', 'text': 'Új', 'seen': false, 'at': null});
    await pumpEventQueue();
    expect(shown, ['Új']);
    expect(await anna.watchUnseenCount().first, 2);

    await anna.markAllSeen();
    expect(await anna.watchUnseenCount().first, 0);
    anna.stop();
  });

  test('meghívások: új, amíg meg nem nyitotta; a múltbeli és a már naptárban lévő nem számít', () async {
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});
    final store = await AppStore.load();
    final now = DateTime(2030, 3, 1);
    store
      ..saveInvite(Invite(id: 'a', title: 'Pizza', date: DateTime(2030, 3, 5)))
      ..saveInvite(Invite(id: 'b', title: 'Régi', date: DateTime(2030, 2, 1)))
      ..saveInvite(Invite(id: 'c', title: 'Mozi', date: DateTime(2030, 3, 9)))
      ..saveEvent(Event(id: 'inv-c', title: 'Mozi', start: DateTime(2030, 3, 9))..shareId = 'c');
    expect(store.unseenInvites(now).map((i) => i.id), ['a']);
    store.markInviteSeen('a');
    expect(store.unseenInvites(now), isEmpty);
  });

  test('admin: a nyitott visszajelzések és a jelentések száma együtt', () async {
    final db = FakeFirebaseFirestore();
    final admin = Admin(db: db);
    await db.collection('feedback').add({'text': 'a', 'done': false});
    await db.collection('feedback').add({'text': 'b', 'done': true});
    await db.collection('reports').add({'reason': 'x'});
    expect(await admin.watchOpenCount().firstWhere((n) => n == 2), 2);
  });

  testWidgets('számok a menüben: Főoldal = új meghívás, Barátok = jelölés + olvasatlan bökés; megnyitáskor eltűnik', (tester) async {
    phone(tester);
    final db = signInFakeAccount();
    final store = (await tester.runAsync(readyStore))!;
    store.saveInvite(Invite(id: 'meghivo1234', title: 'Pizza', date: DateTime.now().add(const Duration(days: 3))));
    await tester.runAsync(() async {
      await db.collection('requests').doc('teszt').collection('items').doc('bela').set({'fromName': 'Béla'});
      await db.collection('nudges').doc('teszt').collection('items').doc('bela_20990101_0').set({
        'fromUid': 'bela',
        'fromName': 'Béla',
        'text': 'Szia!',
        'seen': false,
        'at': Timestamp.fromDate(DateTime(2026, 1, 1)),
      });
    });

    await tester.pumpWidget(LifeupApp(store: store));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();
    Finder inNav(String text) => find.descendant(of: find.byType(NavigationBar), matching: find.text(text));
    expect(inNav('1'), findsOneWidget); // Főoldal: 1 új meghívás
    expect(inNav('2'), findsOneWidget); // Barátok: 1 jelölés + 1 bökés
    expect(find.text('Új'), findsOneWidget); // a Meghívásaim között

    // A bökések listájának megnyitása után a bökés már nem számít.
    await tester.tap(find.text('Barátok').last);
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byType(AppBar), matching: find.text('1')), findsOneWidget);
    await tester.tap(find.byTooltip('Kapott bökések'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();
    expect(find.byType(NudgeInboxScreen), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(inNav('2'), findsNothing);
    expect(inNav('1'), findsNWidgets(2)); // a meghívás és a jelölés maradt
    stopServices();
  });
}
