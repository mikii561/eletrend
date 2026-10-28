import 'dart:convert';
import 'dart:typed_data';

import 'package:eletrend/event_background.dart';
import 'package:eletrend/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  test('háttérfotó: 1000 px-re kicsinyítve, JPEG; a program menti', () {
    final big = img.Image(width: 2400, height: 1600);
    img.fill(big, color: img.ColorRgb8(200, 80, 120));
    final encoded = EventBackgrounds.encode(Uint8List.fromList(img.encodePng(big)))!;
    final back = img.decodeJpg(base64Decode(encoded))!;
    expect(back.width, 1000);
    expect(base64Decode(encoded).length, lessThan(150000));
    expect(EventBackgrounds.encode(Uint8List.fromList([1, 2, 3])), isNull);

    final e = Event(id: '1', title: 'Buli', date: DateTime(2026, 11, 7))..bgTheme = 'party';
    final again = Event.fromJson(e.toJson());
    expect(again.bgTheme, 'party');
    expect(themeFor('party')!.emoji, '🎉');
  });
}
