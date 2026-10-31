import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:eletrend/friends.dart';
import 'package:eletrend/screens/profile_screen.dart';
import 'package:eletrend/square_image.dart';
import 'package:eletrend/store.dart';
import 'package:eletrend/widgets/common.dart';
import 'package:eletrend/widgets/profile_photo_button.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

Future<AppStore> device(String name) async {
  SharedPreferences.resetStatic();
  SharedPreferences.setMockInitialValues({});
  return (await AppStore.load())..setMyName(name);
}

String samplePhoto() {
  final picture = img.Image(width: 900, height: 500);
  img.fill(picture, color: img.ColorRgb8(60, 110, 140));
  img.fillCircle(picture, x: 450, y: 250, radius: 150, color: img.ColorRgb8(245, 230, 200));
  return prepareProfilePhoto(Uint8List.fromList(img.encodePng(picture)));
}

void main() {
  setUp(signInFakeAccount);
  setUpAll(() => initializeDateFormatting('hu'));

  test('profilkép: négyzetre vágva, 256 px, kicsi; rossz fájlra magyar hiba', () {
    final photo = samplePhoto();
    final decoded = img.decodeJpg(base64Decode(photo))!;
    expect([decoded.width, decoded.height], [256, 256]);
    expect(photo.length, lessThan(40000)); // belefér a névjegy dokumentumába
    expect(() => prepareProfilePhoto(Uint8List.fromList([1, 2, 3])), throwsA(isA<FormatException>()));
  });

  test('profilkép: megmarad az újraindítás után, és a barát is látja a névjegyen', () async {
    final db = FakeFirebaseFirestore();
    final gabiStore = await device('Gabi');
    final photo = samplePhoto();
    gabiStore.setProfilePhoto(photo);
    expect(gabiStore.profilePhoto, photo);
    expect(gabiStore.exportData().toString(), contains(photo.substring(0, 40)));

    final gabi = Friends(db: db);
    final anna = Friends(db: db);
    await gabi.start('gabi', gabiStore, random: Random(1));
    final annaStore = await device('Anna');
    await anna.start('anna', annaStore, random: Random(2));
    await anna.addByCode(gabi.myCode!);
    await gabi.accept((await gabi.watchRequests().first).single);

    expect((await anna.watchFriends().first).single.photo, photo);
    // Törlés után a barátnál sincs.
    gabiStore.setProfilePhoto('');
    await gabi.start('gabi', gabiStore);
    expect((await anna.watchFriends().first).single.photo, '');
    gabi.stop();
    anna.stop();
  });

  testWidgets('profil: a névjegyen a saját kép látszik, és koppintásra kamera/galéria választható', (tester) async {
    tester.view.physicalSize = const Size(400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = (await tester.runAsync(() => device('Gabi')))!;
    await tester.pumpWidget(
      StoreScope(
        store: store,
        child: const MaterialApp(home: ProfileScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ProfilePhotoButton), findsOneWidget);

    store.setProfilePhoto(samplePhoto());
    await tester.pumpAndSettle();
    final avatar = tester.widget<NameAvatar>(find.byType(NameAvatar).first);
    expect(avatar.photo, store.profilePhoto);

    await tester.tap(find.byType(ProfilePhotoButton));
    await tester.pumpAndSettle();
    expect(find.text('Fotó készítése'), findsOneWidget);
    expect(find.text('Kép a galériából'), findsOneWidget);
    await tester.tap(find.text('Kép törlése'));
    await tester.pumpAndSettle();
    expect(store.profilePhoto, '');
  });
}
