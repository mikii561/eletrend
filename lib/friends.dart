import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'models.dart';
import 'store.dart';

/// Egy barát az appban (fiókkal), és amit megosztott magáról.
class Friend {
  const Friend({required this.uid, required this.name, this.streaks = const []});

  final String uid;
  final String name;

  /// A legjobb sorozatai (cél neve, nap), ha megosztja; különben üres.
  final List<(String, int)> streaks;
}

class FriendRequest {
  const FriendRequest({required this.fromUid, required this.fromName});

  final String fromUid;
  final String fromName;
}

/// Hibák a barátkezelésnél, magyarul.
class FriendException implements Exception {
  const FriendException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Barátok fiókkal: barátkód, jelölés, elfogadás, sorozatok megosztása, meghívás egy gombnyomással.
///
/// Felhő:
/// - `codes/{KÓD}`: kinek a kódja (bárki megnézheti, aki ismeri a kódot)
/// - `people/{uid}`: név, kód, megosztott sorozatok (a barátai olvashatják)
/// - `requests/{címzett}/items/{küldő}`: barátjelölések
/// - `friendships/{uid}/list/{barát}`: a barátlista (mindkét oldalon)
/// - `inbox/{uid}/items/{programId}`: barát által küldött meghívások
class Friends {
  Friends({FirebaseFirestore? db}) : _dbOverride = db;

  static Friends instance = Friends();

  final FirebaseFirestore? _dbOverride;
  FirebaseFirestore get _db => _dbOverride ?? FirebaseFirestore.instance;

  /// Kódban nem használunk összetéveszthető karaktereket (0/O, 1/I/L).
  static const _alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

  String? _uid;
  AppStore? _store;
  String? myCode;
  String? _lastCard;
  Timer? _debounce;

  /// Bejelentkezéskor: saját kód (ha még nincs) és névjegy; utána a változásokat követi.
  Future<void> start(String uid, AppStore store, {Random? random}) async {
    _uid = uid;
    _store = store;
    final me = await _db.collection('people').doc(uid).get();
    myCode = me.data()?['code'] as String?;
    if (myCode == null) {
      final rnd = random ?? Random.secure();
      for (var attempt = 0; attempt < 5 && myCode == null; attempt++) {
        final code = List.generate(6, (_) => _alphabet[rnd.nextInt(_alphabet.length)]).join();
        final ref = _db.collection('codes').doc(code);
        final taken = await _db.runTransaction((tx) async {
          if ((await tx.get(ref)).exists) return true;
          tx.set(ref, {'uid': uid});
          return false;
        });
        if (!taken) myCode = code;
      }
    }
    await _updateCard(force: true);
    store.removeListener(_onChange);
    store.addListener(_onChange);
  }

  void stop() {
    _debounce?.cancel();
    _store?.removeListener(_onChange);
    _uid = null;
    _store = null;
    myCode = null;
    _lastCard = null;
  }

  void _onChange() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), () => _updateCard().catchError((Object e) {
          debugPrint('Névjegy frissítése később: $e');
        }));
  }

  /// A barátoknak látható névjegy: név, kód és (ha engedted) a sorozataid.
  Map<String, dynamic> _card() {
    final s = _store!;
    final streaks = [
      for (final h in s.habits)
        if (h.streak() > 0) {'name': h.name, 'days': h.streak()},
    ]..sort((a, b) => (b['days'] as int).compareTo(a['days'] as int));
    return {
      'name': s.myName,
      'code': myCode,
      'streaks': s.shareStreaks ? streaks.take(5).toList() : [],
    };
  }

  Future<void> _updateCard({bool force = false}) async {
    if (_uid == null) return;
    final card = _card();
    final key = card.toString();
    if (!force && key == _lastCard) return;
    _lastCard = key;
    await _db.collection('people').doc(_uid).set({...card, 'updatedAt': FieldValue.serverTimestamp()});
  }

  /// Be van-e kapcsolódva (bejelentkezett felhasználóval).
  bool get ready => _uid != null;

  String get _me => _uid ?? (throw const FriendException('Előbb jelentkezz be.'));

  /// Barátjelölés kóddal.
  Future<String> addByCode(String code) async {
    final clean = code.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (clean.length != 6) throw const FriendException('A kód 6 karakterből áll.');
    if (clean == myCode) throw const FriendException('Ez a saját kódod. 🙂');
    final target = await _db.collection('codes').doc(clean).get();
    if (!target.exists) throw const FriendException('Nincs ilyen kód. Nézd meg, jól írtad-e be.');
    final uid = target.data()!['uid'] as String;
    if ((await _db.collection('friendships').doc(_me).collection('list').doc(uid).get()).exists) {
      throw const FriendException('Ő már a barátod.');
    }
    await _db.collection('requests').doc(uid).collection('items').doc(_me).set({
      'fromName': _store!.myName,
      'at': FieldValue.serverTimestamp(),
    });
    return uid;
  }

  Stream<List<FriendRequest>> watchRequests() => _db
      .collection('requests')
      .doc(_me)
      .collection('items')
      .snapshots()
      .map((q) => [for (final d in q.docs) FriendRequest(fromUid: d.id, fromName: d.data()['fromName'] as String? ?? '?')]);

  /// Elfogadás: mindkettőtök listájára felkerültök.
  Future<void> accept(FriendRequest r) async {
    final batch = _db.batch()
      ..set(_db.collection('friendships').doc(_me).collection('list').doc(r.fromUid), {
        'name': r.fromName,
        'since': FieldValue.serverTimestamp(),
      })
      ..set(_db.collection('friendships').doc(r.fromUid).collection('list').doc(_me), {
        'name': _store!.myName,
        'since': FieldValue.serverTimestamp(),
      });
    await batch.commit();
    await decline(r);
  }

  Future<void> decline(FriendRequest r) => _db.collection('requests').doc(_me).collection('items').doc(r.fromUid).delete();

  Future<void> remove(String friendUid) async {
    final batch = _db.batch()
      ..delete(_db.collection('friendships').doc(_me).collection('list').doc(friendUid))
      ..delete(_db.collection('friendships').doc(friendUid).collection('list').doc(_me));
    await batch.commit();
  }

  /// A barátok listája a névjegyükkel (sorozatokkal) együtt.
  Stream<List<Friend>> watchFriends() => _db.collection('friendships').doc(_me).collection('list').snapshots().asyncMap((q) async {
        final friends = <Friend>[];
        for (final d in q.docs) {
          final name = d.data()['name'] as String? ?? '?';
          try {
            final card = (await _db.collection('people').doc(d.id).get()).data();
            friends.add(Friend(
              uid: d.id,
              name: card?['name'] as String? ?? name,
              streaks: [
                for (final s in card?['streaks'] as List? ?? [])
                  ((s as Map)['name'] as String, (s['days'] as num).toInt()),
              ],
            ));
          } catch (_) {
            friends.add(Friend(uid: d.id, name: name));
          }
        }
        return friends..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      });

  /// Meghívás egy gombnyomással: a barátok „Meghívásaim” listájába kerül (a program már meg van osztva).
  Future<void> invite(Event event, List<String> friendUids) async {
    final batch = _db.batch();
    for (final f in friendUids) {
      batch.set(_db.collection('inbox').doc(f).collection('items').doc(event.shareId), {
        'title': event.title,
        'date': event.nextDate().toIso8601String(),
        'fromUid': _me,
        'fromName': _store!.myName,
        'at': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  /// A barátoktól kapott meghívások átkerülnek a saját „Meghívásaim” listába.
  StreamSubscription<void> listenInbox() =>
      _db.collection('inbox').doc(_me).collection('items').snapshots().listen((q) async {
        for (final d in q.docs) {
          final data = d.data();
          _store?.saveInvite(Invite(
            id: d.id,
            title: data['title'] as String? ?? '',
            date: DateTime.tryParse(data['date'] as String? ?? '') ?? DateTime.now(),
          ));
          await d.reference.delete();
        }
      }, onError: (Object e) => debugPrint('Meghívások később: $e'));
}
