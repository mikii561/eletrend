import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'firebase_options.dart';
import 'models.dart';

/// Visszajelzés egy meghívásra.
enum RsvpStatus {
  yes('Jövök', '✅'),
  maybe('Talán', '🤔'),
  no('Nem jövök', '❌'),
  none('Még nem jelzett', '⏳');

  const RsvpStatus(this.label, this.emoji);

  final String label;
  final String emoji;
}

/// Egy megosztott program a felhőben (amit a meghívottak is látnak).
class SharedEvent {
  SharedEvent({
    required this.id,
    required this.title,
    required this.date,
    required this.ownerUid,
    required this.ownerName,
    this.place = '',
    this.repeat = Repeat.none,
    this.lat,
    this.lng,
    this.bgTheme,
    this.bgImage,
    this.pollOptions = const [],
    this.pollClosed = false,
  });

  final String id;
  final String title;
  final DateTime date;
  final String ownerUid;
  final String ownerName;
  final String place;
  final Repeat repeat;

  /// A helyszín koordinátái (az időjáráshoz), ha a szervező térképen választotta.
  final double? lat;
  final double? lng;

  /// A szervező által választott háttér.
  final String? bgTheme;
  final String? bgImage;

  /// Az időpont-szavazás lehetőségei (üres, ha nincs szavazás).
  final List<DateTime> pollOptions;

  /// A szervező már kiválasztotta a végleges időpontot.
  final bool pollClosed;

  bool get pollOpen => pollOptions.length >= 2 && !pollClosed;

  factory SharedEvent.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return SharedEvent(
      id: doc.id,
      title: d['title'] as String? ?? '',
      date: DateTime.parse(d['date'] as String),
      ownerUid: d['ownerUid'] as String? ?? '',
      ownerName: d['ownerName'] as String? ?? '',
      place: d['place'] as String? ?? '',
      lat: (d['lat'] as num?)?.toDouble(),
      lng: (d['lng'] as num?)?.toDouble(),
      bgTheme: d['bgTheme'] as String?,
      bgImage: d['bgImage'] as String?,
      repeat: Repeat.values.asNameMap()[d['repeat']] ?? Repeat.none,
      pollOptions: [for (final o in d['pollOptions'] as List? ?? []) DateTime.parse(o as String)],
      pollClosed: d['pollClosed'] as bool? ?? false,
    );
  }
}

class Rsvp {
  const Rsvp({required this.uid, required this.name, required this.status, this.votes = const {}});

  final String uid;
  final String name;
  final RsvpStatus status;

  /// Mely időpontok jók neki (ISO dátumok, hogy a lehetőségek változása ne keverje össze).
  final Set<String> votes;

  factory Rsvp.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return Rsvp(
      uid: doc.id,
      name: d['name'] as String? ?? '?',
      status: RsvpStatus.values.asNameMap()[d['status']] ?? RsvpStatus.none,
      votes: {for (final v in d['votes'] as List? ?? []) v as String},
    );
  }
}

class ChatMessage {
  const ChatMessage({required this.id, required this.uid, required this.name, required this.text, this.at});

  final String id;
  final String uid;
  final String name;
  final String text;

  /// Null, amíg a szerver még nem rögzítette az időt.
  final DateTime? at;

  factory ChatMessage.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return ChatMessage(
      id: doc.id,
      uid: d['uid'] as String? ?? '',
      name: d['name'] as String? ?? '?',
      text: d['text'] as String? ?? '',
      at: (d['at'] as Timestamp?)?.toDate(),
    );
  }
}

/// Egy tétel a „Ki mit hoz?” listán.
class BringItem {
  const BringItem({required this.id, required this.title, required this.addedBy, this.who, this.whoName});

  final String id;
  final String title;
  final String addedBy;

  /// Aki elvállalta (null, ha még senki).
  final String? who;
  final String? whoName;

  factory BringItem.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return BringItem(
      id: doc.id,
      title: d['title'] as String? ?? '',
      addedBy: d['addedBy'] as String? ?? '',
      who: d['who'] as String?,
      whoName: d['whoName'] as String?,
    );
  }
}

/// Melyik időpont a legjobb: a legtöbben jók rá, egyenlőségnél a korábbi.
DateTime? bestOption(List<DateTime> options, Iterable<Rsvp> rsvps) {
  if (options.isEmpty) return null;
  int votes(DateTime o) => rsvps.where((r) => r.votes.contains(o.toIso8601String())).length;
  final sorted = [...options]..sort((a, b) {
      final byVotes = votes(b).compareTo(votes(a));
      return byVotes != 0 ? byVotes : a.compareTo(b);
    });
  return votes(sorted.first) == 0 ? null : sorted.first;
}

/// A közös funkciók (meghívás, visszajelzés, szavazás, üzenőfal) a Firebase-en keresztül.
/// Csak akkor kapcsolódik, amikor először kell, így az app internet nélkül is működik.
class Social {
  Social({this._db, this._auth});

  static Social instance = Social();

  /// Ide mutatnak a meghívólinkek.
  static const baseUrl = 'https://mikii561.github.io/eletrend/';

  FirebaseFirestore? _db;
  FirebaseAuth? _auth;
  Future<void>? _ready;

  FirebaseFirestore get _firestore => _db!;

  String? get uid => _auth?.currentUser?.uid;

  String linkFor(String eventId) => '$baseUrl?e=$eventId';

  /// Firebase indítása és névtelen bejelentkezés (a barátoknak nem kell regisztrálniuk).
  Future<void> ready() => _ready ??= _connect().catchError((Object e) {
        _ready = null; // legközelebb újrapróbáljuk
        throw e;
      });

  Future<void> _connect() async {
    if (_db == null) {
      if (Firebase.apps.isEmpty) await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      _db = FirebaseFirestore.instance;
      _auth = FirebaseAuth.instance;
    }
    if (_auth!.currentUser == null) await _auth!.signInAnonymously();
  }

  DocumentReference<Map<String, dynamic>> _event(String id) => _firestore.collection('events').doc(id);

  /// Kiteszi (vagy frissíti) a programot, és visszaadja a megosztási azonosítóját.
  Future<String> publish(Event e, {required String ownerName}) async {
    await ready();
    final ref = e.shareId == null ? _firestore.collection('events').doc() : _event(e.shareId!);
    await ref.set({
      'title': e.title,
      'date': e.date.toIso8601String(),
      'place': e.place,
      'lat': e.lat,
      'lng': e.lng,
      'repeat': e.repeat.name,
      'bgTheme': e.bgTheme,
      'bgImage': e.bgImage,
      'ownerUid': uid,
      'ownerName': ownerName,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    if (e.shareId == null) await respond(ref.id, name: ownerName, status: RsvpStatus.yes);
    return ref.id;
  }

  Future<void> unpublish(String id) async {
    await ready();
    await _event(id).delete();
  }

  /// Időpont-szavazás indítása 2–3 lehetőséggel (vagy lezárása üres listával).
  Future<void> setPoll(String id, List<DateTime> options) async {
    await ready();
    await _event(id).update({
      'pollOptions': [for (final o in options) o.toIso8601String()],
      'pollClosed': false,
    });
  }

  /// A szervező kiválasztja a végleges időpontot.
  Future<void> choose(String id, DateTime date) async {
    await ready();
    await _event(id).update({'date': date.toIso8601String(), 'pollClosed': true});
  }

  Stream<SharedEvent?> watchEvent(String id) async* {
    await ready();
    yield* _event(id).snapshots().map((s) => s.exists ? SharedEvent.fromDoc(s) : null);
  }

  Stream<List<Rsvp>> watchRsvps(String id) async* {
    await ready();
    yield* _event(id).collection('rsvps').snapshots().map((q) => [for (final d in q.docs) Rsvp.fromDoc(d)]);
  }

  Future<void> respond(String id, {required String name, RsvpStatus? status, Set<String>? votes}) async {
    await ready();
    final ref = _event(id).collection('rsvps').doc(uid);
    final current = await ref.get();
    final old = current.exists ? Rsvp.fromDoc(current) : null;
    await ref.set({
      'name': name,
      'status': (status ?? old?.status ?? RsvpStatus.none).name,
      'votes': (votes ?? old?.votes ?? const <String>{}).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<ChatMessage>> watchMessages(String id) async* {
    await ready();
    yield* _event(id)
        .collection('messages')
        .orderBy('at')
        .limitToLast(100)
        .snapshots()
        .map((q) => [for (final d in q.docs) ChatMessage.fromDoc(d)]);
  }

  Future<void> send(String id, {required String name, required String text}) async {
    await ready();
    await _event(id).collection('messages').add({
      'uid': uid,
      'name': name,
      'text': text.trim(),
      'at': FieldValue.serverTimestamp(),
    });
  }

  // „Ki mit hoz?”

  Stream<List<BringItem>> watchItems(String id) async* {
    await ready();
    yield* _event(id).collection('items').orderBy('at').snapshots().map((q) => [for (final d in q.docs) BringItem.fromDoc(d)]);
  }

  Future<void> addItem(String id, {required String title, required String name}) async {
    await ready();
    await _event(id).collection('items').add({
      'title': title.trim().length > 60 ? title.trim().substring(0, 60) : title.trim(),
      'addedBy': uid,
      'addedName': name,
      'who': null,
      'whoName': null,
      'at': FieldValue.serverTimestamp(),
    });
  }

  /// Elvállalom (név megadásával), vagy null névvel lemondom.
  Future<void> claimItem(String id, String itemId, {String? name}) async {
    await ready();
    await _event(id).collection('items').doc(itemId).update({'who': name == null ? null : uid, 'whoName': name});
  }

  Future<void> deleteItem(String id, String itemId) async {
    await ready();
    await _event(id).collection('items').doc(itemId).delete();
  }

  Future<void> deleteMessage(String id, String messageId) async {
    await ready();
    await _event(id).collection('messages').doc(messageId).delete();
  }

  @visibleForTesting
  void resetForTesting() => _ready = null;
}
