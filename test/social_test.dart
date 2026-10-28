import 'package:eletrend/models.dart';
import 'package:eletrend/screens/invite_screen.dart';
import 'package:eletrend/social.dart';
import 'package:eletrend/store.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Két „telefon” ugyanazzal a felhővel: a szervezőé és egy meghívotté.
({Social owner, Social guest, FakeFirebaseFirestore db}) twoDevices() {
  final db = FakeFirebaseFirestore();
  return (
    owner: Social(db: db, auth: MockFirebaseAuth(mockUser: MockUser(uid: 'szervezo', isAnonymous: true))),
    guest: Social(db: db, auth: MockFirebaseAuth(mockUser: MockUser(uid: 'anna', isAnonymous: true))),
    db: db,
  );
}

void main() {
  setUpAll(() => initializeDateFormatting('hu'));

  test('meghívás: szervező kiteszi, vendég visszajelez, szavaz, ír; szervező választ', () async {
    final d = twoDevices();
    final event = Event(id: '1', title: 'Pizza', date: DateTime(2026, 11, 6, 19));
    final id = await d.owner.publish(event, ownerName: 'Gabi');
    expect(d.owner.linkFor(id), 'https://mikii561.github.io/eletrend/?e=$id');

    final shared = await d.guest.watchEvent(id).first;
    expect(shared!.title, 'Pizza');
    expect(shared.ownerName, 'Gabi');

    final a = DateTime(2026, 11, 6, 19);
    final b = DateTime(2026, 11, 7, 18);
    await d.owner.setPoll(id, [a, b]);
    await d.guest.respond(id, name: 'Anna', status: RsvpStatus.yes, votes: {b.toIso8601String()});
    await d.guest.respond(id, name: 'Anna', status: RsvpStatus.maybe); // a szavazat megmarad

    final rsvps = await d.owner.watchRsvps(id).first;
    final anna = rsvps.firstWhere((r) => r.uid == 'anna');
    expect(anna.status, RsvpStatus.maybe);
    expect(anna.votes, {b.toIso8601String()});
    expect(rsvps.firstWhere((r) => r.uid == 'szervezo').status, RsvpStatus.yes);
    expect(bestOption([a, b], rsvps), b);

    await d.guest.send(id, name: 'Anna', text: 'Ki hoz chipset?');
    final messages = await d.owner.watchMessages(id).first;
    expect(messages.single.text, 'Ki hoz chipset?');
    expect(messages.single.name, 'Anna');

    await d.owner.choose(id, b);
    final after = await d.guest.watchEvent(id).first;
    expect(after!.date, b);
    expect(after.pollOpen, isFalse);

    await d.owner.unpublish(id);
    expect(await d.guest.watchEvent(id).first, isNull);
  });

  test('legjobb időpont: legtöbb szavazat, egyenlőségnél a korábbi; szavazat nélkül nincs', () {
    final a = DateTime(2026, 11, 6);
    final b = DateTime(2026, 11, 7);
    Rsvp r(String uid, Set<DateTime> v) =>
        Rsvp(uid: uid, name: uid, status: RsvpStatus.yes, votes: {for (final d in v) d.toIso8601String()});
    expect(bestOption([a, b], [r('x', {a, b}), r('y', {b})]), b);
    expect(bestOption([b, a], [r('x', {a}), r('y', {b})]), a);
    expect(bestOption([a, b], []), isNull);
  });

  testWidgets('vendég a meghívólinkről: nevet ad, visszajelez', (tester) async {
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final d = twoDevices();
    final id = (await tester.runAsync(() => d.owner.publish(
          Event(id: '1', title: 'Foci', date: DateTime(2026, 11, 5, 18), repeat: Repeat.weekly),
          ownerName: 'Gabi',
        )))!;
    Social.instance = d.guest;
    SharedPreferences.setMockInitialValues({'onboarded': true});
    final store = (await tester.runAsync(AppStore.load))!;

    await tester.pumpWidget(StoreScope(store: store, child: MaterialApp(home: InviteScreen(eventId: id))));
    await tester.pumpAndSettle();
    expect(find.text('Foci'), findsOneWidget);
    expect(find.text('Szervező: Gabi'), findsOneWidget);
    expect(find.textContaining('csütörtökönként'), findsOneWidget);

    // Név nélkül nem megy
    await tester.tap(find.text('✅ Jövök'));
    await tester.pump();
    expect(find.text('Előbb írd be a neved!'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Anna');
    await tester.tap(find.text('✅ Jövök'));
    await tester.pumpAndSettle();
    final rsvps = (await tester.runAsync(() => d.owner.watchRsvps(id).first))!;
    expect(rsvps.firstWhere((r) => r.uid == 'anna').status, RsvpStatus.yes);
    expect(store.myName, 'Anna');
    expect(store.invites.single.title, 'Foci');
  });

  test('ki mit hoz: felírás, elvállalás, lemondás', () async {
    final d = twoDevices();
    final id = await d.owner.publish(Event(id: '1', title: 'Buli', date: DateTime(2026, 11, 7, 20)), ownerName: 'Gabi');
    await d.owner.addItem(id, title: 'Chips', name: 'Gabi');
    await d.guest.addItem(id, title: 'Üdítő', name: 'Anna');
    var items = await d.guest.watchItems(id).first;
    expect(items.map((i) => i.title), containsAll(['Chips', 'Üdítő']));
    final chips = items.firstWhere((i) => i.title == 'Chips');
    await d.guest.claimItem(id, chips.id, name: 'Anna');
    items = await d.owner.watchItems(id).first;
    expect(items.firstWhere((i) => i.title == 'Chips').whoName, 'Anna');
    expect(items.firstWhere((i) => i.title == 'Chips').who, 'anna');
    await d.guest.claimItem(id, chips.id);
    items = await d.owner.watchItems(id).first;
    expect(items.firstWhere((i) => i.title == 'Chips').who, isNull);
  });
}
