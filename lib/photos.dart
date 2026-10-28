import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

/// A naplófotók kezelése: kiválasztás, az app saját mappájába másolás, törlés.
/// A fotók csak a telefonon maradnak, sehova nem töltődnek fel.
class Photos {
  static final _picker = ImagePicker();

  /// Böngészőben nincs tartós fájltárolás, ott a fotó funkció nem elérhető.
  static bool get supported => !kIsWeb;

  /// Fotó készítése vagy választása; az elmentett fájl útvonalát adja vissza.
  static Future<String?> pick(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, maxWidth: 1600, imageQuality: 85);
    if (picked == null) return null;
    final dir = Directory('${(await getApplicationDocumentsDirectory()).path}/photos');
    await dir.create(recursive: true);
    final path = '${dir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
    await File(picked.path).copy(path);
    return path;
  }

  static Future<void> delete(String? path) async {
    if (path == null || !supported) return;
    final f = File(path);
    if (await f.exists()) await f.delete();
  }
}

/// Saját kép címkéhez vagy hangulathoz: négyzetre vágva, kicsire méretezve,
/// base64-ben mentjük az adatok mellé, így böngészőben is működik.
class TagImages {
  static final _picker = ImagePicker();

  /// A képválasztó; tesztben lecserélhető.
  @visibleForTesting
  static Future<XFile?> Function(ImageSource source) pickFile =
      (source) => _picker.pickImage(source: source, maxWidth: 1024, maxHeight: 1024);

  /// Ekkora (px) négyzetes PNG lesz a képből.
  static const size = 128;

  /// A napi hangulatfotó mérete: kisebb, mert minden naphoz tartozhat egy.
  static const dayPhotoSide = 112;

  static final _decoded = <String, Uint8List>{};

  /// base64 kép bájtjai; a legutóbbiakat megjegyzi, hogy ne dekódoljuk minden rajzoláskor.
  static Uint8List decode(String base64) {
    final hit = _decoded.remove(base64);
    final bytes = hit ?? base64Decode(base64);
    _decoded[base64] = bytes;
    if (_decoded.length > 60) _decoded.remove(_decoded.keys.first);
    return bytes;
  }

  /// Kép választása vagy fotózása. Null, ha a felhasználó meggondolta magát;
  /// [UnsupportedImage], ha a képet nem tudjuk megnyitni (pl. HEIC).
  static Future<String?> pick(ImageSource source, {int side = size}) async {
    final picked = await pickFile(source);
    if (picked == null) return null;
    return base64Encode(await squareThumbnail(await picked.readAsBytes(), side: side));
  }

  /// A kép közepéből kivágott, [side] méretű négyzet PNG-ként.
  /// Nem a böngészőre bízzuk a kicsinyítést, mert az néha az eredeti, több MB-os
  /// képet adja vissza, ami nem fér el a tárhelyen.
  static Future<Uint8List> squareThumbnail(Uint8List bytes, {int side = size}) async {
    final ui.Image src;
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      src = (await codec.getNextFrame()).image;
    } catch (_) {
      throw const UnsupportedImage();
    }
    final crop = min(src.width, src.height).toDouble();
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawImageRect(
      src,
      Rect.fromLTWH((src.width - crop) / 2, (src.height - crop) / 2, crop, crop),
      Rect.fromLTWH(0, 0, side.toDouble(), side.toDouble()),
      Paint()..filterQuality = FilterQuality.medium,
    );
    final thumb = await recorder.endRecording().toImage(side, side);
    final data = await thumb.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }
}

class UnsupportedImage implements Exception {
  const UnsupportedImage();

  @override
  String toString() => 'Ezt a képet nem tudom megnyitni. Válassz JPG vagy PNG képet (a HEIC formátum nem megy).';
}
