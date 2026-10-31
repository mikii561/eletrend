import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'models.dart';
import 'square_image.dart';
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
String prepareChallengeIcon(Uint8List bytes) => squareJpegBase64(bytes, side: 192);

/// Mi történt egy kihívásban, amiről értesítünk.
enum ChallengeActivityKind {
  /// Valaki ma elvégezte, én még nem.
  done,

  /// Valaki megbuzdított.
  cheered,
}

class ChallengeActivity {
  const ChallengeActivity({required this.kind, required this.challenge, required this.name});

  final ChallengeActivityKind kind;
  final Challenge challenge;

  /// Aki elvégezte (a buzdításnál nem tudjuk, ki volt).
  final String name;

  String get title => kind == ChallengeActivityKind.done ? '💪 $name már megcsinálta!' : '👏 Megbuzdítottak!';

  String get body => kind == ChallengeActivityKind.done
      ? '${challenge.title}: most te jössz! Ha te is kész vagy, buzdítsd a többieket.'
      : '${challenge.title}: valaki szerint menni fog. Csináld meg ma!';
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
    _activitySub?.cancel();
    _activitySub = null;
    for (final s in _progressSubs.values) {
      s.cancel();
    }
    _progressSubs.clear();
    _watched.clear();
    _seenDone.clear();
    _seenCheers.clear();
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

  // Értesítés a többiek teljesítéséről és a buzdításokról

  StreamSubscription<List<Challenge>>? _activitySub;
  final _progressSubs = <String, StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>{};
  final _watched = <String, Challenge>{};
  final _seenDone = <String, Set<String>>{};
  final _seenCheers = <String, int>{};

  /// Figyeli a kihívásaimat: ha valaki ma elvégezte, és én még nem, vagy megbuzdítottak, szól az [onActivity].
  /// Az első betöltés csak az induló állapotot jegyzi meg (a régi dolgokról nem értesít).
  void listenActivity(void Function(ChallengeActivity activity) onActivity) {
    _activitySub?.cancel();
    _activitySub = watchMine().listen((list) {
      final active = {
        for (final c in list)
          if (!c.isGoal && c.isActive()) c.id: c,
      };
      for (final gone in _progressSubs.keys.where((id) => !active.containsKey(id)).toList()) {
        _progressSubs.remove(gone)?.cancel();
        _watched.remove(gone);
      }
      _watched.addAll(active);
      for (final id in active.keys) {
        _progressSubs.putIfAbsent(
          id,
          () => _col.doc(id).collection('progress').snapshots().listen((q) => _onProgress(id, q, onActivity)),
        );
      }
    }, onError: (Object e) => debugPrint('Kihívás-figyelés később: $e'));
  }

  void _onProgress(String id, QuerySnapshot<Map<String, dynamic>> q, void Function(ChallengeActivity) onActivity) {
    final challenge = _watched[id];
    final me = _uid;
    if (challenge == null || me == null) return;
    final today = dayKey(DateTime.now());
    final progress = [for (final d in q.docs) ChallengeProgress.fromDoc(d)];
    final iDone = progress.any((p) => p.uid == me && p.done.contains(today));
    for (final p in progress) {
      final key = '$id/${p.uid}';
      final firstLoad = !_seenDone.containsKey(key);
      final before = _seenDone[key] ?? const <String>{};
      final cheersBefore = _seenCheers[key] ?? 0;
      _seenDone[key] = p.done;
      _seenCheers[key] = p.cheers;
      if (firstLoad) continue;
      if (p.uid == me) {
        if (p.cheers > cheersBefore) {
          onActivity(ChallengeActivity(kind: ChallengeActivityKind.cheered, challenge: challenge, name: ''));
        }
      } else if (p.done.contains(today) && !before.contains(today) && !iDone) {
        onActivity(ChallengeActivity(kind: ChallengeActivityKind.done, challenge: challenge, name: p.name));
      }
    }
  }

  /// Megbuzdítja mindazokat, akik ma még nem csinálták meg. Hányan voltak?
  Future<int> cheerAll(Challenge c) async {
    final me = _uid!;
    final today = dayKey(DateTime.now());
    final progress = await _col.doc(c.id).collection('progress').get();
    final waiting =
        {
          for (final m in c.members)
            if (m != me) m,
        }..removeAll([
          for (final d in progress.docs)
            if ((d.data()['done'] as List? ?? []).contains(today)) d.id,
        ]);
    for (final uid in waiting) {
      await cheer(c.id, uid);
    }
    return waiting.length;
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
