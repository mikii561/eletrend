import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:record/record.dart';

/// Hiba a kép vagy a hang előkészítésekor, magyar üzenettel.
class AttachmentException implements Exception {
  const AttachmentException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Egy bökéshez csatolt kép legfeljebb ekkora lehet (base64 előtt), hogy beférjen egy dokumentumba.
const maxAttachmentImageBytes = 450 * 1024;

/// A hangüzenet hossza legfeljebb.
const maxVoiceDuration = Duration(seconds: 20);

/// Kép a bökéshez: a GIF változatlanul (ha nem túl nagy, hogy mozogjon), a fotó kicsinyítve JPEG-be.
/// Base64-et ad vissza.
String prepareAttachmentImage(Uint8List bytes, {String? name}) {
  final isGif =
      (name ?? '').toLowerCase().endsWith('.gif') ||
      (bytes.length > 3 && bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46);
  if (isGif) {
    if (bytes.length > maxAttachmentImageBytes) {
      throw const AttachmentException('Ez a GIF túl nagy (legfeljebb kb. 450 KB lehet).');
    }
    return base64Encode(bytes);
  }
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw const AttachmentException('Ezt a képet nem tudom megnyitni. Próbálj JPG-t, PNG-t vagy GIF-et.');
  }
  final oriented = img.bakeOrientation(decoded);
  final resized = oriented.width > 800 ? img.copyResize(oriented, width: 800) : oriented;
  var quality = 74;
  var out = img.encodeJpg(resized, quality: quality);
  while (out.length > maxAttachmentImageBytes && quality > 40) {
    quality -= 12;
    out = img.encodeJpg(resized, quality: quality);
  }
  return base64Encode(out);
}

/// Hangüzenet felvétele: kis bitrátával, hogy a bökésbe beférjen.
class VoiceRecorder {
  final _rec = AudioRecorder();
  DateTime? _started;

  Future<bool> start() async {
    if (!await _rec.hasPermission()) return false;
    final encoder = kIsWeb ? AudioEncoder.opus : AudioEncoder.aacLc;
    final path = kIsWeb
        ? ''
        : '${Directory.systemTemp.path}/eletrend_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _rec.start(RecordConfig(encoder: encoder, bitRate: 24000, sampleRate: 16000, numChannels: 1), path: path);
    _started = DateTime.now();
    return true;
  }

  Duration get elapsed => _started == null ? Duration.zero : DateTime.now().difference(_started!);

  /// Leállítja, és visszaadja a hangot (base64, formátum); null, ha nem sikerült.
  Future<({String audio, String mime})?> stop() async {
    final path = await _rec.stop();
    _started = null;
    if (path == null) return null;
    final Uint8List bytes;
    if (kIsWeb) {
      // Böngészőben a felvétel egy blob: címen van.
      bytes = (await http.get(Uri.parse(path))).bodyBytes;
    } else {
      final f = File(path);
      bytes = await f.readAsBytes();
      await f.delete();
    }
    if (bytes.isEmpty) return null;
    return (audio: base64Encode(bytes), mime: kIsWeb ? 'audio/webm' : 'audio/mp4');
  }

  Future<void> cancel() async {
    await _rec.cancel();
    _started = null;
  }

  Future<void> dispose() => _rec.dispose();
}
