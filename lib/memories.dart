import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image/image.dart' as img;

import 'models.dart';

/// Kik láthatnak egy fotót: mindenki, aki látja a programot, vagy csak akik mentek.
enum PhotoAudience {
  all('Mindenki, aki látja a programot'),
  going('Csak akik ott voltak (Megyek)');

  const PhotoAudience(this.label);

  final String label;
}

/// Egy fotó egy közös program emlékei között (a listában csak a kis előnézet van benne).
class MemoryPhoto {
  const MemoryPhoto({
    required this.id,
    required this.uid,
    required this.name,
    required this.thumb,
    this.at,
    this.audience = PhotoAudience.all,
    this.allowDownload = true,
  });

  final String id;
  final String uid;
  final String name;

  /// Kis előnézet (JPEG, base64).
  final String thumb;
  final DateTime? at;
  final PhotoAudience audience;

  /// Letöltheti-e más is (a feltöltő dönti el).
  final bool allowDownload;

  Uint8List get thumbBytes => base64Decode(thumb);

  factory MemoryPhoto.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return MemoryPhoto(
      id: doc.id,
      uid: d['uid'] as String? ?? '',
      name: d['name'] as String? ?? '?',
      thumb: d['thumb'] as String? ?? '',
      at: (d['at'] as Timestamp?)?.toDate(),
      audience: PhotoAudience.values.asNameMap()[d['audience']] ?? PhotoAudience.all,
      allowDownload: d['allowDownload'] as bool? ?? true,
    );
  }
}

class MemoryException implements Exception {
  const MemoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Közös emlékek: fotók a közös programokhoz.
///
/// `events/{id}/photos/{fotó}` (feltöltő, előnézet, kik láthatják, letölthető-e) és
/// `events/{id}/photoData/{fotó}` (a teljes kép). Külön vannak, hogy a lista csak a kis
/// előnézeteket töltse le. A képek a Firestore-ban vannak, összenyomva (a Firebase Storage
/// fizetős csomagot kérne), ezért egy kép legfeljebb kb. 700 KB lehet.
class Memories {
  Memories({FirebaseFirestore? db, FirebaseAuth? auth})
      : _dbOverride = db,
        _authOverride = auth;

  static Memories instance = Memories();

  /// Egy feltöltött kép legnagyobb mérete (a dokumentum 1 MB-os korlátja miatt, base64 előtt).
  static const maxBytes = 650 * 1024;

  final FirebaseFirestore? _dbOverride;
  final FirebaseAuth? _authOverride;
  FirebaseFirestore get _db => _dbOverride ?? FirebaseFirestore.instance;
  String? get uid => (_authOverride ?? FirebaseAuth.instance).currentUser?.uid;

  CollectionReference<Map<String, dynamic>> _photos(String eventId) =>
      _db.collection('events').doc(eventId).collection('photos');
  CollectionReference<Map<String, dynamic>> _data(String eventId) =>
      _db.collection('events').doc(eventId).collection('photoData');

  /// Kép előkészítése: legfeljebb 1600 px, JPEG; plusz egy 320 px-es előnézet.
  static ({Uint8List full, Uint8List thumb}) prepare(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) throw const MemoryException('Ezt a képet nem tudom megnyitni. Próbálj JPG-t vagy PNG-t.');
    final oriented = img.bakeOrientation(decoded);
    final big = oriented.width > 1600 || oriented.height > 1600
        ? img.copyResize(oriented, width: oriented.width >= oriented.height ? 1600 : null, height: oriented.height > oriented.width ? 1600 : null)
        : oriented;
    var quality = 78;
    var full = Uint8List.fromList(img.encodeJpg(big, quality: quality));
    // Ha még mindig túl nagy, kisebb minőséggel és mérettel próbáljuk.
    while (full.length > maxBytes && quality > 40) {
      quality -= 12;
      final smaller = img.copyResize(big, width: (big.width * 0.8).round());
      full = Uint8List.fromList(img.encodeJpg(smaller, quality: quality));
    }
    if (full.length > maxBytes) throw const MemoryException('Ez a kép túl nagy.');
    final small = img.copyResize(oriented, width: oriented.width >= oriented.height ? 320 : null, height: oriented.height > oriented.width ? 320 : null);
    return (full: full, thumb: Uint8List.fromList(img.encodeJpg(small, quality: 60)));
  }

  /// A program fotói, amiket láthatok: a mindenkinek szólók, a sajátjaim, és ha ott voltam,
  /// a csak résztvevőknek szólók. (Külön lekérdezések, mert a szabályok így tudják ellenőrizni.)
  Stream<List<MemoryPhoto>> watch(String eventId, {required bool going}) {
    final me = uid;
    final queries = [
      _photos(eventId).where('audience', isEqualTo: PhotoAudience.all.name),
      if (me != null) _photos(eventId).where('uid', isEqualTo: me),
      if (going) _photos(eventId).where('audience', isEqualTo: PhotoAudience.going.name),
    ];
    final latest = List<List<MemoryPhoto>?>.filled(queries.length, null);
    late final StreamController<List<MemoryPhoto>> controller;
    final subs = <StreamSubscription<void>>[];
    void emit() {
      if (latest.any((l) => l == null)) return;
      final byId = {for (final list in latest) for (final p in list!) p.id: p};
      final list = byId.values.toList()..sort((a, b) => (a.at ?? DateTime(3000)).compareTo(b.at ?? DateTime(3000)));
      controller.add(list);
    }

    controller = StreamController<List<MemoryPhoto>>(
      onListen: () {
        for (var i = 0; i < queries.length; i++) {
          subs.add(queries[i].snapshots().listen((q) {
            latest[i] = [for (final d in q.docs) MemoryPhoto.fromDoc(d)];
            emit();
          }, onError: controller.addError));
        }
      },
      onCancel: () async {
        for (final s in subs) {
          await s.cancel();
        }
      },
    );
    return controller.stream;
  }

  /// Fotó feltöltése (a kép és az előnézet már előkészítve, lásd [prepare]).
  Future<void> upload(
    String eventId, {
    required String name,
    required Uint8List full,
    required Uint8List thumb,
    PhotoAudience audience = PhotoAudience.all,
    bool allowDownload = true,
  }) async {
    final me = uid ?? (throw const MemoryException('Előbb jelentkezz be.'));
    final id = newId();
    // Előbb a teljes kép, hogy a listában ne jelenjen meg olyan, aminek nincs képe.
    await _data(eventId).doc(id).set({'uid': me, 'audience': audience.name, 'data': base64Encode(full)});
    await _photos(eventId).doc(id).set({
      'uid': me,
      'name': name,
      'thumb': base64Encode(thumb),
      'audience': audience.name,
      'allowDownload': allowDownload,
      'at': FieldValue.serverTimestamp(),
    });
    // Jegyzet a saját adatok közé, hogy fióktörléskor megtaláljuk (index nélkül).
    await _mine(me).doc(id).set({'eventId': eventId});
  }

  CollectionReference<Map<String, dynamic>> _mine(String userUid) =>
      _db.collection('users').doc(userUid).collection('myPhotos');

  /// A teljes kép (null, ha már nincs meg).
  Future<Uint8List?> full(String eventId, MemoryPhoto photo) async {
    final d = await _data(eventId).doc(photo.id).get();
    final data = d.data()?['data'] as String?;
    return data == null ? null : base64Decode(data);
  }

  /// Ki láthatja és letöltheti (csak a feltöltő módosíthatja).
  Future<void> update(String eventId, MemoryPhoto photo, {required PhotoAudience audience, required bool allowDownload}) async {
    await _photos(eventId).doc(photo.id).update({'audience': audience.name, 'allowDownload': allowDownload});
    await _data(eventId).doc(photo.id).update({'audience': audience.name});
  }

  Future<void> delete(String eventId, String photoId) async {
    await _photos(eventId).doc(photoId).delete();
    await _data(eventId).doc(photoId).delete();
    final me = uid;
    if (me != null) await _mine(me).doc(photoId).delete();
  }

  /// Fióktörléskor: az összes saját fotó minden programból. Ha egy program már nincs meg
  /// (a szervező törölte), azt átugorjuk.
  Future<void> deleteAllOf(String userUid) async {
    final mine = await _mine(userUid).get();
    for (final d in mine.docs) {
      final eventId = d.data()['eventId'] as String?;
      if (eventId != null) {
        try {
          await _photos(eventId).doc(d.id).delete();
          await _data(eventId).doc(d.id).delete();
        } on FirebaseException catch (e) {
          if (e.code != 'permission-denied' && e.code != 'not-found') rethrow;
        }
      }
      await d.reference.delete();
    }
  }
}

/// Egy felbukkanó emlék: melyik közös program, és mennyi ideje volt.
class MemoryPick {
  const MemoryPick({required this.event, required this.occurredAt, required this.ago, this.anniversary = false});

  final Event event;
  final DateTime occurredAt;

  /// Pl. „1 éve”, „3 hónapja”, „2 hete”.
  final String ago;

  /// Kerek évforduló (ma pontosan 1 hete / 1, 3, 6 hónapja / N éve volt).
  final bool anniversary;
}

/// Mennyi ideje volt, magyarul.
String agoLabel(DateTime then, DateTime now) {
  final days = startOfDay(now).difference(startOfDay(then)).inDays;
  if (days < 1) return 'ma';
  if (days < 7) return '$days napja';
  if (days < 30) return '${days ~/ 7} hete';
  final months = (now.year - then.year) * 12 + now.month - then.month - (now.day < then.day ? 1 : 0);
  if (months < 12) return '${months < 1 ? 1 : months} hónapja';
  return '${months ~/ 12} éve';
}

/// A közös programjaim közül egy emlék mára.
///
/// Elsőbbsége van a kerek évfordulóknak (ma 1 hete, 1/3/6 hónapja vagy N éve volt). Ha nincs
/// ilyen, a legalább két hete volt programok közül háromnaponta másik jön elő.
MemoryPick? pickMemory(List<Event> events, DateTime now) {
  final today = startOfDay(now);
  final past = [
    for (final e in events)
      if (e.shareId != null && e.repeat == Repeat.none && !e.start.add(e.duration).isAfter(now)) e,
  ]..sort((a, b) => a.start.compareTo(b.start));
  if (past.isEmpty) return null;

  for (final e in past.reversed) {
    final d = startOfDay(e.start);
    final days = today.difference(d).inDays;
    final sameDayOfMonth = d.day == today.day;
    final months = (today.year - d.year) * 12 + today.month - d.month;
    final anniversary = days == 7 || (sameDayOfMonth && (months == 1 || months == 3 || months == 6 || (months > 0 && months % 12 == 0)));
    if (anniversary) return MemoryPick(event: e, occurredAt: e.start, ago: agoLabel(e.start, now), anniversary: true);
  }

  final older = past.where((e) => today.difference(startOfDay(e.start)).inDays >= 14).toList();
  if (older.isEmpty) return null;
  final slot = today.difference(DateTime(2020)).inDays ~/ 3;
  final e = older[slot % older.length];
  return MemoryPick(event: e, occurredAt: e.start, ago: agoLabel(e.start, now));
}
