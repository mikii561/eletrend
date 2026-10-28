/// Az app adatmodelljei: programok, szokások, naplóbejegyzések.
library;

import 'dart:convert';
import 'dart:typed_data';

/// Egy napot azonosító kulcs, pl. "2026-10-27".
String dayKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// [n] naptári nappal később (negatívval korábban), délben.
/// Nem 24 órákat ad hozzá, így az óraátállítás napján sem csúszik el.
DateTime addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n, 12);

String newId() => DateTime.now().microsecondsSinceEpoch.toString();

/// Közös program barátokkal.
class Event {
  Event({
    required this.id,
    required this.title,
    required this.date,
    this.place = '',
    this.lat,
    this.lng,
    List<String>? invited,
  }) : invited = invited ?? [];

  final String id;
  String title;
  DateTime date;
  String place;

  /// A helyszín koordinátái, ha térképen lett kiválasztva.
  double? lat;
  double? lng;
  List<String> invited;

  bool get hasLocation => lat != null && lng != null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'date': date.toIso8601String(),
        'place': place,
        'lat': lat,
        'lng': lng,
        'invited': invited,
      };

  factory Event.fromJson(Map<String, dynamic> j) => Event(
        id: j['id'] as String,
        title: j['title'] as String,
        date: DateTime.parse(j['date'] as String),
        place: j['place'] as String? ?? '',
        lat: (j['lat'] as num?)?.toDouble(),
        lng: (j['lng'] as num?)?.toDouble(),
        invited: List<String>.from(j['invited'] as List? ?? []),
      );
}

/// Napi szokás, a teljesített napok kulcsaival.
class Habit {
  Habit({required this.id, required this.name, Set<String>? doneDays})
      : doneDays = doneDays ?? {};

  final String id;
  String name;
  Set<String> doneDays;

  bool isDoneOn(DateTime d) => doneDays.contains(dayKey(d));

  /// Hány egymást követő napja teljesül. Ha ma még nincs kész, a tegnapi
  /// naptól számol, így a sorozat nem nullázódik le reggel.
  int streak([DateTime? now]) {
    var day = now ?? DateTime.now();
    if (!isDoneOn(day)) day = addDays(day, -1);
    var count = 0;
    while (isDoneOn(day)) {
      count++;
      day = addDays(day, -1);
    }
    return count;
  }

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'doneDays': doneDays.toList()};

  factory Habit.fromJson(Map<String, dynamic> j) => Habit(
        id: j['id'] as String,
        name: j['name'] as String,
        doneDays: Set<String>.from(j['doneDays'] as List? ?? []),
      );
}

/// Napi hangulat- és hálanapló-bejegyzés.
class JournalEntry {
  JournalEntry({
    required this.id,
    required this.date,
    required this.mood,
    this.gratitude = '',
    this.note = '',
    this.question = '',
    this.answer = '',
    this.photoPath,
    List<String>? tags,
  }) : tags = tags ?? [];

  final String id;
  DateTime date;

  /// 1 (nagyon rossz) – 5 (nagyon jó)
  int mood;
  String gratitude;
  String note;

  /// A napi kérdés és a rá adott válasz (üres, ha nem válaszolt).
  String question;
  String answer;

  /// A nap fotója a telefon tárhelyén (null, ha nincs).
  String? photoPath;

  /// A kiválasztott hangulatcímkék azonosítói ([MoodTag.id]).
  List<String> tags;

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'mood': mood,
        'gratitude': gratitude,
        'note': note,
        'question': question,
        'answer': answer,
        'photoPath': photoPath,
        'tags': tags,
      };

  factory JournalEntry.fromJson(Map<String, dynamic> j) => JournalEntry(
        id: j['id'] as String,
        date: DateTime.parse(j['date'] as String),
        mood: j['mood'] as int,
        gratitude: j['gratitude'] as String? ?? '',
        note: j['note'] as String? ?? '',
        question: j['question'] as String? ?? '',
        answer: j['answer'] as String? ?? '',
        photoPath: j['photoPath'] as String?,
        tags: List<String>.from(j['tags'] as List? ?? []),
      );
}

/// Hangulatcímke: beépített vagy saját, emojival vagy saját képpel.
class MoodTag {
  MoodTag({required this.id, required this.name, this.emoji = '🏷️', this.image, this.visible = true});

  /// Állandó azonosító; a bejegyzések ezt tárolják, így átnevezéskor sem vesznek el.
  final String id;
  String name;
  String emoji;

  /// Megjelenik-e a napló szerkesztőjében.
  bool visible;

  /// Saját kép base64-ben (null, ha emoji van helyette).
  String? image;

  String? _decodedFrom;
  Uint8List? _bytes;

  /// A kép bájtjai; csak akkor dekódoljuk újra, ha a kép megváltozott.
  Uint8List? get imageBytes {
    if (image == null) return null;
    if (!identical(_decodedFrom, image)) {
      _bytes = base64Decode(image!);
      _decodedFrom = image;
    }
    return _bytes;
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'emoji': emoji, 'image': image, 'visible': visible};

  factory MoodTag.fromJson(Map<String, dynamic> j) => MoodTag(
        id: j['id'] as String,
        name: j['name'] as String,
        emoji: j['emoji'] as String? ?? '🏷️',
        image: j['image'] as String?,
        visible: j['visible'] as bool? ?? true,
      );
}

/// Az alap hangulatcímkék (név → emoji). A nevük egyben az azonosítójuk is.
const defaultMoodTags = {
  'boldog': '🥳',
  'nyugodt': '😌',
  'hálás': '🙏',
  'motivált': '💪',
  'produktív': '✅',
  'kreatív': '🎨',
  'szerelmes': '😍',
  'társasági': '👯',
  'fáradt': '😴',
  'stresszes': '😰',
  'szorongó': '😟',
  'ideges': '😠',
  'szomorú': '😢',
  'magányos': '🫥',
  'unatkozó': '🥱',
  'beteg': '🤒',
};

const moodEmojis = ['😞', '🙁', '😐', '🙂', '😄'];
const moodLabels = ['Nagyon rossz', 'Rossz', 'Átlagos', 'Jó', 'Nagyon jó'];
