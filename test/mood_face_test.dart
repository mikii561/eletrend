import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:eletrend/photos.dart';
import 'package:eletrend/screens/tags_screen.dart';
import 'package:eletrend/store.dart';
import 'package:eletrend/widgets/tag_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Nagy, telefonos fotó méretű kép.
Future<XFile> bigPhoto() async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(const Rect.fromLTWH(0, 0, 3000, 2000), Paint()..color = Colors.orange);
  final image = await recorder.endRecording().toImage(3000, 2000);
  final png = (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
  return XFile.fromData(png, name: 'IMG_2026.png', mimeType: 'image/png');
}

void main() {
  testWidgets('saját kép a hangulatarcnak: kiválasztás, mentés, megjelenés', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = await AppStore.load();
    final photo = (await tester.runAsync(bigPhoto))!;
    TagImages.pickFile = (_) async => photo;

    await tester.pumpWidget(StoreScope(store: store, child: const MaterialApp(home: TagsScreen())));
    await tester.tap(find.text('Nagyon jó'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Saját kép'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Választás a galériából'));
    // A kép feldolgozása valódi aszinkron munka: váltogatva engedjük futni.
    for (var i = 0; i < 20 && find.text('Kép eltávolítása (vissza az emojihoz)').evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.text('Kép eltávolítása (vissza az emojihoz)'), findsOneWidget);

    await tester.tap(find.text('Mentés'));
    await tester.pumpAndSettle();
    final face = store.moodFace(5);
    expect(face.image, isNotNull);
    // Kicsi maradt: elfér a böngésző tárhelyén is.
    expect(face.image!.length, lessThan(60000));
    expect(find.byWidgetPredicate((w) => w is Image && w.image is MemoryImage), findsWidgets);
    expect(find.byType(MoodFace), findsNWidgets(5));
  });

  testWidgets('olvashatatlan képnél hibaüzenet a lapon', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = await AppStore.load();
    TagImages.pickFile = (_) async => XFile.fromData(Uint8List.fromList([1, 2, 3]), name: 'IMG.heic');

    await tester.pumpWidget(StoreScope(store: store, child: const MaterialApp(home: TagsScreen())));
    await tester.tap(find.text('Nagyon jó'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Saját kép'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Választás a galériából'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
    await tester.pumpAndSettle();
    expect(find.textContaining('HEIC'), findsOneWidget);
  });
}
