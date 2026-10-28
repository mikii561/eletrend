import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'models.dart';
import 'store.dart';

/// Bejelentkezési hiba, magyar üzenettel.
class AccountException implements Exception {
  const AccountException(this.message);

  final String message;

  @override
  String toString() => message;
}

String _hungarian(FirebaseAuthException e) => switch (e.code) {
      'invalid-email' => 'Ez nem érvényes e-mail-cím.',
      'email-already-in-use' => 'Ezzel az e-mail-címmel már van fiók. Jelentkezz be!',
      'weak-password' => 'Túl gyenge a jelszó: legalább 6 karakter legyen.',
      'user-not-found' || 'wrong-password' || 'invalid-credential' => 'Hibás e-mail-cím vagy jelszó.',
      'user-disabled' => 'Ezt a fiókot letiltották.',
      'too-many-requests' => 'Túl sok próbálkozás. Várj egy kicsit, és próbáld újra.',
      'network-request-failed' => 'Nincs internet. Ellenőrizd a kapcsolatot!',
      'requires-recent-login' => 'Biztonsági okból add meg újra a jelszavad.',
      'operation-not-allowed' => 'Az e-mailes regisztráció nincs bekapcsolva a Firebase-ben.',
      _ => 'Valami hiba történt (${e.code}). Próbáld újra.',
    };

/// Felhasználói fiók: regisztráció, bejelentkezés, kijelentkezés, törlés.
/// Az adatok a fiókhoz kötve a felhőben vannak (lásd [CloudSync]).
class Account {
  Account({FirebaseAuth? auth, FirebaseFirestore? db})
      : _authOverride = auth,
        _dbOverride = db;

  static Account instance = Account();

  final FirebaseAuth? _authOverride;
  final FirebaseFirestore? _dbOverride;

  /// A bejelentkezett fiók szinkronizálása (null, ha nincs bejelentkezve).
  CloudSync? sync;

  FirebaseAuth get auth => _authOverride ?? FirebaseAuth.instance;
  FirebaseFirestore get db => _dbOverride ?? FirebaseFirestore.instance;

  /// A bejelentkezett (nem névtelen) felhasználó, vagy null.
  User? get user {
    final u = auth.currentUser;
    return u == null || u.isAnonymous ? null : u;
  }

  /// Változik, ha valaki be- vagy kijelentkezik.
  Stream<User?> get changes => auth.authStateChanges().map((u) => u == null || u.isAnonymous ? null : u);

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on FirebaseAuthException catch (e) {
      throw AccountException(_hungarian(e));
    }
  }

  /// Új fiók. Ha a böngészőben már volt névtelen munkamenet (pl. egy meghívásnál),
  /// azt alakítjuk fiókká, így a korábbi visszajelzések és meghívók megmaradnak.
  Future<User> register({required String name, required String email, required String password}) => _guard(() async {
        final credential = EmailAuthProvider.credential(email: email.trim(), password: password);
        final current = auth.currentUser;
        final result = current != null && current.isAnonymous
            ? await current.linkWithCredential(credential)
            : await auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
        await result.user!.updateDisplayName(name.trim());
        return result.user!;
      });

  Future<User> login({required String email, required String password}) => _guard(() async {
        final result = await auth.signInWithEmailAndPassword(email: email.trim(), password: password);
        return result.user!;
      });

  Future<void> resetPassword(String email) => _guard(() async {
        await auth.setLanguageCode('hu');
        await auth.sendPasswordResetEmail(email: email.trim());
      });

  Future<void> logout() => auth.signOut();

  /// A fiók és minden felhőbeli adat végleges törlése. Biztonsági okból a jelszó kell hozzá.
  Future<void> deleteAccount(String password) => _guard(() async {
        final u = user!;
        await u.reauthenticateWithCredential(EmailAuthProvider.credential(email: u.email!, password: password));
        await CloudSync(store: null, uid: u.uid, db: db).deleteAll();
        await u.delete();
      });
}

/// A felhasználó adatainak szinkronizálása a felhővel: `users/{uid}/{fajta}/{azonosító}`.
/// Minden naplóbejegyzés, szokás, program és címke külön dokumentum, így egyik sem
/// ütközik a Firestore 1 MB-os dokumentumkorlátjába (a képek miatt fontos).
class CloudSync {
  CloudSync({required this.store, required this.uid, FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  final AppStore? store;
  final String uid;
  final FirebaseFirestore _db;

  static const kinds = ['events', 'habits', 'journal', 'moodTags', 'moodFaces', 'meta'];

  /// Amit legutóbb feltöltöttünk/letöltöttünk (útvonal → a tartalom ujjlenyomata), hogy csak a
  /// változást küldjük. Az eszközön megmarad, így az offline módosítások is felkerülnek később.
  late final Map<String, String> _known = {...?store?.syncHashesFor(uid)};
  Timer? _debounce;
  Future<void>? _pushing;

  CollectionReference<Map<String, dynamic>> _col(String kind) => _db.collection('users').doc(uid).collection(kind);

  /// Az app jelenlegi állapota dokumentumokra bontva.
  Map<String, Map<String, dynamic>> _snapshot() {
    final s = store!;
    return {
      for (final e in s.events) 'events/${e.id}': e.toJson(),
      for (final h in s.habits) 'habits/${h.id}': h.toJson(),
      for (final j in s.journal) 'journal/${j.id}': j.toJson(),
      for (var i = 0; i < s.moodTags.length; i++) 'moodTags/${s.moodTags[i].id}': {...s.moodTags[i].toJson(), 'order': i},
      for (final f in s.moodFaces) 'moodFaces/${f.id}': f.toJson(),
      'meta/settings': s.cloudSettings(),
    };
  }

  /// A változások feltöltése (a törölt elemeket a felhőből is töröljük).
  Future<void> push() async {
    await _pushing;
    _pushing = _push();
    await _pushing;
  }

  Future<void> _push() async {
    final now = _snapshot();
    final writes = <String, Map<String, dynamic>?>{
      for (final e in now.entries)
        if (_known[e.key] != _hash(e.value)) e.key: e.value,
      for (final path in _known.keys)
        if (!now.containsKey(path)) path: null,
    };
    if (writes.isEmpty) return;
    // Egy kötegben legfeljebb 500 művelet lehet.
    final entries = writes.entries.toList();
    for (var i = 0; i < entries.length; i += 400) {
      final batch = _db.batch();
      for (final e in entries.skip(i).take(400)) {
        final slash = e.key.indexOf('/');
        final ref = _col(e.key.substring(0, slash)).doc(e.key.substring(slash + 1));
        e.value == null ? batch.delete(ref) : batch.set(ref, e.value!);
      }
      await batch.commit();
    }
    for (final e in writes.entries) {
      e.value == null ? _known.remove(e.key) : _known[e.key] = _hash(e.value!);
    }
    store!.saveSyncHashes(uid, _known);
  }

  /// Van-e már adat a fiókban (új fióknál nincs).
  Future<bool> hasCloudData() async => (await _col('meta').doc('settings').get()).exists;

  /// Letölti a fiók adatait, és ezekkel írja felül az eszközön lévőket.
  Future<void> pull() async {
    final docs = <String, List<Map<String, dynamic>>>{};
    final known = <String, String>{};
    for (final kind in kinds) {
      final q = await _col(kind).get();
      docs[kind] = [for (final d in q.docs) d.data()];
      for (final d in q.docs) {
        known['$kind/${d.id}'] = _hash(d.data());
      }
    }
    // Ha a felhőben semmi sem változott, nem cseréljük le az adatokat (egy épp nyitott szerkesztő
    // így a saját példányán dolgozhat tovább).
    final unchanged = known.length == _known.length && known.entries.every((e) => _known[e.key] == e.value);
    _known
      ..clear()
      ..addAll(known);
    if (unchanged && store!.syncUid == uid) return;
    final tags = [...docs['moodTags']!]..sort((a, b) => (a['order'] as int? ?? 0).compareTo(b['order'] as int? ?? 0));
    store!.applyCloud(
      events: docs['events']!.map(Event.fromJson).toList(),
      habits: docs['habits']!.map(Habit.fromJson).toList(),
      journal: docs['journal']!.map(JournalEntry.fromJson).toList(),
      moodTags: tags.map(MoodTag.fromJson).toList(),
      moodFaces: docs['moodFaces']!.map(MoodTag.fromJson).toList(),
      settings: docs['meta']!.isEmpty ? null : docs['meta']!.first,
    );
    store!.saveSyncHashes(uid, _known);
  }

  /// Ezen az eszközön már ehhez a fiókhoz szinkronizáltunk (akkor offline is indulhat).
  bool get knownDevice => store!.syncUid == uid;

  /// Bejelentkezés után. Ismert eszközön: a közben (akár offline) történt változások fel, a máshol
  /// történtek le. Új eszközön: ha a fiókban már van adat, azt töltjük le, különben az eszközön
  /// lévőt töltjük fel (így kerülnek az első regisztrációkor a régi adatok a fiókba).
  Future<void> start() async {
    if (knownDevice) {
      await push();
      await pull();
    } else if (await hasCloudData()) {
      await pull();
    } else {
      await push();
    }
  }

  /// Innentől minden változás (kis késleltetéssel) felkerül.
  void listen() {
    store!.removeListener(_onChange);
    store!.addListener(_onChange);
  }

  void _onChange() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 1200), () => push().catchError((Object e) {
          debugPrint('Felhő mentése nem sikerült, később újra: $e');
        }));
  }

  /// Visszatéréskor: előbb a függő változások fel, aztán a máshol történtek le.
  Future<void> refresh() async {
    _debounce?.cancel();
    await push();
    await pull();
  }

  void stop() {
    _debounce?.cancel();
    store?.removeListener(_onChange);
  }

  /// A tartalom ujjlenyomata. A kulcsokat sorba rendezzük, mert a felhő más sorrendben adhatja vissza
  /// a mezőket, és ettől még nem változott semmi.
  static String _hash(Map<String, dynamic> data) => sha1.convert(utf8.encode(jsonEncode(_canonical(data)))).toString();

  static Object? _canonical(Object? v) => switch (v) {
        Map() => SplayTreeMap<String, Object?>.of({for (final e in v.entries) e.key.toString(): _canonical(e.value)}),
        List() => [for (final x in v) _canonical(x)],
        double() when v == v.roundToDouble() => v.toInt(),
        _ => v,
      };

  /// A fiók összes adatának törlése a felhőből.
  Future<void> deleteAll() async {
    for (final kind in kinds) {
      final q = await _col(kind).get();
      for (var i = 0; i < q.docs.length; i += 400) {
        final batch = _db.batch();
        for (final d in q.docs.skip(i).take(400)) {
          batch.delete(d.reference);
        }
        await batch.commit();
      }
    }
  }
}
