import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'firebase_options.dart';
import 'models.dart';

/// Visszajelzés egy meghívásra.
enum RsvpStatus {
  yes('Megyek'),
  maybe('Talán'),
  no('Nem megyek'),
  none('Még nem jelzett');

  const RsvpStatus(this.label);

  final String label;
}

/// Reakciók egy közös programra (egy ember egyet választhat).
const reactionEmojis = ['🎉', '❤️', '😂', '👍', '🔥'];

/// Hiba a közös funkcióknál, magyarul.
class SocialException implements Exception {
  const SocialException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Egy megosztott program a felhőben (amit a meghívottak is látnak).
class SharedEvent {
  SharedEvent({
    required this.id,
    required this.title,
    required this.date,
    required this.ownerUid,
    required this.ownerName,
    this.durationMin = 120,
    this.allDay = false,
    this.category = EventCategory.social,
    this.place = '',
    this.notes = '',
    this.repeat = Repeat.none,
    this.lat,
    this.lng,
    this.limit,
    this.inviteOnly = false,
    this.going = const [],
    this.pollOptions = const [],
    this.pollClosed = false,
  });

  final String id;
  final String title;
  final DateTime date;
  final String ownerUid;
  final String ownerName;
  final int durationMin;
  final bool allDay;
  final EventCategory category;
  final String place;
  final String notes;
  final Repeat repeat;
  final double? lat;
  final double? lng;

  /// Létszámkorlát (null = nincs); a [going] lista hosszát a szabályok ellenőrzik.
  final int? limit;
  final bool inviteOnly;

  /// Akik jönnek (a létszámkorláthoz).
  final List<String> going;

  /// Az időpont-szavazás lehetőségei (üres, ha nincs szavazás).
  final List<DateTime> pollOptions;

  /// A szervező már kiválasztotta a végleges időpontot.
  final bool pollClosed;

  DateTime get end => date.add(Duration(minutes: durationMin));
  bool get pollOpen => pollOptions.length >= 2 && !pollClosed;
  bool get full => limit != null && going.length >= limit!;

  factory SharedEvent.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return SharedEvent(
      id: doc.id,
      title: d['title'] as String? ?? '',
      date: DateTime.parse(d['date'] as String),
      ownerUid: d['ownerUid'] as String? ?? '',
      ownerName: d['ownerName'] as String? ?? '',
      durationMin: (d['durationMin'] as num?)?.toInt() ?? 120,
      allDay: d['allDay'] as bool? ?? false,
      category: EventCategory.values.asNameMap()[d['category']] ?? EventCategory.social,
      place: d['place'] as String? ?? '',
      notes: d['notes'] as String? ?? '',
      lat: (d['lat'] as num?)?.toDouble(),
      lng: (d['lng'] as num?)?.toDouble(),
      repeat: Repeat.values.asNameMap()[d['repeat']] ?? Repeat.none,
      limit: (d['limit'] as num?)?.toInt(),
      inviteOnly: d['inviteOnly'] as bool? ?? false,
      going: List<String>.from(d['going'] as List? ?? []),
      pollOptions: [for (final o in d['pollOptions'] as List? ?? []) DateTime.parse(o as String)],
      pollClosed: d['pollClosed'] as bool? ?? false,
    );
  }

  /// A program a saját naptáramba (ha elfogadom a meghívást).
  Event toEvent() => Event(
    id: 'inv-$id',
    title: title,
    start: date,
    durationMin: durationMin,
    allDay: allDay,
    category: EventCategory.shared,
    place: place,
    lat: lat,
    lng: lng,
    notes: notes,
    repeat: repeat,
    shareId: id,
  );
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

/// Melyik időpont a legjobb: a legtöbben jók rá, egyenlőségnél a korábbi.
DateTime? bestOption(List<DateTime> options, Iterable<Rsvp> rsvps) {
  if (options.isEmpty) return null;
  int votes(DateTime o) => rsvps.where((r) => r.votes.contains(o.toIso8601String())).length;
  final sorted = [...options]
    ..sort((a, b) {
      final byVotes = votes(b).compareTo(votes(a));
      return byVotes != 0 ? byVotes : a.compareTo(b);
    });
  return votes(sorted.first) == 0 ? null : sorted.first;
}

/// Közös programok (meghívás, visszajelzés, létszám, szavazás, hozzászólások, reakciók) a Firebase-en.
/// Csak akkor kapcsolódik, amikor először kell.
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

  /// Firebase indítása és (ha a meghívólinket bejelentkezés nélkül nyitották meg) névtelen bejelentkezés.
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
  /// A szervező automatikusan „Megyek”.
  Future<String> publish(Event e, {required String ownerName}) async {
    await ready();
    final ref = e.shareId == null ? _firestore.collection('events').doc() : _event(e.shareId!);
    final first = e.shareId == null;
    await ref.set({
      'title': e.title,
      'date': e.start.toIso8601String(),
      'durationMin': e.durationMin,
      'allDay': e.allDay,
      'category': e.category.name,
      'place': e.place,
      'notes': e.notes,
      'lat': e.lat,
      'lng': e.lng,
      'repeat': e.repeat.name,
      'limit': e.limit,
      'inviteOnly': e.inviteOnly,
      'ownerUid': uid,
      'ownerName': ownerName,
      if (first) 'going': [uid],
      if (first) 'invitedUids': <String>[],
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    if (first) await respond(ref.id, name: ownerName, status: RsvpStatus.yes);
    return ref.id;
  }

  Future<void> unpublish(String id) async {
    await ready();
    await _event(id).delete();
  }

  /// A meghívott barátok felkerülnek a listára (csak meghívottaknak szóló programot ők láthatnak).
  Future<void> addInvited(String id, List<String> uids) async {
    await ready();
    await _event(id).update({'invitedUids': FieldValue.arrayUnion(uids)});
  }

  /// Időpont-szavazás indítása 2–3 lehetőséggel.
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

  Future<SharedEvent?> fetchEvent(String id) async {
    await ready();
    final s = await _event(id).get();
    return s.exists ? SharedEvent.fromDoc(s) : null;
  }

  Stream<List<Rsvp>> watchRsvps(String id) async* {
    await ready();
    yield* _event(id).collection('rsvps').snapshots().map((q) => [for (final d in q.docs) Rsvp.fromDoc(d)]);
  }

  /// Visszajelzés (és/vagy szavazat). „Megyek”-nél előbb a létszámlistára kerülsz; ha betelt,
  /// a szabály elutasítja, és [SocialException]-t kapsz.
  Future<void> respond(String id, {required String name, RsvpStatus? status, Set<String>? votes}) async {
    await ready();
    final me = uid!;
    final ref = _event(id).collection('rsvps').doc(me);
    final current = await ref.get();
    final old = current.exists ? Rsvp.fromDoc(current) : null;
    if (status != null && status != old?.status) {
      try {
        await _event(id).update({
          'going': status == RsvpStatus.yes ? FieldValue.arrayUnion([me]) : FieldValue.arrayRemove([me]),
        });
      } on FirebaseException catch (e) {
        if (e.code == 'permission-denied' && status == RsvpStatus.yes) {
          throw const SocialException('Betelt a létszám, most nem tudsz jelentkezni.');
        }
        rethrow;
      }
    }
    await ref.set({
      'name': name,
      'status': (status ?? old?.status ?? RsvpStatus.none).name,
      'votes': (votes ?? old?.votes ?? const <String>{}).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Hozzászólások

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
    final clean = text.trim();
    await _event(id).collection('messages').add({
      'uid': uid,
      'name': name,
      'text': clean.length > 500 ? clean.substring(0, 500) : clean,
      'at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteMessage(String id, String messageId) async {
    await ready();
    await _event(id).collection('messages').doc(messageId).delete();
  }

  // Reakciók

  /// Emoji → kik reagáltak vele.
  Stream<Map<String, List<String>>> watchReactions(String id) async* {
    await ready();
    yield* _event(id).collection('reactions').snapshots().map((q) {
      final out = <String, List<String>>{};
      for (final d in q.docs) {
        final e = d.data()['emoji'] as String?;
        if (e != null) out.putIfAbsent(e, () => []).add(d.id);
      }
      return out;
    });
  }

  /// Reakció beállítása vagy (null-lal) visszavonása.
  Future<void> react(String id, String? emoji) async {
    await ready();
    final ref = _event(id).collection('reactions').doc(uid);
    emoji == null ? await ref.delete() : await ref.set({'emoji': emoji});
  }

  @visibleForTesting
  void resetForTesting() => _ready = null;
}
