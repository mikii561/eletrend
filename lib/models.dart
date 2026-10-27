/// Az app adatmodelljei: programok, szokások, naplóbejegyzések.
library;

/// Egy napot azonosító kulcs, pl. "2026-10-27".
String dayKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

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
    if (!isDoneOn(day)) day = day.subtract(const Duration(days: 1));
    var count = 0;
    while (isDoneOn(day)) {
      count++;
      day = day.subtract(const Duration(days: 1));
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
  });

  final String id;
  DateTime date;

  /// 1 (nagyon rossz) – 5 (nagyon jó)
  int mood;
  String gratitude;
  String note;

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'mood': mood,
        'gratitude': gratitude,
        'note': note,
      };

  factory JournalEntry.fromJson(Map<String, dynamic> j) => JournalEntry(
        id: j['id'] as String,
        date: DateTime.parse(j['date'] as String),
        mood: j['mood'] as int,
        gratitude: j['gratitude'] as String? ?? '',
        note: j['note'] as String? ?? '',
      );
}

const moodEmojis = ['😞', '🙁', '😐', '🙂', '😄'];
const moodLabels = ['Nagyon rossz', 'Rossz', 'Átlagos', 'Jó', 'Nagyon jó'];
