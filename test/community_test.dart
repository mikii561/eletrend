import 'package:eletrend/community.dart';
import 'package:eletrend/ideas.dart';
import 'package:eletrend/screens/community_screen.dart';
import 'package:eletrend/store.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

CommunityIdea idea(String id, {IdeaPlace place = const IdeaPlace(), Set<IdeaTag> tags = const {}, int day = 1}) =>
    CommunityIdea(id: id, title: id, emoji: '💡', authorUid: 'x', authorName: 'X', place: place, tags: tags, createdAt: DateTime(2026, 10, day));

IdeaScore score({int likes = 0, List<int> ratings = const []}) => IdeaScore()
  ..likes = likes
  ..ratingSum = ratings.fold(0, (a, b) => a + b)
  ..ratingCount = ratings.length;

void main() {
  setUpAll(() => initializeDateFormatting('hu'));

  const budapest = IdeaPlace(name: 'Margitsziget', city: 'Budapest', country: 'Magyarország', lat: 47.527, lng: 19.047);
  const szentendre = IdeaPlace(name: 'Duna-part', city: 'Szentendre', country: 'Magyarország', lat: 47.669, lng: 19.075);
  const debrecen = IdeaPlace(name: 'Nagyerdő', city: 'Debrecen', country: 'Magyarország', lat: 47.553, lng: 21.624);
  const becs = IdeaPlace(name: 'Prater', city: 'Bécs', country: 'Ausztria', lat: 48.216, lng: 16.396);

  test('rendezés: értékelés (sok jó > egy tökéletes), kedvelés, legújabb', () {
    final ideas = [idea('egy5', day: 1), idea('sok48', day: 2), idea('uj', day: 9)];
    final scores = {
      'egy5': score(likes: 1, ratings: [5]),
      'sok48': score(likes: 9, ratings: [5, 5, 5, 5, 4, 5, 5, 4]),
    };
    expect(sortAndFilter(ideas, scores).map((i) => i.id).first, 'sok48');
    expect(sortAndFilter(ideas, scores, sort: IdeaSort.likes).map((i) => i.id), ['sok48', 'egy5', 'uj']);
    expect(sortAndFilter(ideas, scores, sort: IdeaSort.newest).first.id, 'uj');
  });

  test('hely: ország, város, közelben (30 km), címke', () {
    final ideas = [
      idea('bp', place: budapest, tags: {IdeaTag.outside}),
      idea('szentendre', place: szentendre),
      idea('debrecen', place: debrecen),
      idea('becs', place: becs),
      idea('mindegy'),
    ];
    expect(sortAndFilter(ideas, {}, country: 'Ausztria').map((i) => i.id), ['becs']);
    expect(sortAndFilter(ideas, {}, country: 'Magyarország', city: 'Debrecen').map((i) => i.id), ['debrecen']);
    final near = sortAndFilter(ideas, {}, sort: IdeaSort.nearby, home: budapest);
    expect(near.map((i) => i.id), ['bp', 'szentendre']); // Debrecen ~190 km, Bécs ~215 km
    expect(sortAndFilter(ideas, {}, sort: IdeaSort.nearby), isEmpty); // lakóhely nélkül nincs „közelben”
    expect(sortAndFilter(ideas, {}, tags: {IdeaTag.outside}).map((i) => i.id), ['bp']);
    expect(distanceKm(47.4979, 19.0402, 47.5316, 21.6273).round(), inInclusiveRange(190, 200));
  });

  test('felhő: megosztás, kedvelés és csillag, összesítés, jelentés, admin törlés', () async {
    final db = FakeFirebaseFirestore();
    final c = Community(db: db);
    final id = await c.publish(uid: 'gabi', authorName: 'Gabi', title: 'Naplemente', emoji: '🌅', place: budapest, tags: {IdeaTag.outside});
    await c.vote(id, 'anna', const MyVote(liked: true, rating: 5));
    await c.vote(id, 'bence', const MyVote(rating: 4));
    await c.vote(id, 'anna', const MyVote(liked: true, rating: 4)); // átírja, nem kétszer számít
    final ideas = await c.latest();
    expect(ideas.single.place.city, 'Budapest');
    expect(ideas.single.tags, {IdeaTag.outside});
    final v = await c.votes('anna');
    expect(v.scores[id]!.likes, 1);
    expect(v.scores[id]!.average, 4);
    expect(v.mine[id]!.rating, 4);

    await c.report(id, 'bence', 'reklám');
    expect((await c.reports())[id], ['reklám']);
    await c.delete(id, asAdmin: true);
    expect(await c.latest(), isEmpty);
    expect((await c.votes(null)).scores, isEmpty);
  });

  testWidgets('böngészés: szűrősor, ötlet megnyitása, kedvelés', (tester) async {
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = signInFakeAccount(uid: 'anna');
    await tester.runAsync(() => Community.instance.publish(uid: 'gabi', authorName: 'Gabi', title: 'Bowling', emoji: '🎳', place: budapest));
    SharedPreferences.setMockInitialValues({});
    final store = (await tester.runAsync(AppStore.load))!;

    await tester.pumpWidget(StoreScope(store: store, child: const MaterialApp(home: CommunityIdeasScreen())));
    await tester.pumpAndSettle();
    expect(find.text('Bowling'), findsOneWidget);
    await tester.tap(find.text('Bowling'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Kedvelem'));
    await tester.pumpAndSettle();
    final votes = (await tester.runAsync(() => db.collectionGroup('votes').get()))!;
    expect(votes.docs.single.data()['liked'], isTrue);
  });
}
