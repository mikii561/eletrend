import 'dart:convert';
import 'dart:typed_data';

import 'package:eletrend/nudges.dart';
import 'package:eletrend/screens/nudge_screens.dart';
import 'package:eletrend/store.dart';
import 'package:eletrend/voice.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

Uint8List photo({int width = 1600, int height = 1200}) {
  final picture = img.Image(width: width, height: height);
  img.fill(picture, color: img.ColorRgb8(60, 110, 140));
  img.fillCircle(picture, x: width ~/ 2, y: height ~/ 2, radius: 300, color: img.ColorRgb8(245, 230, 200));
  return Uint8List.fromList(img.encodePng(picture));
}

void main() {
  setUpAll(() => initializeDateFormatting('hu'));

  test('csatolt kép: fotó kicsinyítve JPEG-be, GIF változatlanul, túl nagy GIF és rossz fájl hibával', () {
    final jpeg = img.decodeJpg(base64Decode(prepareAttachmentImage(photo(), name: 'k.png')))!;
    expect(jpeg.width, 800);
    expect(base64Decode(prepareAttachmentImage(photo())).length, lessThan(maxAttachmentImageBytes));

    final gif = Uint8List.fromList(img.encodeGif(img.Image(width: 20, height: 20)));
    expect(base64Decode(prepareAttachmentImage(gif, name: 'a.gif')), gif);
    final big = Uint8List(maxAttachmentImageBytes + 10)..setRange(0, 3, [0x47, 0x49, 0x46]);
    expect(() => prepareAttachmentImage(big, name: 'nagy.gif'), throwsA(isA<AttachmentException>()));
    expect(() => prepareAttachmentImage(Uint8List.fromList([1, 2, 3])), throwsA(isA<AttachmentException>()));
  });

  test('bökés képpel és hanggal: szöveg nélkül is elmegy, a címzett megkapja; teljesen üres nem', () async {
    final db = FakeFirebaseFirestore();
    final gabi = Nudges(db: db)..start('gabi', (_) {});
    final received = <Nudge>[];
    final anna = Nudges(db: db)..start('anna', received.add);
    final image = prepareAttachmentImage(photo());
    final audio = base64Encode([1, 2, 3, 4]);

    await gabi.send('anna', fromName: 'Gabi', text: '', image: image, audio: audio, audioMime: 'audio/mp4');
    await pumpEventQueue();
    final n = received.single;
    expect(n.image, image);
    expect(n.audio, audio);
    expect(n.audioMime, 'audio/mp4');
    expect(n.hasMedia, isTrue);
    expect(n.headline, '👋 Gabi: 📷 kép + 🎙️ hangüzenet');

    // Szöveggel együtt, és csak hanggal.
    // (A teszt-adatbázis nem kényszeríti a napi sorszámot, ezért másik napra küldünk.)
    await gabi.send('anna', fromName: 'Gabi', text: 'Hallgasd meg!', audio: audio, now: DateTime(2030, 1, 2));
    await pumpEventQueue();
    expect(received.last.headline, '👋 Gabi: Hallgasd meg! (🎙️ hangüzenet)');
    expect(received.last.image, isNull);

    await expectLater(gabi.send('anna', fromName: 'Gabi', text: '  '), throwsA(isA<NudgeException>()));
    gabi.stop();
    anna.stop();
  });

  testWidgets('kapott képes/hangos bökés: a kép és a lejátszó gomb látszik, a program megnyitható', (tester) async {
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final nudge = Nudge(
      id: 'x',
      fromName: 'Anna',
      text: 'Nézd ezt!',
      image: prepareAttachmentImage(photo(width: 300, height: 200)),
      audio: base64Encode([1, 2, 3]),
      eventId: 'abcdefghij12',
      eventTitle: 'Pizzaest',
    );
    await tester.pumpWidget(MaterialApp(home: NudgeDetailScreen(nudge: nudge)));
    await tester.pumpAndSettle();
    // (A kép a MaterialApp-ban egy lapváltó átmenet alatt áll, ezért skipOffstage: false.)
    expect(find.byType(Image, skipOffstage: false), findsOneWidget);
    expect(find.text('👋 Nézd ezt!'), findsOneWidget);
    expect(find.text('Hangüzenet lejátszása'), findsOneWidget);
    expect(find.text('Program: Pizzaest'), findsOneWidget);
  });

  testWidgets('bökés írása: van Kép és Hangüzenet gomb; semmi nélkül nem megy el', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});
    final store = (await tester.runAsync(AppStore.load))!;
    await tester.pumpWidget(
      StoreScope(
        store: store,
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showNudgeComposer(context, to: {'anna': 'Anna'}),
              child: const Text('Nyit'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Nyit'));
    await tester.pumpAndSettle();
    expect(find.text('Kép'), findsOneWidget);
    expect(find.text('Hangüzenet'), findsOneWidget);

    await tester.tap(find.text('Bökés küldése'));
    await tester.pumpAndSettle();
    expect(find.textContaining('csatolj képet vagy hangot'), findsOneWidget);
  });
}
