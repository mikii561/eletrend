import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'availability.dart';
import 'store.dart';

/// Egy barát elérhetősége, ahogy ő megosztotta (csak szabad/foglalt, részletek nélkül).
class FriendAvailability {
  const FriendAvailability({
    this.manual,
    this.manualUntil,
    this.busy = const [],
    this.windows = const [],
    this.utcOffsetMin = 60,
  });

  final AvailabilityStatus? manual;
  final DateTime? manualUntil;
  final List<TimeSpan> busy;
  final List<FreeWindow> windows;
  final int utcOffsetMin;

  factory FriendAvailability.fromJson(Map<String, dynamic> d) => FriendAvailability(
    manual: AvailabilityStatus.values.asNameMap()[d['manual']],
    manualUntil: DateTime.tryParse(d['manualUntil'] as String? ?? ''),
    busy: [
      for (final b in d['busy'] as List? ?? [])
        TimeSpan(DateTime.parse((b as Map)['s'] as String), DateTime.parse(b['e'] as String)),
    ],
    windows: [for (final w in d['windows'] as List? ?? []) FreeWindow.fromJson(Map<String, dynamic>.from(w as Map))],
    utcOffsetMin: (d['offset'] as num?)?.toInt() ?? 60,
  );

  /// Az állapota [now]-kor: a kézi, ha még érvényes; különben foglalt, ha épp tart valamije.
  AvailabilityStatus statusAt(DateTime now) {
    final m = manual;
    if (m != null && (manualUntil == null || now.isBefore(manualUntil!))) return m;
    final t = now.toUtc();
    final busyNow = busy.any((b) => !t.isBefore(b.start) && t.isBefore(b.end));
    return busyNow ? AvailabilityStatus.busy : AvailabilityStatus.available;
  }

  /// Mikor lesz legközelebb szabad (ha most foglalt).
  DateTime? freeFrom(DateTime now) {
    final t = now.toUtc();
    for (final b in mergeIntervals(busy)) {
      if (!t.isBefore(b.start) && t.isBefore(b.end)) return b.end.toLocal();
    }
    return null;
  }

  Participant toParticipant(String uid, String name) =>
      Participant(uid: uid, name: name, known: true, busy: busy, windows: windows, utcOffsetMin: utcOffsetMin);
}

/// Az elérhetőség megosztása: `availability/{uid}`.
///
/// Csak a foglalt időszakok kezdete és vége kerül fel (a bejegyzések címe, helye soha), és csak
/// azok olvashatják, akik a `viewers` listában vannak (ezt a szabályok ellenőrzik).
class AvailabilityService {
  AvailabilityService({FirebaseFirestore? db}) : _dbOverride = db;

  static AvailabilityService instance = AvailabilityService();

  final FirebaseFirestore? _dbOverride;
  FirebaseFirestore get _db => _dbOverride ?? FirebaseFirestore.instance;

  String? _uid;
  AppStore? _store;
  Timer? _debounce;
  StreamSubscription<void>? _friendsSub;
  List<String> _friendUids = [];
  String? _lastPublished;

  DocumentReference<Map<String, dynamic>> _doc(String uid) => _db.collection('availability').doc(uid);

  void start(String uid, AppStore store) {
    stop();
    _uid = uid;
    _store = store;
    store.addListener(_onChange);
    _friendsSub = _db.collection('friendships').doc(uid).collection('list').snapshots().listen((q) {
      _friendUids = [for (final d in q.docs) d.id];
      _onChange();
    }, onError: (Object e) => debugPrint('Barátlista később: $e'));
  }

  void stop() {
    _debounce?.cancel();
    _friendsSub?.cancel();
    _friendsSub = null;
    _store?.removeListener(_onChange);
    _store = null;
    _uid = null;
    _lastPublished = null;
  }

  void _onChange() {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(seconds: 2),
      () => publish().catchError((Object e) {
        debugPrint('Elérhetőség feltöltése később: $e');
      }),
    );
  }

  /// Kik láthatják: minden barát, vagy a kiválasztott csoportok tagjai (akik még barátok).
  @visibleForTesting
  static List<String> viewersFor(AppStore store, List<String> friendUids) => switch (store.shareAvailability) {
    AvailabilityShare.nobody => const [],
    AvailabilityShare.friends => [...friendUids]..sort(),
    AvailabilityShare.groups => {
      for (final g in store.groups)
        if (store.shareGroups.contains(g.id))
          for (final m in g.members)
            if (friendUids.contains(m)) m,
    }.toList()..sort(),
  };

  /// A megosztott adat; null, ha senkivel nem osztom meg.
  @visibleForTesting
  static Map<String, dynamic>? payload(AppStore store, List<String> friendUids, {DateTime? now}) {
    final viewers = viewersFor(store, friendUids);
    if (store.shareAvailability == AvailabilityShare.nobody) return null;
    final t = now ?? DateTime.now();
    final from = DateTime(t.year, t.month, t.day);
    final blocks = busyBlocks(store.busyIntervals(from, from.add(const Duration(days: 28))), from: from);
    return {
      'manual': store.statusIsManual ? store.manualStatus!.name : null,
      'manualUntil': store.statusIsManual ? store.manualStatusUntil?.toUtc().toIso8601String() : null,
      'busy': [
        for (final b in blocks) {'s': b.start.toIso8601String(), 'e': b.end.toIso8601String()},
      ],
      'windows': [for (final w in store.freeWindows) w.toJson()],
      'offset': localOffsetMin(t),
      'viewers': viewers,
    };
  }

  /// Feltölti (vagy, ha kikapcsoltad a megosztást, törli) az elérhetőségemet.
  Future<void> publish() async {
    final uid = _uid, store = _store;
    if (uid == null || store == null) return;
    final data = payload(store, _friendUids);
    final key = data?.toString() ?? 'off';
    if (key == _lastPublished) return;
    if (data == null) {
      await _doc(uid).delete();
    } else {
      await _doc(uid).set({...data, 'updatedAt': FieldValue.serverTimestamp()});
    }
    _lastPublished = key;
  }

  /// Egy barát elérhetősége; null, ha nem osztja meg velem.
  Future<FriendAvailability?> fetch(String friendUid) async {
    try {
      final d = await _doc(friendUid).get();
      return d.exists ? FriendAvailability.fromJson(d.data()!) : null;
    } on FirebaseException catch (e) {
      // Ha nem vagyok a látók között, a szabályok elutasítják: ez annyit jelent, hogy nem osztja meg.
      if (e.code == 'permission-denied') return null;
      rethrow;
    }
  }

  /// Több barát egyszerre (amelyiknél hiba van, azt „nem ismert”-nek vesszük).
  Future<Map<String, FriendAvailability?>> fetchAll(Iterable<String> uids) async {
    final entries = await Future.wait(
      uids.map((u) async {
        try {
          return MapEntry(u, await fetch(u));
        } catch (e) {
          debugPrint('Elérhetőség ($u) nem jött le: $e');
          return MapEntry<String, FriendAvailability?>(u, null);
        }
      }),
    );
    return Map.fromEntries(entries);
  }
}
