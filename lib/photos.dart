import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
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

/// Saját címkekép: kicsire méretezve, base64-ben a címke mellé mentjük,
/// így böngészőben is működik.
class TagImages {
  static final _picker = ImagePicker();

  static Future<String?> pick(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, maxWidth: 160, maxHeight: 160, imageQuality: 90);
    if (picked == null) return null;
    return base64Encode(await picked.readAsBytes());
  }
}
