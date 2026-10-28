import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:record/record.dart';

import 'widgets/effects.dart';

/// Egy „bump”: rövid üzenet egy barátnak matricával, képpel/GIF-fel, hangüzenettel és effekttel,
/// opcionálisan egy programhoz kötve.
class Bump {
  const Bump({
    this.id = '',
    this.fromUid = '',
    this.fromName = '',
    this.text = '',
    this.effect = BumpEffect.none,
    this.sticker,
    this.image,
    this.audio,
    this.audioMime,
    this.eventId,
    this.eventTitle,
    this.at,
    this.seen = false,
  });

  final String id;
  final String fromUid;
  final String fromName;
  final String text;
  final BumpEffect effect;

  /// Nagy emoji matrica.
  final String? sticker;

  /// Kép vagy GIF, base64.
  final String? image;

  /// Hangüzenet, base64 (és a formátuma, pl. audio/mp4 vagy audio/webm).
  final String? audio;
  final String? audioMime;

  /// A megosztott program azonosítója, ha programhoz kötött.
  final String? eventId;
  final String? eventTitle;
  final DateTime? at;
  final bool seen;

  Uint8List? get imageBytes => image == null ? null : base64Decode(image!);

  /// Az értesítés szövege, pl. „👋 Gabi bumpolt: Ne felejtsd a pizzát!”
  String get headline => '${sticker ?? '👋'} $fromName bumpolt${text.isEmpty ? '!' : ': $text'}';

  EffectShow get show => EffectShow(effect: effect, image: imageBytes, sticker: image == null ? sticker : null, caption: headline);

  Map<String, dynamic> toJson() => {
        'fromUid': fromUid,
        'fromName': fromName,
        'text': text,
        'effect': effect.name,
        'sticker': sticker,
        'image': image,
        'audio': audio,
        'audioMime': audioMime,
        'eventId': eventId,
        'eventTitle': eventTitle,
        'seen': false,
        'at': FieldValue.serverTimestamp(),
      };

  factory Bump.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return Bump(
      id: doc.id,
      fromUid: d['fromUid'] as String? ?? '',
      fromName: d['fromName'] as String? ?? '?',
      text: d['text'] as String? ?? '',
      effect: BumpEffect.values.asNameMap()[d['effect']] ?? BumpEffect.none,
      sticker: d['sticker'] as String?,
      image: d['image'] as String?,
      audio: d['audio'] as String?,
      audioMime: d['audioMime'] as String?,
      eventId: d['eventId'] as String?,
      eventTitle: d['eventTitle'] as String?,
      at: (d['at'] as Timestamp?)?.toDate(),
      seen: d['seen'] as bool? ?? false,
    );
  }
}

class BumpException implements Exception {
  const BumpException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Bumpok küldése és fogadása: `bumps/{címzett}/items/{id}`; a fogadás beállításai
/// (kikapcsolás, némított barátok) a `bumpSettings/{uid}` dokumentumban vannak.
class Bumps {
  Bumps({FirebaseFirestore? db}) : _dbOverride = db;

  static Bumps instance = Bumps();

  /// Egy bump legfeljebb ekkora kép/GIF lehet (base64 előtt), hogy beférjen egy dokumentumba.
  static const maxImageBytes = 450 * 1024;

  /// A hangüzenet hossza legfeljebb.
  static const maxVoice = Duration(seconds: 20);

  final FirebaseFirestore? _dbOverride;
  FirebaseFirestore get _db => _dbOverride ?? FirebaseFirestore.instance;

  String? _uid;
  StreamSubscription<void>? _sub;
  final _handled = <String>{};

  bool get ready => _uid != null;

  String? get myUid => _uid;

  CollectionReference<Map<String, dynamic>> _inbox(String uid) => _db.collection('bumps').doc(uid).collection('items');

  /// Figyeli az új (még nem látott) bumpokat; mindegyikre egyszer meghívja az [onBump]-ot.
  void start(String uid, void Function(Bump bump) onBump) {
    stop();
    _uid = uid;
    _onBump = onBump;
    _sub = _inbox(uid).where('seen', isEqualTo: false).snapshots().listen((q) {
      for (final d in q.docs) {
        if (_handled.add(d.id)) onBump(Bump.fromDoc(d));
      }
    }, onError: (Object e) => debugPrint('Bumpok később: $e'));
  }

  void Function(Bump bump)? _onBump;

  /// Egy bumpot még nem tudtunk megmutatni (pl. háttérben volt az app): később újra jöhet.
  void notShown(String id) => _handled.remove(id);

  /// Visszatéréskor: a közben jött, még nem látott bumpok.
  Future<void> checkNow() async {
    final uid = _uid;
    final onBump = _onBump;
    if (uid == null || onBump == null) return;
    final q = await _inbox(uid).where('seen', isEqualTo: false).get();
    for (final d in q.docs) {
      if (_handled.add(d.id)) onBump(Bump.fromDoc(d));
    }
  }

  Future<Bump?> fetch(String id) async {
    final uid = _uid;
    if (uid == null) return null;
    final d = await _inbox(uid).doc(id).get();
    return d.exists ? Bump.fromDoc(d) : null;
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
    _uid = null;
  }

  Future<void> send(String toUid, Bump bump) async {
    try {
      await _inbox(toUid).add(bump.toJson());
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw const BumpException('Most nem fogad bumpot (kikapcsolta, vagy nem vagytok barátok).');
      }
      rethrow;
    }
  }

  Future<void> markSeen(String id) => _inbox(_uid!).doc(id).update({'seen': true});

  Future<void> delete(String id) => _inbox(_uid!).doc(id).delete();

  /// A kapott bumpok (a legújabb 50), visszajátszáshoz.
  Stream<List<Bump>> watchAll() => _inbox(_uid!)
      .orderBy('at', descending: true)
      .limit(50)
      .snapshots()
      .map((q) => [for (final d in q.docs) Bump.fromDoc(d)]);

  // Beállítások

  DocumentReference<Map<String, dynamic>> get _settings => _db.collection('bumpSettings').doc(_uid);

  Future<({bool off, Set<String> muted})> settings() async {
    final d = (await _settings.get()).data() ?? {};
    return (off: d['off'] as bool? ?? false, muted: Set<String>.from(d['muted'] as List? ?? []));
  }

  Future<void> setOff(bool off) => _settings.set({'off': off}, SetOptions(merge: true));

  Future<void> setMuted(String friendUid, bool muted) => _settings.set({
        'muted': muted ? FieldValue.arrayUnion([friendUid]) : FieldValue.arrayRemove([friendUid]),
      }, SetOptions(merge: true));

  // Kép és hang előkészítése

  /// Kép a bumphoz: a GIF változatlanul (ha nem túl nagy, hogy mozogjon), a fotó kicsinyítve JPEG-be.
  static String prepareImage(Uint8List bytes, {String? name}) {
    final isGif = (name ?? '').toLowerCase().endsWith('.gif') || (bytes.length > 3 && bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46);
    if (isGif) {
      if (bytes.length > maxImageBytes) throw const BumpException('Ez a GIF túl nagy (legfeljebb kb. 450 KB lehet).');
      return base64Encode(bytes);
    }
    final decoded = img.decodeImage(bytes);
    if (decoded == null) throw const BumpException('Ezt a képet nem tudom megnyitni. Próbálj JPG-t, PNG-t vagy GIF-et.');
    final resized = decoded.width > 700 ? img.copyResize(decoded, width: 700) : decoded;
    return base64Encode(img.encodeJpg(resized, quality: 72));
  }
}

/// Hangüzenet felvétele: kis bitrátával, hogy a bumpba beférjen.
class VoiceRecorder {
  final _rec = AudioRecorder();
  DateTime? _started;

  Future<bool> start() async {
    if (!await _rec.hasPermission()) return false;
    final encoder = kIsWeb ? AudioEncoder.opus : AudioEncoder.aacLc;
    final path = kIsWeb ? '' : '${Directory.systemTemp.path}/eletrend_bump_${DateTime.now().millisecondsSinceEpoch}.m4a';
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
