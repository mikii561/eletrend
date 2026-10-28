import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'ideas.dart';

/// Egy helyszín a közösségi ötletekhez: név, város, ország, és ha van, koordináta.
class IdeaPlace {
  const IdeaPlace({this.name = '', this.city = '', this.country = '', this.lat, this.lng});

  final String name;
  final String city;
  final String country;
  final double? lat;
  final double? lng;

  bool get hasPoint => lat != null && lng != null;

  /// Pl. „Budapest, Magyarország”.
  String get label => [if (city.isNotEmpty) city, if (country.isNotEmpty) country].join(', ');

  Map<String, dynamic> toJson() => {'name': name, 'city': city, 'country': country, 'lat': lat, 'lng': lng};

  factory IdeaPlace.fromJson(Map<String, dynamic> j) => IdeaPlace(
        name: j['name'] as String? ?? '',
        city: j['city'] as String? ?? '',
        country: j['country'] as String? ?? '',
        lat: (j['lat'] as num?)?.toDouble(),
        lng: (j['lng'] as num?)?.toDouble(),
      );
}

/// Egy felhasználó által mindenkivel megosztott programötlet.
class CommunityIdea {
  const CommunityIdea({
    required this.id,
    required this.title,
    required this.emoji,
    required this.authorUid,
    required this.authorName,
    this.text = '',
    this.tags = const {},
    this.place = const IdeaPlace(),
    this.createdAt,
  });

  final String id;
  final String title;
  final String text;
  final String emoji;
  final Set<IdeaTag> tags;
  final String authorUid;
  final String authorName;
  final IdeaPlace place;
  final DateTime? createdAt;

  factory CommunityIdea.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return CommunityIdea(
      id: doc.id,
      title: d['title'] as String? ?? '',
      text: d['text'] as String? ?? '',
      emoji: d['emoji'] as String? ?? '💡',
      tags: {for (final t in d['tags'] as List? ?? []) ?IdeaTag.values.asNameMap()[t]},
      authorUid: d['authorUid'] as String? ?? '',
      authorName: d['authorName'] as String? ?? '',
      place: IdeaPlace(
        name: d['placeName'] as String? ?? '',
        city: d['city'] as String? ?? '',
        country: d['country'] as String? ?? '',
        lat: (d['lat'] as num?)?.toDouble(),
        lng: (d['lng'] as num?)?.toDouble(),
      ),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// Egy ötlet kedvelései és értékelései.
class IdeaScore {
  int likes = 0;
  int ratingSum = 0;
  int ratingCount = 0;

  double? get average => ratingCount == 0 ? null : ratingSum / ratingCount;

  /// Rendezéshez: kevés értékelésnél a középérték felé húzzuk, hogy egyetlen 5 csillag ne előzze
  /// meg a sok 4,8-ast.
  double get weighted => (ratingSum + 3.5 * 2) / (ratingCount + 2);
}

/// A saját szavazatom egy ötletre.
class MyVote {
  const MyVote({this.liked = false, this.rating = 0});

  final bool liked;

  /// 1–5 csillag; 0 = még nem értékeltem.
  final int rating;
}

enum IdeaSort {
  rating('⭐ Legjobbra értékelt'),
  likes('❤️ Legtöbb kedvelés'),
  newest('🆕 Legújabb'),
  nearby('📍 Közelben');

  const IdeaSort(this.label);

  final String label;
}

/// Két pont távolsága kilométerben.
double distanceKm(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371.0;
  double rad(double d) => d * pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLng = rad(lng2 - lng1);
  final a = sin(dLat / 2) * sin(dLat / 2) + cos(rad(lat1)) * cos(rad(lat2)) * sin(dLng / 2) * sin(dLng / 2);
  return 2 * r * asin(sqrt(a));
}

/// Szűrés és rendezés. „Közelben”: legfeljebb [radiusKm] távolságra az otthonodtól.
List<CommunityIdea> sortAndFilter(
  List<CommunityIdea> ideas,
  Map<String, IdeaScore> scores, {
  IdeaSort sort = IdeaSort.rating,
  String? country,
  String? city,
  IdeaPlace? home,
  double radiusKm = 30,
  Set<IdeaTag> tags = const {},
}) {
  IdeaScore score(CommunityIdea i) => scores[i.id] ?? IdeaScore();
  double? distance(CommunityIdea i) => home != null && home.hasPoint && i.place.hasPoint
      ? distanceKm(home.lat!, home.lng!, i.place.lat!, i.place.lng!)
      : null;

  final list = ideas.where((i) {
    if (country != null && i.place.country != country) return false;
    if (city != null && i.place.city != city) return false;
    if (!i.tags.containsAll(tags)) return false;
    if (sort == IdeaSort.nearby) {
      final d = distance(i);
      return d != null && d <= radiusKm;
    }
    return true;
  }).toList();

  int newest(CommunityIdea a, CommunityIdea b) => (b.createdAt ?? DateTime(2000)).compareTo(a.createdAt ?? DateTime(2000));
  list.sort(switch (sort) {
    IdeaSort.rating => (a, b) {
        final c = score(b).weighted.compareTo(score(a).weighted);
        return c != 0 ? c : newest(a, b);
      },
    IdeaSort.likes => (a, b) {
        final c = score(b).likes.compareTo(score(a).likes);
        return c != 0 ? c : newest(a, b);
      },
    IdeaSort.newest => newest,
    IdeaSort.nearby => (a, b) => distance(a)!.compareTo(distance(b)!),
  });
  return list;
}

/// Közösségi ötletek a felhőben: `ideas/{id}`, szavazatok `ideas/{id}/votes/{uid}`,
/// jelentések `ideas/{id}/reports/{uid}`.
class Community {
  Community({FirebaseFirestore? db}) : _dbOverride = db;

  static Community instance = Community();

  final FirebaseFirestore? _dbOverride;
  FirebaseFirestore get _db => _dbOverride ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _ideas => _db.collection('ideas');

  /// A legújabb (legfeljebb 300) ötlet; a szűrés és rendezés a telefonon történik.
  Future<List<CommunityIdea>> latest({int limit = 300}) async {
    final q = await _ideas.orderBy('createdAt', descending: true).limit(limit).get();
    return [for (final d in q.docs) CommunityIdea.fromDoc(d)];
  }

  /// Minden ötlet pontszáma és a saját szavazataim, egyetlen lekérdezéssel.
  Future<({Map<String, IdeaScore> scores, Map<String, MyVote> mine})> votes(String? myUid) async {
    final q = await _db.collectionGroup('votes').get();
    final scores = <String, IdeaScore>{};
    final mine = <String, MyVote>{};
    for (final d in q.docs) {
      final data = d.data();
      final ideaId = data['ideaId'] as String?;
      if (ideaId == null) continue;
      final s = scores.putIfAbsent(ideaId, IdeaScore.new);
      final liked = data['liked'] as bool? ?? false;
      final rating = (data['rating'] as num?)?.toInt() ?? 0;
      if (liked) s.likes++;
      if (rating > 0) {
        s.ratingSum += rating;
        s.ratingCount++;
      }
      if (d.id == myUid) mine[ideaId] = MyVote(liked: liked, rating: rating);
    }
    return (scores: scores, mine: mine);
  }

  Future<String> publish({
    required String uid,
    required String authorName,
    required String title,
    required String emoji,
    String text = '',
    Set<IdeaTag> tags = const {},
    IdeaPlace place = const IdeaPlace(),
  }) async {
    final ref = await _ideas.add({
      'title': title.trim(),
      'text': text.trim(),
      'emoji': emoji,
      'tags': [for (final t in tags) t.name],
      'authorUid': uid,
      'authorName': authorName,
      'placeName': place.name,
      'city': place.city,
      'country': place.country,
      'lat': place.lat,
      'lng': place.lng,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> vote(String ideaId, String uid, MyVote vote) =>
      _ideas.doc(ideaId).collection('votes').doc(uid).set({'ideaId': ideaId, 'liked': vote.liked, 'rating': vote.rating});

  Future<void> report(String ideaId, String uid, String reason) => _ideas.doc(ideaId).collection('reports').doc(uid).set({
        'ideaId': ideaId,
        'reason': reason.length > 200 ? reason.substring(0, 200) : reason,
        'at': FieldValue.serverTimestamp(),
      });

  /// Jelentések száma ötletenként (az adminnak).
  Future<Map<String, List<String>>> reports() async {
    final q = await _db.collectionGroup('reports').get();
    final result = <String, List<String>>{};
    for (final d in q.docs) {
      final ideaId = d.data()['ideaId'] as String?;
      if (ideaId != null) result.putIfAbsent(ideaId, () => []).add(d.data()['reason'] as String? ?? '');
    }
    return result;
  }

  /// Törlés. Az admin a szavazatokat és jelentéseket is eltakarítja; a szerző csak az ötletet
  /// törölheti (a megmaradt szavazatok nem látszanak sehol).
  Future<void> delete(String ideaId, {bool asAdmin = false}) async {
    final ref = _ideas.doc(ideaId);
    for (final sub in asAdmin ? ['votes', 'reports'] : const <String>[]) {
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
