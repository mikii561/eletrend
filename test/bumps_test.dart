import 'dart:convert';
import 'dart:typed_data';

import 'package:eletrend/bumps.dart';
import 'package:eletrend/screens/bump_screens.dart';
import 'package:eletrend/store.dart';
import 'package:eletrend/widgets/effects.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() => initializeDateFormatting('hu'));

  test('bump: küldés, azonnali fogadás, látott, törlés, beállítások', () async {
    final db = FakeFirebaseFirestore();
    final gabi = Bumps(db: db);
    final anna = Bumps(db: db);
    final received = <Bump>[];
    gabi.start('gabi', (_) {});
    anna.start('anna', received.add);

    await gabi.send('anna', const Bump(fromUid: 'gabi', fromName: 'Gabi', text: 'Pizza!', sticker: '🍕', effect: BumpEffect.confetti, eventId: 'e1', eventTitle: 'Pizzaest'));
    await pumpEventQueue();
    expect(received.single.headline, '🍕 Gabi bumpolt: Pizza!');
    expect(received.single.effect, BumpEffect.confetti);
    expect(received.single.eventTitle, 'Pizzaest');

    await anna.markSeen(received.single.id);
    expect((await anna.watchAll().first).single.seen, isTrue);
    // A látott nem jön újra visszatéréskor
    await anna.checkNow();
    expect(received.length, 1);

    await anna.setOff(true);
    await anna.setMuted('gabi', true);
    final s = await anna.settings();
    expect(s.off, isTrue);
    expect(s.muted, {'gabi'});

    await anna.delete(received.single.id);
    expect(await anna.watchAll().first, isEmpty);
    gabi.stop();
    anna.stop();
  });

  test('kép a bumphoz: fotó kicsinyítve JPEG-be, GIF változatlanul, túl nagy GIF nem', () {
    final photo = img.Image(width: 1600, height: 1200);
    final jpeg = Bumps.prepareImage(Uint8List.fromList(img.encodePng(photo)), name: 'foto.png');
    expect(img.decodeJpg(base64Decode(jpeg))!.width, 700);

    final gif = Uint8List.fromList(img.encodeGif(img.Image(width: 50, height: 50)));
    expect(base64Decode(Bumps.prepareImage(gif, name: 'tanc.gif')), gif);
    final huge = Uint8List.fromList([0x47, 0x49, 0x46, ...List.filled(Bumps.maxImageBytes + 10, 0)]);
    expect(() => Bumps.prepareImage(huge), throwsA(isA<BumpException>()));
    expect(() => Bumps.prepareImage(Uint8List.fromList([1, 2, 3])), throwsA(isA<BumpException>()));
  });

  testWidgets('bump írása: matrica, effekt, küldés', (tester) async {
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = FakeFirebaseFirestore();
    Bumps.instance = Bumps(db: db)..start('gabi', (_) {});
    SharedPreferences.setMockInitialValues({});
    final store = (await tester.runAsync(AppStore.load))!..setMyName('Gabi');

    await tester.pumpWidget(StoreScope(
      store: store,
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(onPressed: () => showBumpComposer(context, to: {'anna': 'Anna'}), child: const Text('Bump')),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Bump'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Gyere!');
    await tester.tap(find.text('🎉').first);
    await tester.tap(find.text('🎆 Tűzijáték'));
    await tester.pump();
    await tester.ensureVisible(find.text('Bump küldése'));
    await tester.tap(find.text('Bump küldése'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 4)); // az effekt is lefut
    final sent = (await tester.runAsync(() => db.collection('bumps').doc('anna').collection('items').get()))!;
    final d = sent.docs.single.data();
    expect(d['text'], 'Gyere!');
    expect(d['sticker'], '🎉');
    expect(d['effect'], 'fireworks');
    expect(d['fromUid'], 'gabi');
    expect(d['fromName'], 'Gabi');
    Bumps.instance.stop();
  });
}
