import 'package:eletrend/erase.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fióktörlés: a társas adatok mind törlődnek, a barátnál is; a kihívásból kilép, a sajátot törli', () async {
    final db = FakeFirebaseFirestore();
    Future<void> set(String path, Map<String, dynamic> data) => db.doc(path).set(data);

    await set('people/me', {'name': 'Gabi', 'code': 'ABC234'});
    await set('profiles/me', {'name': 'Gabi', 'email': 'g@pelda.hu'});
    await set('codes/ABC234', {'uid': 'me'});
    await set('availability/me', {'busy': []});
    await set('friendships/me/list/anna', {'name': 'Anna'});
    await set('friendships/anna/list/me', {'name': 'Gabi'});
    await set('friendships/anna/list/bela', {'name': 'Béla'}); // más barátság: marad
    await set('requests/me/items/cili', {'fromName': 'Cili'});
    await set('blocks/me/list/dani', {'name': 'Dani'});
    await set('nudges/me/items/x', {'text': 'szia'});
    await set('nudgeSettings/me', {'off': false});
    await set('inbox/me/items/e1', {'title': 'Program'});
    await set('events/e1', {'ownerUid': 'me', 'title': 'Pizza'});
    await set('challenges/own', {
      'ownerUid': 'me',
      'members': ['me', 'anna'],
    });
    await set('challenges/own/progress/me', {'done': []});
    await set('challenges/own/progress/anna', {'done': []});
    await set('challenges/joined', {
      'ownerUid': 'anna',
      'members': ['me', 'anna'],
      'names': {'me': 'Gabi', 'anna': 'Anna'},
    });
    await set('challenges/joined/progress/me', {'done': []});
    await set('challenges/joined/progress/anna', {'done': []});
    await set('people/anna', {'name': 'Anna', 'code': 'ZZZ222'});

    await eraseSocialData(db, 'me', sharedEventIds: ['e1']);

    for (final path in [
      'people/me',
      'profiles/me',
      'codes/ABC234',
      'availability/me',
      'friendships/me/list/anna',
      'friendships/anna/list/me',
      'requests/me/items/cili',
      'blocks/me/list/dani',
      'nudges/me/items/x',
      'nudgeSettings/me',
      'inbox/me/items/e1',
      'events/e1',
      'challenges/own',
      'challenges/own/progress/me',
      'challenges/own/progress/anna',
      'challenges/joined/progress/me',
    ]) {
      expect((await db.doc(path).get()).exists, isFalse, reason: path);
    }
    // Ami másé, megmarad; a közös kihívásból csak kilépett.
    expect((await db.doc('people/anna').get()).exists, isTrue);
    expect((await db.doc('friendships/anna/list/bela').get()).exists, isTrue);
    final joined = (await db.doc('challenges/joined').get()).data()!;
    expect(joined['members'], ['anna']);
    expect((joined['names'] as Map).containsKey('me'), isFalse);
    expect((await db.doc('challenges/joined/progress/anna').get()).exists, isTrue);
  });
}
