import 'dart:math';

import 'package:eletrend/friends.dart';
import 'package:eletrend/models.dart';
import 'package:eletrend/store.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AppStore> device(String name) async {
  SharedPreferences.resetStatic();
  SharedPreferences.setMockInitialValues({});
  return (await AppStore.load())..setMyName(name);
}

void main() {
  test('barátkód → jelölés → elfogadás; sorozat csak engedéllyel; meghívás egy gombnyomással', () async {
    final db = FakeFirebaseFirestore();
    final gabiStore = await device('Gabi');
    final annaStore = await device('Anna');
    final gabi = Friends(db: db);
    final anna = Friends(db: db);
    await gabi.start('gabi', gabiStore, random: Random(1));
    await anna.start('anna', annaStore, random: Random(2));
    expect(gabi.myCode, hasLength(6));
    expect(gabi.myCode, isNot(anna.myCode));
    expect(gabi.myCode, isNot(matches(RegExp('[01OIL]'))));

    // Hibás és saját kód
    await expectLater(anna.addByCode('ABC'), throwsA(isA<FriendException>()));
    await expectLater(anna.addByCode('ZZZZZZ'), throwsA(isA<FriendException>()));
    await expectLater(anna.addByCode(anna.myCode!), throwsA(isA<FriendException>()));

    // Anna jelöli Gabit (kisbetűvel, szóközzel is jó)
    await anna.addByCode(' ${gabi.myCode!.toLowerCase()} ');
    final requests = await gabi.watchRequests().first;
    expect(requests.single.fromName, 'Anna');
    await gabi.accept(requests.single);
    expect(await gabi.watchRequests().first, isEmpty);
    await expectLater(anna.addByCode(gabi.myCode!), throwsA(isA<FriendException>())); // már barátok

    // Sorozat: alapból nem látszik
    gabiStore.addHabit('Edzés');
    final h = gabiStore.habits.single;
    for (var i = 0; i < 3; i++) {
      h.doneDays.add(dayKey(addDays(DateTime.now(), -i)));
    }
    await gabi.start('gabi', gabiStore); // névjegy frissítése
    expect((await anna.watchFriends().first).single.streaks, isEmpty);
    gabiStore.setPrivacy(shareStreaks: true);
    await gabi.start('gabi', gabiStore);
    var seen = (await anna.watchFriends().first).single;
    expect(seen.name, 'Gabi');
    expect(seen.streaks.single, ('Edzés', 3));
    expect(seen.birthday, isNull);

    // Születésnap: csak engedéllyel, és csak hónap-nap (év nélkül)
    gabiStore.setBirthday('1999-11-03');
    await gabi.start('gabi', gabiStore);
    expect((await anna.watchFriends().first).single.birthday, isNull);
    gabiStore.setPrivacy(shareBirthday: true);
    await gabi.start('gabi', gabiStore);
    seen = (await anna.watchFriends().first).single;
    expect(seen.birthday, '11-03');
    expect((await db.collection('people').doc('gabi').get()).data().toString(), isNot(contains('1999')));

    // A barátlista az eszközön is megmarad (offline nézethez, születésnap-emlékeztetőhöz)
    await anna.refreshCache();
    expect(annaStore.friendsCache.single.name, 'Gabi');
    expect(annaStore.friendsCache.single.birthday, '11-03');

    // Gabi meghívja Annát egy programra: Annánál a Meghívásaim közé kerül
    final event = Event(id: 'e', title: 'Pizza', start: DateTime(2030, 11, 6, 19))..shareId = 'megosztott1';
    expect(await gabi.invite(event, ['anna']), isEmpty);
    final sub = anna.listenInbox();
    await pumpEventQueue();
    await sub.cancel();
    expect(annaStore.invites.single.title, 'Pizza');
    expect(annaStore.invites.single.fromName, 'Gabi');
    expect((await db.collection('inbox').doc('anna').collection('items').get()).docs, isEmpty);

    // Jelentés az adminnak
    await anna.report(userUid: 'gabi', reason: 'teszt');
    final reports = await db.collection('reports').get();
    expect(reports.docs.single.data()['reporterUid'], 'anna');

    // Eltávolítás mindkét oldalról
    await anna.remove('gabi');
    expect(await gabi.watchFriends().first, isEmpty);
    gabi.stop();
    anna.stop();
  });

  test('letiltás: a barátság megszűnik, a letiltott listán látszik, feloldható', () async {
    final db = FakeFirebaseFirestore();
    final gabiStore = await device('Gabi');
    final annaStore = await device('Anna');
    final gabi = Friends(db: db);
    final anna = Friends(db: db);
    await gabi.start('gabi', gabiStore, random: Random(1));
    await anna.start('anna', annaStore, random: Random(2));
    await anna.addByCode(gabi.myCode!);
    await gabi.accept((await gabi.watchRequests().first).single);
    expect(await gabi.watchFriends().first, hasLength(1));

    await gabi.block('anna', 'Anna');
    expect(await gabi.watchFriends().first, isEmpty);
    expect(await anna.watchFriends().first, isEmpty);
    expect(await gabi.watchBlocked().first, {'anna': 'Anna'});

    await gabi.unblock('anna');
    expect(await gabi.watchBlocked().first, isEmpty);
    gabi.stop();
    anna.stop();
  });
}
