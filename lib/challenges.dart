import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import 'models.dart';
import 'store.dart';

/// Közös kihívás barátokkal, pl. „30 nap edzés”.
class Challenge {
  const Challenge({
    required this.id,
    required this.title,
    required this.emoji,
    required this.days,
    required this.start,
    required this.ownerUid,
    required this.members,
    required this.names,
    this.kind = '',
    this.image = '',
  });

  final String id;
  final String title;
  final String emoji;
  final int days;
  final DateTime start;
  final String ownerUid;
  final List<String> members;
  final Map<String, String> names;

  /// 'goal': közös cél (a Célok között látszik), egyébként kihívás.
  final String kind;

  /// Saját kép az emoji helyett (kicsi JPEG, base64); üres, ha nincs.
  final String image;

  bool get isGoal => kind == 'goal';

  DateTime get end => addDays(start, days - 1);

  /// Hányadik napnál tart (1-től), a kezdés előtt 0, a vége után [days].
  int dayNumber([DateTime? now]) {
    final n = now ?? DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    final s = DateTime(start.year, start.month, start.day);
    final d = today.difference(s).inDays + 1;
    return d < 0 ? 0 : (d > days ? days : d);
  }

  bool isActive([DateTime? now]) {
    final d = dayNumber(now);
    final n = now ?? DateTime.now();
    return d >= 1 && !DateTime(n.year, n.month, n.day).isAfter(DateTime(end.year, end.month, end.day));
  }

  /// A kihívás napjai közé esik-e.
  bool covers(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    return !day.isBefore(DateTime(start.year, start.month, start.day)) &&
        !day.isAfter(DateTime(end.year, end.month, end.day));
  }

  factory Challenge.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return Challenge(
      id: doc.id,
      title: d['title'] as String? ?? '',
      emoji: d['emoji'] as String? ?? '🏁',
      days: (d['days'] as num?)?.toInt() ?? 30,
      start: DateTime.parse(d['start'] as String),
      ownerUid: d['ownerUid'] as String? ?? '',
      members: List<String>.from(d['members'] as List? ?? []),
      names: Map<String, String>.from(d['names'] as Map? ?? {}),
      kind: d['kind'] as String? ?? '',
      image: d['image'] as String? ?? '',
    );
  }
}

class ChallengeProgress {
  const ChallengeProgress({required this.uid, required this.name, this.done = const {}, this.cheers = 0});

  final String uid;
  final String name;
  final Set<String> done;
  final int cheers;

  factory ChallengeProgress.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return ChallengeProgress(
      uid: doc.id,
      name: d['name'] as String? ?? '?',
      done: Set<String>.from(d['done'] as List? ?? []),
      cheers: (d['cheers'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Kihívás-ötletek az induláshoz.
const challengeIdeas = [
  ('🏋️', '30 nap edzés', 30),
  ('⏰', '21 nap korán kelés', 21),
  ('🍬', '30 nap cukor nélkül', 30),
  ('🚶', '14 nap napi 10 000 lépés', 14),
  ('📵', '7 nap esti telefon nélkül', 7),
  ('📖', '30 nap olvasás', 30),
];

/// Legfeljebb ennyi napos lehet egy kihívás (a szabályok is ezt engedik).
const maxChallengeDays = 366;

/// Saját kép a kihíváshoz: középen négyzetre vágva, 192 px-esre kicsinyítve, JPEG (pár tíz KB),
/// hogy a kihívás dokumentumában elférjen és a barátoknál is gyorsan betöltsön.
String prepareChallengeIcon(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) throw const FormatException('Ezt a képet nem tudom megnyitni. Próbálj JPG-t vagy PNG-t.');
  final oriented = img.bakeOrientation(decoded);
  final side = oriented.width < oriented.height ? oriented.width : oriented.height;
  final square = img.copyCrop(
    oriented,
    x: (oriented.width - side) ~/ 2,
    y: (oriented.height - side) ~/ 2,
    width: side,
    height: side,
  );
  final small = side > 192 ? img.copyResize(square, width: 192, height: 192) : square;
  return base64Encode(img.encodeJpg(small, quality: 80));
}

/// Közös kihívások: `challenges/{id}` (tagok, nevek), `challenges/{id}/progress/{uid}` (teljesített napok, buzdítások).
class Challenges {
  Challenges({FirebaseFirestore? db}) : _dbOverride = db;

  static Challenges instance = Challenges();

  final FirebaseFirestore? _dbOverride;
  FirebaseFirestore get _db => _dbOverride ?? FirebaseFirestore.instance;

  String? _uid;
  AppStore? _store;
  Timer? _debounce;

  bool get ready => _uid != null;
  String? get uid => _uid;

  CollectionReference<Map<String, dynamic>> get _col => _db.collection('challenges');

  /// Bejelentkezéskor: a célhoz kötött kihívások maguktól követik a célt.
  void start(String uid, AppStore store) {
    _uid = uid;
    _store = store;
    store.removeListener(_onChange);
    store.addListener(_onChange);
  }

  void stop() {
    _debounce?.cancel();
    _store?.removeListener(_onChange);
    _uid = null;
    _store = null;
  }

  void _onChange() {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(seconds: 2),
      () => syncLinkedHabits().catchError((Object e) {
        debugPrint('Kihívás frissítése később: $e');
      }),
    );
  }

  Stream<List<Challenge>> watchMine() => _col
      .where('members', arrayContains: _uid)
      .snapshots()
      .map((q) => [for (final d in q.docs) Challenge.fromDoc(d)]..sort((a, b) => b.start.compareTo(a.start)));

  Future<Challenge?> get(String id) async {
    final doc = await _col.doc(id).get();
    return doc.exists ? Challenge.fromDoc(doc) : null;
  }

  /// Közös célok (a kihívások listájában nem szerepelnek).
  Stream<List<Challenge>> watchSharedGoals() => watchMine().map(
    (l) => [
      for (final c in l)
        if (c.isGoal) c,
    ],
  );

  /// Közös cél indítása egy meglévő célból: a barátok meghívást kapnak, a cél pipái maguktól átmennek.
  Future<String> shareGoal(Habit habit, Map<String, String> friends) async {
    final id = await create(
      title: habit.name.length > 60 ? habit.name.substring(0, 60) : habit.name,
      emoji: '',
      days: 366,
      start: DateTime.now(),
      friends: friends,
      kind: 'goal',
    );
    _store!.linkChallengeHabit(id, habit.id);
    await syncLinkedHabits();
    return id;
  }

  /// Csatlakozás egy barát közös céljához: saját cél lesz belőle, ugyanazzal a névvel.
  Future<void> joinSharedGoal(Challenge c) async {
    final store = _store!;
    store.addHabit(c.title);
    store.linkChallengeHabit(c.id, store.habits.last.id);
    await syncLinkedHabits();
  }

  Stream<List<ChallengeProgress>> watchProgress(String id) => _col.doc(id).collection('progress').snapshots().map((q) {
    final list = [for (final d in q.docs) ChallengeProgress.fromDoc(d)];
    return list..sort((a, b) => b.done.length.compareTo(a.done.length));
  });

  Future<String> create({
    required String title,
    required String emoji,
    required int days,
    required DateTime start,
    required Map<String, String> friends,
    String kind = '',
    String image = '',
  }) async {
    final me = _uid!;
    final name = _store!.myName;
    final ref = _col.doc();
    await ref.set({
      'title': title.trim(),
      'emoji': emoji,
      'days': days,
      'start': dayKey(start),
      'ownerUid': me,
      'members': [me, ...friends.keys],
      'names': {me: name, ...friends},
      if (kind.isNotEmpty) 'kind': kind,
      if (image.isNotEmpty) 'image': image,
      'at': FieldValue.serverTimestamp(),
    });
    await ref.collection('progress').doc(me).set({'name': name, 'done': <String>[], 'cheers': 0});
    return ref.id;
  }

  /// Mai (vagy adott napi) teljesítés be/ki.
  Future<void> checkIn(Challenge c, DateTime day, bool done) async {
    final ref = _col.doc(c.id).collection('progress').doc(_uid);
    final snap = await ref.get();
    final current = snap.exists ? ChallengeProgress.fromDoc(snap).done : <String>{};
    final key = dayKey(day);
    final next = done ? {...current, key} : ({...current}..remove(key));
    if (snap.exists) {
      await ref.update({'done': next.toList(), 'name': _store!.myName});
    } else {
      await ref.set({'name': _store!.myName, 'done': next.toList(), 'cheers': 0});
    }
  }

  /// 👏 Buzdítás egy másik tagnak.
  Future<void> cheer(String challengeId, String memberUid) =>
      _col.doc(challengeId).collection('progress').doc(memberUid).update({'cheers': FieldValue.increment(1)});

  Future<void> leave(Challenge c) async {
    final me = _uid!;
    await _col.doc(c.id).collection('progress').doc(me).delete();
    await _col.doc(c.id).update({
      'members': FieldValue.arrayRemove([me]),
      'names.$me': FieldValue.delete(),
    });
    _store?.linkChallengeHabit(c.id, null);
  }

  Future<void> delete(Challenge c) async {
    final progress = await _col.doc(c.id).collection('progress').get();
    final batch = _db.batch();
    for (final d in progress.docs) {
      batch.delete(d.reference);
    }
    batch.delete(_col.doc(c.id));
    await batch.commit();
    _store?.linkChallengeHabit(c.id, null);
  }

  /// A célhoz kötött kihívásoknál a cél teljesített napjai (a kihívás idejére) kerülnek be.
  Future<void> syncLinkedHabits() async {
    final store = _store;
    if (store == null || _uid == null) return;
    for (final link in store.challengeHabits.entries) {
      final habit = store.habits.where((h) => h.id == link.value).firstOrNull;
      if (habit == null) continue;
      final doc = await _col.doc(link.key).get();
      if (!doc.exists) continue;
      final c = Challenge.fromDoc(doc);
      final done = {
        for (final d in habit.doneDays)
          if (c.covers(DateTime.parse(d))) d,
      };
      final ref = _col.doc(c.id).collection('progress').doc(_uid);
      final snap = await ref.get();
      if (snap.exists && setEquals(ChallengeProgress.fromDoc(snap).done, done)) continue;
      snap.exists
          ? await ref.update({'done': done.toList(), 'name': store.myName})
          : await ref.set({'name': store.myName, 'done': done.toList(), 'cheers': 0});
    }
  }
}
