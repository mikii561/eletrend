import 'package:eletrend/account.dart';
import 'package:eletrend/challenges.dart';
import 'package:eletrend/admin.dart';
import 'package:eletrend/friends.dart';
import 'package:eletrend/main.dart';
import 'package:eletrend/models.dart';
import 'package:eletrend/store.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Egy „új eszköz”: üres helyi tárhely.
Future<AppStore> freshDevice([Map<String, Object> prefs = const {}]) {
  SharedPreferences.resetStatic();
  SharedPreferences.setMockInitialValues(prefs);
  return AppStore.load();
}

Future<int> count(FakeFirebaseFirestore db, String uid, String kind) async =>
    (await db.collection('users').doc(uid).collection(kind).get()).docs.length;

void main() {
  setUpAll(() => initializeDateFormatting('hu'));

  test('regisztráció: a régi helyi adatok a fiókba kerülnek, másik eszközön ugyanazok jönnek le', () async {
    final db = FakeFirebaseFirestore();
    final user = MockUser(uid: 'u1', email: 'gabi@pelda.hu');

    // 1. eszköz: már van adat, most regisztrál
    final phone = await freshDevice();
    phone.addHabit('Séta');
    phone.saveTask(TaskItem(id: 't1', title: 'Számla befizetése', due: DateTime(2026, 10, 27)));
    phone.saveEvent(Event(id: 'e1', title: 'Foci', start: DateTime(2026, 10, 29, 18), repeat: Repeat.weekly));
    phone.saveGroup(FriendGroup(id: 'g1', name: 'Foci csapat', members: ['x']));
    phone.setMyName('Gabi');
    final account = Account(
      auth: MockFirebaseAuth(mockUser: user),
      db: db,
    );
    final u = await account.register(name: 'Gabi', email: 'gabi@pelda.hu', password: 'titok123');
    final phoneSync = CloudSync(store: phone, uid: u.uid, db: db);
    await phoneSync.start();
    expect(await count(db, u.uid, 'habits'), 1);
    expect(await count(db, u.uid, 'tasks'), 1);
    expect(await count(db, u.uid, 'groups'), 1);

    // Módosítás és törlés is felkerül, de csak ami változott
    phone.addHabit('Olvasás');
    phone.removeEvent(phone.events.single);
    await phoneSync.push();
    expect(await count(db, u.uid, 'habits'), 2);
    expect(await count(db, u.uid, 'events'), 0);

    // 2. eszköz (pl. a weboldal): üres, bejelentkezik
    final web = await freshDevice();
    await CloudSync(store: web, uid: u.uid, db: db).start();
    expect(web.habits.map((h) => h.name), ['Séta', 'Olvasás']);
    expect(web.tasks.single.title, 'Számla befizetése');
    expect(web.groups.single.name, 'Foci csapat');
    expect(web.myName, 'Gabi');
    expect(web.events, isEmpty);

    // A weboldalon írt bejegyzés a telefonon is megjelenik visszatéréskor
    final webSync = CloudSync(store: web, uid: u.uid, db: db);
    web.toggleTask(web.tasks.single);
    await webSync.push();
    await phoneSync.refresh();
    expect(phone.tasks.single.done, isTrue);
  });

  test('ismert eszköz offline módosítása is felkerül; kijelentkezéskor minden lekerül', () async {
    final db = FakeFirebaseFirestore();
    final phone = await freshDevice();
    phone.addHabit('Víz');
    final sync = CloudSync(store: phone, uid: 'u1', db: db);
    await sync.start();

    // Az app újraindul (új CloudSync példány), közben offline kipipált egy célt
    phone.toggleHabit(phone.habits.single, DateTime(2026, 10, 28));
    final again = CloudSync(store: phone, uid: 'u1', db: db);
    expect(again.knownDevice, isTrue);
    await again.start();
    final cloud = await db.collection('users').doc('u1').collection('habits').get();
    expect(cloud.docs.single.data()['doneDays'], contains('2026-10-28'));

    await phone.clearAll();
    expect(phone.habits, isEmpty);
    expect(phone.syncUid, isNull);
  });

  testWidgets('első indítás: regisztráció nélkül nem megy, regisztráció után indul az app', (tester) async {
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = FakeFirebaseFirestore();
    Account.instance = Account(
      auth: MockFirebaseAuth(
        mockUser: MockUser(uid: 'u9', email: 'anna@pelda.hu'),
      ),
      db: db,
    );
    Admin.instance = Admin(db: db);
    Friends.instance = Friends(db: db);
    Challenges.instance = Challenges(db: db);
    final store = (await tester.runAsync(() => freshDevice()))!;

    await tester.pumpWidget(LifeupApp(store: store));
    await tester.pumpAndSettle();
    expect(find.text('Fiók létrehozása'), findsOneWidget);

    // Hiányos adatoknál magyar hibaüzenet
    await tester.tap(find.text('Fiók létrehozása'));
    await tester.pump();
    expect(find.text('Add meg a neved.'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Neved'), 'Anna');
    await tester.enterText(find.widgetWithText(TextField, 'E-mail-cím'), 'anna@pelda.hu');
    await tester.enterText(find.widgetWithText(TextField, 'Jelszó (legalább 6 karakter)'), 'titok123');
    await tester.tap(find.text('Fiók létrehozása'));
    await tester.pumpAndSettle();

    expect(find.text('Üdv a LIFEUP-ban!'), findsOneWidget); // új, üres fiók: a bevezető jön
    expect(store.myName, 'Anna');
    final uid = Account.instance.user!.uid;
    expect((await tester.runAsync(() => count(db, uid, 'meta')))!, 1);
    Account.instance.sync?.stop();
    Friends.instance.stop();
    Challenges.instance.stop();
  });

  test('Google-belépés: új fiók, és névtelen vendégből is fiók lesz', () async {
    final db = FakeFirebaseFirestore();
    final google = MockUser(uid: 'g1', email: 'anna@gmail.com', displayName: 'Anna');
    final account = Account(
      auth: MockFirebaseAuth(mockUser: google),
      db: db,
    );
    final u = await account.signInWithGoogle();
    expect(u.email, 'anna@gmail.com');
    expect(account.user, isNotNull);
  });
  test('letöltés nem írja felül a még fel nem töltött helyi változást', () async {
    final db = FakeFirebaseFirestore();
    final phone = await freshDevice();
    phone.addHabit('Séta');
    final phoneSync = CloudSync(store: phone, uid: 'u2', db: db);
    await phoneSync.start();

    // Másik eszközön új cél kerül fel.
    final web = await freshDevice();
    final webSync = CloudSync(store: web, uid: 'u2', db: db);
    await webSync.start();
    web.addHabit('Olvasás');
    await webSync.push();

    // A telefonon közben (pl. offline) új cél, még nincs fent: a letöltés nem törölheti.
    phone.addHabit('Edzés');
    await phoneSync.pull();
    expect(phone.habits.map((h) => h.name), contains('Edzés'));

    // Feltöltés, aztán letöltés: minden megvan mindkét helyen.
    await phoneSync.refresh();
    expect(phone.habits.map((h) => h.name).toSet(), {'Séta', 'Edzés', 'Olvasás'});
    await webSync.refresh();
    expect(web.habits.map((h) => h.name).toSet(), {'Séta', 'Edzés', 'Olvasás'});
  });
}
