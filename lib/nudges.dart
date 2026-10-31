import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'models.dart';

/// Kész bökés-szövegek (barátságos, nem tolakodó).
const nudgeTemplates = [
  ('👋', 'Találkozzunk végre a héten!'),
  ('💪', 'Tartozol nekem egy edzéssel!'),
  ('📅', 'Ne felejtsd a holnapi programunkat!'),
  ('🎉', 'Szervezzünk valamit!'),
  ('☕', 'Egy kávé valamikor?'),
];

/// Egy bökés: rövid, barátságos emlékeztető egy barátnak, opcionálisan egy programhoz kötve.
class Nudge {
  const Nudge({
    this.id = '',
    this.fromUid = '',
    this.fromName = '',
    required this.text,
    this.emoji = '👋',
    this.eventId,
    this.eventTitle,
    this.at,
    this.seen = false,
  });

  final String id;
  final String fromUid;
  final String fromName;
  final String text;
  final String emoji;

  /// A közös program azonosítója, ha programhoz kötött.
  final String? eventId;
  final String? eventTitle;
  final DateTime? at;
  final bool seen;

  /// Az értesítés szövege, pl. „👋 Gabi: Szervezzünk valamit!”
  String get headline => '$emoji $fromName: $text';

  factory Nudge.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return Nudge(
      id: doc.id,
      fromUid: d['fromUid'] as String? ?? '',
      fromName: d['fromName'] as String? ?? '?',
      text: d['text'] as String? ?? '',
      emoji: d['emoji'] as String? ?? '👋',
      eventId: d['eventId'] as String?,
      eventTitle: d['eventTitle'] as String?,
      at: (d['at'] as Timestamp?)?.toDate(),
      seen: d['seen'] as bool? ?? false,
    );
  }
}

class NudgeException implements Exception {
  const NudgeException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Bökések: `nudges/{címzett}/items/{küldő}_{nap}_{0–2}`.
///
/// Az azonosító miatt egy barát naponta legfeljebb [dailyLimit] bökést küldhet ugyanannak az
/// embernek; ezt a szabályok is kikényszerítik (a meglévő dokumentum nem írható felül).
/// A fogadás beállításai (kikapcsolás, némított barátok): `nudgeSettings/{uid}`.
class Nudges {
  Nudges({FirebaseFirestore? db}) : _dbOverride = db;

  static Nudges instance = Nudges();

  static const dailyLimit = 3;

  final FirebaseFirestore? _dbOverride;
  FirebaseFirestore get _db => _dbOverride ?? FirebaseFirestore.instance;

  String? _uid;
  StreamSubscription<void>? _sub;
  void Function(Nudge nudge)? _onNudge;
  final _handled = <String>{};

  bool get ready => _uid != null;

  CollectionReference<Map<String, dynamic>> _inbox(String uid) => _db.collection('nudges').doc(uid).collection('items');

  /// Figyeli az új (még nem látott) bökéseket; mindegyikre egyszer meghívja az [onNudge]-ot.
  void start(String uid, void Function(Nudge nudge) onNudge) {
    stop();
    _uid = uid;
    _onNudge = onNudge;
    _sub = _inbox(uid).where('seen', isEqualTo: false).snapshots().listen((q) {
      for (final d in q.docs) {
        if (_handled.add(d.id)) onNudge(Nudge.fromDoc(d));
      }
    }, onError: (Object e) => debugPrint('Bökések később: $e'));
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
    _uid = null;
  }

  /// Egy bökést még nem tudtunk megmutatni (pl. háttérben volt az app): később újra jöhet.
  void notShown(String id) => _handled.remove(id);

  /// Visszatéréskor: a közben jött, még nem látott bökések.
  Future<void> checkNow() async {
    final uid = _uid, onNudge = _onNudge;
    if (uid == null || onNudge == null) return;
    final q = await _inbox(uid).where('seen', isEqualTo: false).get();
    for (final d in q.docs) {
      if (_handled.add(d.id)) onNudge(Nudge.fromDoc(d));
    }
  }

  Future<Nudge?> fetch(String id) async {
    final uid = _uid;
    if (uid == null) return null;
    final d = await _inbox(uid).doc(id).get();
    return d.exists ? Nudge.fromDoc(d) : null;
  }

  /// Bökés küldése. A mai keretből a következő szabad sorszámot használja.
  Future<void> send(
    String toUid, {
    required String fromName,
    required String text,
    String emoji = '👋',
    String? eventId,
    String? eventTitle,
    DateTime? now,
  }) async {
    final me = _uid ?? (throw const NudgeException('Előbb jelentkezz be.'));
    final clean = text.trim();
    if (clean.isEmpty) throw const NudgeException('Írj valamit a bökésbe.');
    final day = dayKey(now ?? DateTime.now()).replaceAll('-', '');
    for (var n = 0; n < dailyLimit; n++) {
      final ref = _inbox(toUid).doc('${me}_${day}_$n');
      try {
        // Csak létrehozni szabad: ha már van ilyen sorszám, a szabály elutasítja, és jön a következő.
        await ref.set({
          'fromUid': me,
          'fromName': fromName,
          'text': clean.length > 120 ? clean.substring(0, 120) : clean,
          'emoji': emoji,
          'eventId': eventId,
          'eventTitle': eventTitle,
          'seen': false,
          'at': FieldValue.serverTimestamp(),
        });
        return;
      } on FirebaseException catch (e) {
        if (e.code != 'permission-denied') rethrow;
      }
    }
    throw const NudgeException('Ma már elég bökést küldtél neki (vagy nem fogad bökést). Próbáld holnap!');
  }

  Future<void> markSeen(String id) => _inbox(_uid!).doc(id).update({'seen': true});

  Future<void> delete(String id) => _inbox(_uid!).doc(id).delete();

  /// A kapott bökések (a legújabb 50).
  Stream<List<Nudge>> watchAll() =>
      _inbox(_uid!)
          .orderBy('at', descending: true)
          .limit(50)
          .snapshots()
          .map((q) => [for (final d in q.docs) Nudge.fromDoc(d)]);

  // Beállítások

  DocumentReference<Map<String, dynamic>> get _settings => _db.collection('nudgeSettings').doc(_uid);

  Future<({bool off, Set<String> muted})> settings() async {
    final d = (await _settings.get()).data() ?? {};
    return (off: d['off'] as bool? ?? false, muted: Set<String>.from(d['muted'] as List? ?? []));
  }

  Future<void> setOff(bool off) => _settings.set({'off': off}, SetOptions(merge: true));

  Future<void> setMuted(String friendUid, bool muted) => _settings.set({
    'muted': muted ? FieldValue.arrayUnion([friendUid]) : FieldValue.arrayRemove([friendUid]),
  }, SetOptions(merge: true));
}
