import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Kép négyzetre vágva (középen), [side] px-esre kicsinyítve, JPEG base64-ben.
/// Profilképnek és kihívás-ikonnak: pár tíz KB, így a Firestore-dokumentumba is belefér.
/// Ha a kép nem nyitható meg, [FormatException] a hiba (magyar üzenettel).
String squareJpegBase64(Uint8List bytes, {required int side, int quality = 80}) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) throw const FormatException('Ezt a képet nem tudom megnyitni. Próbálj JPG-t vagy PNG-t.');
  final oriented = img.bakeOrientation(decoded);
  final shortSide = oriented.width < oriented.height ? oriented.width : oriented.height;
  final square = img.copyCrop(
    oriented,
    x: (oriented.width - shortSide) ~/ 2,
    y: (oriented.height - shortSide) ~/ 2,
    width: shortSide,
    height: shortSide,
  );
  final small = shortSide > side ? img.copyResize(square, width: side, height: side) : square;
  return base64Encode(img.encodeJpg(small, quality: quality));
}

/// Profilkép: 256 px-es négyzet.
String prepareProfilePhoto(Uint8List bytes) => squareJpegBase64(bytes, side: 256);
