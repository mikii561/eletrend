import 'dart:convert';
import 'dart:typed_data';

import 'package:eletrend/admin.dart';
import 'package:eletrend/screens/account_section.dart';
import 'package:eletrend/screens/admin_screen.dart';
import 'package:eletrend/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

/// Egy „képernyőkép” PNG-ben, a megadott méretben.
Uint8List screenshot(int w, int h) {
  final image = img.Image(width: w, height: h);
  img.fill(image, color: img.ColorRgb8(244, 233, 218));
  img.fillRect(image, x1: 0, y1: 0, x2: w, y2: h ~/ 8, color: img.ColorRgb8(89, 9, 7));
  for (var i = 0; i < 40; i++) {
    img.fillRect(image, x1: 20, y1: h ~/ 6 + i * 30, x2: w - 20 - (i * 37) % (w ~/ 2), y2: h ~/ 6 + i * 30 + 12, color: img.ColorRgb8(43, 23, 20));
  }
  return Uint8List.fromList(img.encodePng(image));
}

void main() {
  setUpAll(() => initializeDateFormatting('hu'));

  test('képernyőkép előkészítése: kisebb JPEG, legfeljebb 1280 px; nem kép → hiba', () {
    final out = Admin.prepareScreenshot(screenshot(1440, 3120));
    expect(out.length, lessThanOrEqualTo(Admin.maxScreenshotBytes));
    final decoded = img.decodeJpg(out)!;
    expect(decoded.height, lessThanOrEqualTo(1280));
    expect(() => Admin.prepareScreenshot(Uint8List.fromList([1, 2, 3])), throwsFormatException);
  });

  testWidgets('bejelentés képernyőképpel: csatolás, eltávolítás, küldés; az admin látja', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = signInFakeAccount();
    SharedPreferences.setMockInitialValues({});
    final store = (await tester.runAsync(AppStore.load))!..setMyName('Gabi');
    final shots = (await tester.runAsync(() async => [screenshot(400, 800), screenshot(500, 900)]))!;

    await tester.pumpWidget(
      StoreScope(
        store: store,
        child: MaterialApp(home: Scaffold(body: FeedbackSheet(pick: (limit) async => shots.take(limit).toList()))),
      ),
    );
    await tester.tap(find.text('Képernyőkép csatolása'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsNWidgets(2));
    expect(find.text('Még egy (2/3)'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Kép eltávolítása').first);
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsOneWidget);

    // Szöveg nélkül nem megy el.
    await tester.tap(find.text('Küldés'));
    await tester.pump();
    expect(find.text('Írd le pár szóban, mi történt.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'A naptárban eltűnt egy program.');
    await tester.tap(find.text('Küldés'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    final sent = (await tester.runAsync(() => db.collection('feedback').get()))!.docs.single.data();
    expect(sent['text'], 'A naptárban eltűnt egy program.');
    expect(sent['images'], hasLength(1));
    expect(img.decodeJpg(base64Decode((sent['images'] as List).single as String)), isNotNull);

    // Az admin felületen a képernyőkép is látszik, és nagyítható.
    await tester.pumpWidget(const MaterialApp(home: AdminScreen()));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Visszajelzések'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Visszajelzések'));
    await tester.pumpAndSettle();
    expect(find.text('A naptárban eltűnt egy program.'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('1. képernyőkép megnyitása'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Bezárás'), findsOneWidget);
  });
}
