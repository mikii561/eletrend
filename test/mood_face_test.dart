import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:eletrend/photos.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:eletrend/screens/journal_screen.dart';
import 'package:eletrend/screens/tags_screen.dart';
import 'package:eletrend/screens/today_screen.dart';
import 'package:eletrend/store.dart';
import 'package:eletrend/widgets/tag_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/date_symbol_data_local.dart';
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
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
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

    await tester.ensureVisible(find.text('Mentés'));
    await tester.pumpAndSettle();
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

  testWidgets('napló: mai arc fotóval, és az arcsáv szerkesztése helyben', (tester) async {
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await initializeDateFormatting('hu');
    SharedPreferences.setMockInitialValues({'onboarded': true});
    final store = await AppStore.load();
    final photo = (await tester.runAsync(bigPhoto))!;
    TagImages.pickFile = (_) async => photo;
    final day = DateTime(2026, 10, 28);

    await tester.pumpWidget(StoreScope(store: store, child: MaterialApp(home: JournalEditor(date: day))));
    await tester.tap(find.text('Csak mára fotó'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Választás a galériából'));
    for (var i = 0; i < 20 && find.text('Fotó cseréje').evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await tester.pump();
    }
    expect(find.text('Fotó cseréje'), findsOneWidget);

    // Szerkesztő mód: arcra koppintva a hangulat szerkesztője nyílik, nem választás történik.
    await tester.tap(find.byTooltip('Arcok szerkesztése'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(MoodButton).first);
    await tester.pumpAndSettle();
    expect(find.text('Hangulat: 1/5'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Nagyon rossz'), 'Pocsék');
    await tester.tap(find.text('Mentés').last);
    await tester.pumpAndSettle();
    expect(store.moodFace(1).name, 'Pocsék');
    await tester.tap(find.byTooltip('Kész'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mentés'));
    await tester.pumpAndSettle();
    final entry = store.entryFor(day)!;
    expect(entry.moodImage, isNotNull);
    expect(entry.moodImage!.length, lessThan(40000));
    expect((await AppStore.load()).entryFor(day)!.moodImage, entry.moodImage);
  });

  testWidgets('napló: a mai fotó egy gombbal végleges arc lesz, hosszan nyomva is szerkeszthető', (tester) async {
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await initializeDateFormatting('hu');
    SharedPreferences.setMockInitialValues({'onboarded': true});
    final store = await AppStore.load();
    final photo = (await tester.runAsync(bigPhoto))!;
    TagImages.pickFile = (_) async => photo;

    await tester.pumpWidget(StoreScope(store: store, child: MaterialApp(home: JournalEditor(date: DateTime(2026, 10, 28)))));
    await tester.tap(find.text('Csak mára fotó'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Választás a galériából'));
    for (var i = 0; i < 20 && find.text('Legyen mindig ez').evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await tester.pump();
    }
    expect(store.moodFace(3).image, isNull);
    await tester.tap(find.text('Legyen mindig ez'));
    await tester.pumpAndSettle();
    expect(store.moodFace(3).image, isNotNull);
    expect((await AppStore.load()).moodFace(3).image, store.moodFace(3).image);
    // A mai fotó helyett már az arc képe látszik.
    expect(find.text('Csak mára fotó'), findsOneWidget);

    // Hosszú nyomás: az arc szerkesztője nyílik.
    await tester.longPress(find.byType(MoodButton).first);
    await tester.pumpAndSettle();
    expect(find.text('Hangulat: 1/5'), findsOneWidget);
  });

  testWidgets('teljes emojiválasztó: bármelyik emoji kiválasztható a címkéhez', (tester) async {
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final store = await AppStore.load();

    await tester.pumpWidget(StoreScope(store: store, child: const MaterialApp(home: TagsScreen())));
    await tester.tap(find.text('Új címke'));
    await tester.pumpAndSettle();
    expect(find.byType(EmojiPicker), findsOneWidget);

    // Állatok kategória, egy ott lévő emoji
    await tester.tap(find.byIcon(Icons.pets));
    await tester.pumpAndSettle();
    await tester.tap(find.text('🦊'));
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, 'ravasz');
    await tester.ensureVisible(find.text('Mentés'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mentés'));
    await tester.pumpAndSettle();
    expect(store.moodTags.last.name, 'ravasz');
    expect(store.moodTags.last.emoji, '🦊');
  });
}
