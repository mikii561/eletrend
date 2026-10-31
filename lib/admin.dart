import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import 'store.dart';

/// Az app verziója (a pubspec.yaml-lel együtt kell léptetni); a hibajelentésekben látszik.
const appVersion = '1.0.0';

String get platformName => kIsWeb ? 'web' : defaultTargetPlatform.name;

/// Egy felhasználó adatlapja az adminnak: ki ő, mikor volt aktív, mennyi adata van.
/// A bejegyzések, feladatok tartalmát szándékosan nem tartalmazza, csak darabszámokat.
class UserProfile {
  const UserProfile({
    required this.uid,
    required this.name,
    required this.email,
    this.createdAt,
    this.lastSeen,
    this.platform = '',
    this.version = '',
    this.counts = const {},
    this.banned = false,
  });

  final String uid;
  final String name;
  final String email;
  final DateTime? createdAt;
  final DateTime? lastSeen;
  final String platform;
  final String version;

  /// Hány bejegyzése, feladata, célja van.
  final Map<String, int> counts;
  final bool banned;

  factory UserProfile.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc, {bool banned = false}) {
    final d = doc.data()!;
    return UserProfile(
      uid: doc.id,
      name: d['name'] as String? ?? '',
      email: d['email'] as String? ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      lastSeen: (d['lastSeen'] as Timestamp?)?.toDate(),
      platform: d['platform'] as String? ?? '',
      version: d['version'] as String? ?? '',
      counts: {for (final e in (d['counts'] as Map? ?? {}).entries) e.key as String: (e.value as num).toInt()},
      banned: banned,
    );
  }
}

class ErrorReport {
  const ErrorReport({
    required this.id,
    required this.message,
    this.stack = '',
    this.uid,
    this.platform = '',
    this.version = '',
    this.at,
  });

  final String id;
  final String message;
  final String stack;
  final String? uid;
  final String platform;
  final String version;
  final DateTime? at;

  factory ErrorReport.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return ErrorReport(
      id: doc.id,
      message: d['message'] as String? ?? '',
      stack: d['stack'] as String? ?? '',
      uid: d['uid'] as String?,
      platform: d['platform'] as String? ?? '',
      version: d['version'] as String? ?? '',
      at: (d['at'] as Timestamp?)?.toDate(),
    );
  }
}

class UserFeedback {
  const UserFeedback({
    required this.id,
    required this.text,
    this.name = '',
    this.email = '',
    this.uid,
    this.done = false,
    this.at,
    this.images = const [],
  });

  final String id;
  final String text;
  final String name;
  final String email;
  final String? uid;
  final bool done;
  final DateTime? at;

  /// Csatolt képernyőképek (JPEG, base64).
  final List<String> images;

  factory UserFeedback.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return UserFeedback(
      id: doc.id,
      text: d['text'] as String? ?? '',
      name: d['name'] as String? ?? '',
      email: d['email'] as String? ?? '',
      uid: d['uid'] as String?,
      done: d['done'] as bool? ?? false,
      at: (d['at'] as Timestamp?)?.toDate(),
      images: [for (final i in d['images'] as List? ?? []) i as String],
    );
  }
}

/// Egy jelentés: ki, kit/mit, miért.
class UserReport {
  const UserReport({
    required this.id,
    required this.reporterUid,
    this.userUid,
    this.eventId,
    required this.reason,
    this.at,
  });

  final String id;
  final String reporterUid;
  final String? userUid;
  final String? eventId;
  final String reason;
  final DateTime? at;

  factory UserReport.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return UserReport(
      id: doc.id,
      reporterUid: d['reporterUid'] as String? ?? '',
      userUid: d['userUid'] as String?,
      eventId: d['eventId'] as String?,
      reason: d['reason'] as String? ?? '',
      at: (d['at'] as Timestamp?)?.toDate(),
    );
  }
}

/// Összesítés az áttekintéshez.
class AdminStats {
  AdminStats(
    List<UserProfile> users, {
    required this.sharedEvents,
    required this.openFeedback,
    required this.errors24h,
    DateTime? now,
  }) : total = users.length,
       active7 = users
           .where((u) => u.lastSeen != null && (now ?? DateTime.now()).difference(u.lastSeen!).inDays < 7)
           .length,
       active30 = users
           .where((u) => u.lastSeen != null && (now ?? DateTime.now()).difference(u.lastSeen!).inDays < 30)
           .length,
       newThisWeek = users
           .where((u) => u.createdAt != null && (now ?? DateTime.now()).difference(u.createdAt!).inDays < 7)
           .length,
       platforms = _countBy(users.map((u) => u.platform.isEmpty ? '?' : u.platform)),
       totals = {
         for (final k in ['events', 'tasks', 'habits']) k: users.fold(0, (acc, u) => acc + (u.counts[k] ?? 0)),
       };

  final int total;
  final int active7;
  final int active30;
  final int newThisWeek;
  final Map<String, int> platforms;
  final Map<String, int> totals;
  final int sharedEvents;
  final int openFeedback;
  final int errors24h;

  static Map<String, int> _countBy(Iterable<String> keys) {
    final result = <String, int>{};
    for (final k in keys) {
      result[k] = (result[k] ?? 0) + 1;
    }
    return result;
  }
}

/// Admin funkciók és a hozzájuk tartozó adatgyűjtés (profil, hibák, visszajelzés).
/// Hogy ki admin, azt csak a Firebase konzolban lehet beállítani (`admins/{uid}` dokumentum).
class Admin {
  Admin({FirebaseFirestore? db}) : _dbOverride = db;

  static Admin instance = Admin();

  final FirebaseFirestore? _dbOverride;
  FirebaseFirestore get _db => _dbOverride ?? FirebaseFirestore.instance;

  /// Admin-e a bejelentkezett felhasználó (a felület csak ekkor látszik; a jogot a szabályok adják).
  Future<bool> isAdmin(String uid) async {
    try {
      return (await _db.collection('admins').doc(uid).get()).exists;
    } catch (_) {
      return false;
    }
  }

  Future<bool> isBanned(String uid) async {
    try {
      return (await _db.collection('bans').doc(uid).get()).exists;
    } catch (_) {
      return false; // ha nincs internet, inkább engedjük; a szabályok úgyis tiltják az írást
    }
  }

  DateTime? _lastProfile;

  /// A felhasználó adatlapjának frissítése (óránként legfeljebb egyszer).
  Future<void> updateProfile({
    required String uid,
    required String email,
    required AppStore store,
    DateTime? createdAt,
    bool force = false,
  }) async {
    final now = DateTime.now();
    if (!force && _lastProfile != null && now.difference(_lastProfile!).inMinutes < 60) return;
    _lastProfile = now;
    await _db.collection('profiles').doc(uid).set({
      'name': store.myName,
      'email': email,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt),
      'lastSeen': FieldValue.serverTimestamp(),
      'platform': platformName,
      'version': appVersion,
      'counts': {'events': store.events.length, 'tasks': store.tasks.length, 'habits': store.habits.length},
    }, SetOptions(merge: true));
  }

  // Hibajelentés

  /// Csak az élesben futó appban kapcsoljuk be (a tesztek ne küldjenek semmit).
  static bool reportingEnabled = false;
  static String? currentUid;
  final _reported = <String>{};

  /// Egy hiba elküldése az adminnak. Ugyanazt csak egyszer, és munkamenetenként legfeljebb 20-at.
  Future<void> reportError(Object error, StackTrace? stack) async {
    if (!reportingEnabled) return;
    final message = error.toString();
    final key = message.length > 200 ? message.substring(0, 200) : message;
    if (_reported.contains(key) || _reported.length >= 20) return;
    _reported.add(key);
    try {
      await _db.collection('errors').add({
        'message': message.length > 1000 ? message.substring(0, 1000) : message,
        'stack': (stack?.toString() ?? '').split('\n').take(25).join('\n'),
        'uid': currentUid,
        'platform': platformName,
        'version': appVersion,
        'at': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Ha a hibajelentés sem megy (pl. nincs internet), nem csinálunk belőle újabb hibát.
    }
  }

  /// Legfeljebb ennyi képernyőkép csatolható egy bejelentéshez.
  static const maxScreenshots = 3;

  /// Egy képernyőkép legfeljebb ekkora lehet (hogy a három együtt beférjen egy dokumentumba).
  static const maxScreenshotBytes = 240 * 1024;

  /// Képernyőkép előkészítése: legfeljebb 1280 px, JPEG; ha még mindig nagy, kisebb minőséggel.
  /// [FormatException]-t dob, ha nem kép.
  static Uint8List prepareScreenshot(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) throw const FormatException('Ezt a képet nem tudom megnyitni.');
    var image = img.bakeOrientation(decoded);
    final longest = image.width > image.height ? image.width : image.height;
    if (longest > 1280) {
      image = image.width >= image.height ? img.copyResize(image, width: 1280) : img.copyResize(image, height: 1280);
    }
    var quality = 75;
    var out = Uint8List.fromList(img.encodeJpg(image, quality: quality));
    while (out.length > maxScreenshotBytes && quality > 35) {
      quality -= 10;
      image = img.copyResize(image, width: (image.width * 0.85).round());
      out = Uint8List.fromList(img.encodeJpg(image, quality: quality));
    }
    if (out.length > maxScreenshotBytes) throw const FormatException('Ez a kép túl nagy.');
    return out;
  }

  Future<void> sendFeedback({
    required String uid,
    required String name,
    required String email,
    required String text,
    List<Uint8List> images = const [],
  }) =>
      _db.collection('feedback').add({
        'uid': uid,
        'name': name,
        'email': email,
        'text': text.length > 2000 ? text.substring(0, 2000) : text,
        'platform': platformName,
        'version': appVersion,
        'done': false,
        if (images.isNotEmpty) 'images': [for (final i in images.take(maxScreenshots)) base64Encode(i)],
        'at': FieldValue.serverTimestamp(),
      });

  // Az admin felület lekérdezései

  Future<List<UserProfile>> users() async {
    final bans = {for (final d in (await _db.collection('bans').get()).docs) d.id};
    final q = await _db.collection('profiles').get();
    return [for (final d in q.docs) UserProfile.fromDoc(d, banned: bans.contains(d.id))]
      ..sort((a, b) => (b.lastSeen ?? DateTime(2000)).compareTo(a.lastSeen ?? DateTime(2000)));
  }

  Future<List<ErrorReport>> errors() async {
    final q = await _db.collection('errors').orderBy('at', descending: true).limit(200).get();
    return [for (final d in q.docs) ErrorReport.fromDoc(d)];
  }

  Future<List<UserFeedback>> feedback() async {
    final q = await _db.collection('feedback').orderBy('at', descending: true).limit(200).get();
    return [for (final d in q.docs) UserFeedback.fromDoc(d)];
  }

  /// Megosztott programok (moderáláshoz).
  Future<List<Map<String, dynamic>>> sharedEvents() async {
    final q = await _db.collection('events').limit(300).get();
    return [
      for (final d in q.docs) {...d.data(), 'id': d.id},
    ];
  }

  Future<AdminStats> stats() async {
    final all = await users();
    final events = await _db.collection('events').count().get();
    final open = await _db.collection('feedback').where('done', isEqualTo: false).count().get();
    final since = Timestamp.fromDate(DateTime.now().subtract(const Duration(hours: 24)));
    final errs = await _db.collection('errors').where('at', isGreaterThan: since).count().get();
    return AdminStats(all, sharedEvents: events.count ?? 0, openFeedback: open.count ?? 0, errors24h: errs.count ?? 0);
  }

  Future<void> setBanned(String uid, bool banned) async {
    final ref = _db.collection('bans').doc(uid);
    banned ? await ref.set({'at': FieldValue.serverTimestamp()}) : await ref.delete();
  }

  /// Egy felhasználó összes felhőbeli adatának törlése (a fiókját a Firebase konzolban lehet törölni).
  Future<void> deleteUserData(String uid) async {
    for (final kind in ['events', 'tasks', 'habits', 'groups', 'journal', 'moodTags', 'moodFaces', 'meta', 'push']) {
      final q = await _db.collection('users').doc(uid).collection(kind).get();
      for (var i = 0; i < q.docs.length; i += 400) {
        final batch = _db.batch();
        for (final d in q.docs.skip(i).take(400)) {
          batch.delete(d.reference);
        }
        await batch.commit();
      }
    }
    await _db.collection('profiles').doc(uid).delete();
  }

  Future<void> deleteError(String id) => _db.collection('errors').doc(id).delete();

  /// Az összes ilyen szövegű hiba törlése (ha kijavítottuk).
  Future<void> deleteErrorsLike(String message) async {
    final q = await _db.collection('errors').where('message', isEqualTo: message).get();
    final batch = _db.batch();
    for (final d in q.docs) {
      batch.delete(d.reference);
    }
    await batch.commit();
  }

  /// Felhasználói jelentések (felhasználóról vagy közös programról), a legújabb elöl.
  Future<List<UserReport>> reports() async {
    final q = await _db.collection('reports').orderBy('at', descending: true).limit(200).get();
    return [for (final d in q.docs) UserReport.fromDoc(d)];
  }

  Future<void> deleteReport(String id) => _db.collection('reports').doc(id).delete();

  /// Ami az admin figyelmére vár: nyitott visszajelzések és jelentések (a számlálóhoz).
  Stream<int> watchOpenCount() {
    late final StreamController<int> controller;
    var feedback = 0, reports = 0;
    final subs = <StreamSubscription<void>>[];
    controller = StreamController<int>(
      onListen: () {
        subs
          ..add(_db.collection('feedback').where('done', isEqualTo: false).snapshots().listen((q) {
            feedback = q.size;
            controller.add(feedback + reports);
          }, onError: controller.addError))
          ..add(_db.collection('reports').snapshots().listen((q) {
            reports = q.size;
            controller.add(feedback + reports);
          }, onError: controller.addError));
      },
      onCancel: () async {
        for (final s in subs) {
          await s.cancel();
        }
      },
    );
    return controller.stream;
  }

  Future<void> setFeedbackDone(String id, bool done) => _db.collection('feedback').doc(id).update({'done': done});

  Future<void> deleteFeedback(String id) => _db.collection('feedback').doc(id).delete();

  /// Egy megosztott program és az üzenőfala törlése (moderálás).
  Future<void> deleteSharedEvent(String id) async {
    final ref = _db.collection('events').doc(id);
    for (final sub in ['messages', 'rsvps', 'reactions', 'photos', 'photoData']) {
      final q = await ref.collection(sub).get();
      final batch = _db.batch();
      for (final d in q.docs) {
        batch.delete(d.reference);
      }
      await batch.commit();
    }
    await ref.delete();
  }
}
