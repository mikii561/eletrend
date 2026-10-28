// Az app ikonjának megrajzolása. Futtatás: flutter test tool/icon_test.dart
// Utána: dart run flutter_launcher_icons && dart run flutter_native_splash:create
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// A márkaszín (theme.dart), egy árnyalaton belül, hogy ne legyen tarka.
const _gradient = [Color(0xFF0F766E), Color(0xFF115E59)];

/// A jel: kör, benne pipa, a kör nyílásában egy kis nap. [scale] a 1024-es vászonhoz képest.
void _drawSymbol(Canvas c, double scale) {
  c.save();
  c.translate(512, 512);
  c.scale(scale);
  c.translate(-512, -512);
  final white = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  c.drawArc(Rect.fromCircle(center: const Offset(512, 512), radius: 300), -1.05, 5.4, false, white..strokeWidth = 72);
  c.drawPath(
    Path()
      ..moveTo(372, 522)
      ..lineTo(478, 626)
      ..lineTo(668, 420),
    white..strokeWidth = 84,
  );
  c.drawCircle(const Offset(536, 213), 58, Paint()..color = const Color(0xFFF59E0B));
  c.restore();
}

Future<void> _save(String path, void Function(Canvas c) draw) async {
  final recorder = ui.PictureRecorder();
  draw(Canvas(recorder));
  final image = await recorder.endRecording().toImage(1024, 1024);
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  File(path).writeAsBytesSync(png!.buffer.asUint8List());
}

void main() {
  test('ikonok rajzolása', () async {
    const full = Rect.fromLTWH(0, 0, 1024, 1024);
    final bg = Paint()..shader = const LinearGradient(colors: _gradient, begin: Alignment.topLeft, end: Alignment.bottomRight).createShader(full);

    // Teljes ikon (régi Android, web)
    await _save('assets/icon/icon.png', (c) {
      c.drawRect(full, bg);
      _drawSymbol(c, 0.8);
    });
    // Adaptív ikon előtere: a jel a középső biztonságos zónában, átlátszó háttéren
    await _save('assets/icon/icon_foreground.png', (c) => _drawSymbol(c, 0.55));
    // Adaptív ikon háttere
    await _save('assets/icon/icon_background.png', (c) => c.drawRect(full, bg));
    // Indítóképernyő: csak a jel
    await _save('assets/icon/splash.png', (c) => _drawSymbol(c, 0.9));
  });
}
