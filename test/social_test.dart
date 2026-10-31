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
    owner: Social(
      db: db,
      auth: MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'szervezo')),
    ),
    guest: Social(
      db: db,
      auth: MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'anna')),
    ),
    db: db,
  );
}

void main() {
  setUpAll(() => initializeDateFormatting('hu'));

  test('közös program: kitétel, Megyek/Talán, létszámlista, szavazás, hozzászólás, reakció', () async {
    final d = twoDevices();
    final event = Event(
      id: '1',
      title: 'Pizza',
      start: DateTime(2030, 11, 6, 19),
      durationMin: 150,
      notes: 'Hozz jó kedvet',
      limit: 6,
    );
    final id = await d.owner.publish(event, ownerName: 'Gabi');
    expect(d.owner.linkFor(id), 'https://mikii561.github.io/eletrend/?e=$id');

    var shared = (await d.guest.watchEvent(id).first)!;
    expect(shared.title, 'Pizza');
    expect(shared.ownerName, 'Gabi');
    expect(shared.end, DateTime(2030, 11, 6, 21, 30));
    expect(shared.notes, 'Hozz jó kedvet');
    expect(shared.limit, 6);
    expect(shared.going, ['szervezo']); // a szervező automatikusan megy

    // Megyek: felkerül a létszámlistára; Talán: lekerül róla
    await d.guest.respond(id, name: 'Anna', status: RsvpStatus.yes);
    expect((await d.guest.fetchEvent(id))!.going, containsAll(['szervezo', 'anna']));
    final a = DateTime(2030, 11, 6, 19), b = DateTime(2030, 11, 7, 18);
    await d.owner.setPoll(id, [a, b]);
    await d.guest.respond(id, name: 'Anna', votes: {b.toIso8601String()});
    await d.guest.respond(id, name: 'Anna', status: RsvpStatus.maybe); // a szavazat megmarad
    expect((await d.guest.fetchEvent(id))!.going, ['szervezo']);

    final rsvps = await d.owner.watchRsvps(id).first;
    final anna = rsvps.firstWhere((r) => r.uid == 'anna');
    expect(anna.status, RsvpStatus.maybe);
    expect(anna.votes, {b.toIso8601String()});
    expect(bestOption([a, b], rsvps), b);

    await d.guest.send(id, name: 'Anna', text: '  Ki hoz italt?  ');
    final messages = await d.owner.watchMessages(id).first;
    expect(messages.single.text, 'Ki hoz italt?');

    await d.guest.react(id, '🎉');
    await d.owner.react(id, '🎉');
    expect((await d.owner.watchReactions(id).first)['🎉'], hasLength(2));
    await d.guest.react(id, null);
    expect((await d.owner.watchReactions(id).first)['🎉'], ['szervezo']);

    await d.owner.choose(id, b);
    shared = (await d.guest.watchEvent(id).first)!;
    expect(shared.date, b);
    expect(shared.pollOpen, isFalse);

    await d.owner.addInvited(id, ['anna']);
    expect((await d.db.collection('events').doc(id).get()).data()!['invitedUids'], ['anna']);

    await d.owner.unpublish(id);
    expect(await d.guest.watchEvent(id).first, isNull);
  });

  test('létszám: betelt programnál a „Megyek” nem választható (a felületen)', () {
    final full = SharedEvent(
      id: 'x',
      title: 't',
      date: DateTime(2030),
      ownerUid: 'o',
      ownerName: 'O',
      limit: 2,
      going: const ['o', 'a'],
    );
    expect(full.full, isTrue);
    final open = SharedEvent(
      id: 'x',
      title: 't',
      date: DateTime(2030),
      ownerUid: 'o',
      ownerName: 'O',
      going: const ['o', 'a'],
    );
    expect(open.full, isFalse);
  });

  test('legjobb időpont: legtöbb szavazat, egyenlőségnél a korábbi; szavazat nélkül nincs', () {
    final a = DateTime(2026, 11, 6);
    final b = DateTime(2026, 11, 7);
    Rsvp r(String uid, Set<DateTime> v) =>
        Rsvp(uid: uid, name: uid, status: RsvpStatus.yes, votes: {for (final d in v) d.toIso8601String()});
    expect(
      bestOption(
        [a, b],
        [
          r('x', {a, b}),
          r('y', {b}),
        ],
      ),
      b,
    );
    expect(
      bestOption(
        [b, a],
        [
          r('x', {a}),
          r('y', {b}),
        ],
      ),
      a,
    );
    expect(bestOption([a, b], []), isNull);
  });

  testWidgets('meghívott: látja a programot, a naptárába teszi, visszajelez', (tester) async {
    tester.view.physicalSize = const Size(400, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final d = twoDevices();
    final id = (await tester.runAsync(
      () => d.owner.publish(
        Event(id: '1', title: 'Foci', start: DateTime(2030, 11, 7, 18), repeat: Repeat.weekly, place: 'Margitsziget'),
        ownerName: 'Gabi',
      ),
    ))!;
    Social.instance = d.guest;
    SharedPreferences.setMockInitialValues({});
    final store = (await tester.runAsync(AppStore.load))!..setMyName('Anna');

    await tester.pumpWidget(
      StoreScope(
        store: store,
        child: MaterialApp(home: InviteScreen(eventId: id)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Foci'), findsOneWidget);
    expect(find.text('Szervező: Gabi'), findsOneWidget);
    expect(find.textContaining('csütörtökönként'), findsOneWidget);
    expect(find.text('Margitsziget'), findsOneWidget);
    expect(store.invites.single.title, 'Foci');

    await tester.tap(find.text('Hozzáadom a naptáramhoz'));
    await tester.pumpAndSettle();
    expect(store.events.single.shareId, id);
    expect(store.events.single.category, EventCategory.shared);

    await tester.tap(find.text('Megyek'));
    await tester.pumpAndSettle();
    final rsvps = (await tester.runAsync(() => d.owner.watchRsvps(id).first))!;
    expect(rsvps.firstWhere((r) => r.uid == 'anna').status, RsvpStatus.yes);
  });
}
