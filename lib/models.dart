/// Az app adatmodelljei: programok, célok, naplóbejegyzések.
library;

import 'dart:convert';
import 'dart:math';
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
    this.repeat = Repeat.none,
    List<Expense>? expenses,
    this.shareId,
    this.bgTheme,
    this.bgImage,
  })  : invited = invited ?? [],
        expenses = expenses ?? [];

  final String id;
  String title;
  DateTime date;
  String place;

  /// A helyszín koordinátái, ha térképen lett kiválasztva.
  double? lat;
  double? lng;
  List<String> invited;

  bool get hasLocation => lat != null && lng != null;

  /// Ismétlődés; a [date] ilyenkor az első alkalom.
  Repeat repeat;

  /// Ki mennyit fizetett a programon.
  List<Expense> expenses;

  /// A felhőbe kitett példány azonosítója, ha megosztottad a barátaiddal (a meghívólinkben is ez van).
  String? shareId;

  /// Háttér: kész téma kulcsa, vagy saját fotó (base64 JPEG). A fotó az erősebb.
  String? bgTheme;
  String? bgImage;

  /// Az [i]-edik alkalom időpontja (0 = az első). Naptári napokkal számol, így
  /// óraátállításkor sem csúszik el az időpont.
  DateTime occurrence(int i) => switch (repeat) {
        Repeat.none => date,
        Repeat.weekly => DateTime(date.year, date.month, date.day + 7 * i, date.hour, date.minute),
        Repeat.biweekly => DateTime(date.year, date.month, date.day + 14 * i, date.hour, date.minute),
        Repeat.monthly => DateTime(
            date.year,
            date.month + i,
            min(date.day, DateTime(date.year, date.month + i + 1, 0).day),
            date.hour,
            date.minute,
          ),
      };

  /// A következő alkalom a mai naptól (ma is beleszámít). Nem ismétlődőnél maga a [date].
  DateTime nextDate([DateTime? now]) {
    if (repeat == Repeat.none) return date;
    final today = now ?? DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    var i = 0;
    while (occurrence(i).isBefore(start)) {
      i++;
    }
    return occurrence(i);
  }

  /// Van-e alkalma az adott napon.
  bool occursOn(DateTime day) {
    final key = dayKey(day);
    for (var i = 0;; i++) {
      final d = occurrence(i);
      if (dayKey(d) == key) return true;
      if (repeat == Repeat.none || d.isAfter(DateTime(day.year, day.month, day.day, 23, 59))) return false;
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'date': date.toIso8601String(),
        'place': place,
        'lat': lat,
        'lng': lng,
        'invited': invited,
        'repeat': repeat.name,
        'expenses': expenses.map((x) => x.toJson()).toList(),
        'shareId': shareId,
        if (bgTheme != null) 'bgTheme': bgTheme,
        if (bgImage != null) 'bgImage': bgImage,
      };

  factory Event.fromJson(Map<String, dynamic> j) => Event(
        id: j['id'] as String,
        title: j['title'] as String,
        date: DateTime.parse(j['date'] as String),
        place: j['place'] as String? ?? '',
        lat: (j['lat'] as num?)?.toDouble(),
        lng: (j['lng'] as num?)?.toDouble(),
        invited: List<String>.from(j['invited'] as List? ?? []),
        repeat: Repeat.values.asNameMap()[j['repeat']] ?? Repeat.none,
        expenses: [for (final x in j['expenses'] as List? ?? []) Expense.fromJson(x as Map<String, dynamic>)],
        shareId: j['shareId'] as String?,
        bgTheme: j['bgTheme'] as String?,
        bgImage: j['bgImage'] as String?,
      );
}

/// Program ismétlődése.
enum Repeat {
  none('Nem ismétlődik'),
  weekly('Hetente'),
  biweekly('Kéthetente'),
  monthly('Havonta');

  const Repeat(this.label);

  final String label;
}

/// Egy kiadás a programon: ki fizette, mennyit, és kik között oszlik meg.
class Expense {
  Expense({required this.id, required this.title, required this.amount, required this.payer, required this.shares});

  final String id;
  String title;

  /// Forintban.
  int amount;
  String payer;

  /// Akik között egyenlően oszlik meg (a fizető is lehet köztük).
  List<String> shares;

  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'amount': amount, 'payer': payer, 'shares': shares};

  factory Expense.fromJson(Map<String, dynamic> j) => Expense(
        id: j['id'] as String,
        title: j['title'] as String? ?? '',
        amount: j['amount'] as int,
        payer: j['payer'] as String,
        shares: List<String>.from(j['shares'] as List? ?? []),
      );
}

/// Napi cél, a teljesített napok kulcsaival.
///
/// Lehet heti cél („hetente 3×”) és mennyiségi („8 pohár víz”) is; a [doneDays] mindig azokat
/// a napokat tartalmazza, amikor az aznapi adag megvolt, így a sorozat, a statisztika és a
/// widget ugyanúgy működik minden fajtánál.
class Habit {
  Habit({
    required this.id,
    required this.name,
    Set<String>? doneDays,
    this.perWeek,
    this.target = 1,
    this.unit = '',
    Map<String, int>? counts,
    this.reminderMinutes,
  })  : doneDays = doneDays ?? {},
        counts = counts ?? {};

  final String id;
  String name;
  Set<String> doneDays;

  /// Heti cél (pl. 3 = hetente háromszor); null = minden nap.
  int? perWeek;

  /// Napi mennyiség (pl. 8 pohár); 1 = egyszerű kipipálás.
  int target;

  /// A mennyiség egysége (pl. „pohár”), csak kiíráshoz.
  String unit;

  /// Mennyiségi célnál napi számláló (napkulcs → darab).
  Map<String, int> counts;

  /// Saját emlékeztető ideje percben (pl. 8:30 = 510); null = nincs.
  int? reminderMinutes;

  bool get isWeekly => perWeek != null;
  bool get isCounted => target > 1;

  bool isDoneOn(DateTime d) => doneDays.contains(dayKey(d));

  int countOn(DateTime d) => isCounted ? counts[dayKey(d)] ?? 0 : (isDoneOn(d) ? 1 : 0);

  /// Egy nap hozzáadása a mennyiséghez (a célnál megáll); eléréskor a nap késznek számít.
  void addOne(DateTime d) {
    final key = dayKey(d);
    final n = (counts[key] ?? 0) + 1;
    counts[key] = n > target ? target : n;
    if (counts[key]! >= target) doneDays.add(key);
  }

  void removeOne(DateTime d) {
    final key = dayKey(d);
    final n = (counts[key] ?? 0) - 1;
    n <= 0 ? counts.remove(key) : counts[key] = n;
    if (n < target) doneDays.remove(key);
  }

  /// A hét (hétfőtől) napjai, amelyiken teljesült.
  int doneInWeek(DateTime d) {
    final monday = addDays(d, 1 - d.weekday);
    return [for (var i = 0; i < 7; i++) addDays(monday, i)].where(isDoneOn).length;
  }

  /// Ma „rendben van”-e: napi célnál ha kész, hetinél ha kész vagy a heti cél már megvan.
  bool isSatisfiedOn(DateTime d) => isDoneOn(d) || (isWeekly && doneInWeek(d) >= perWeek!);

  /// Hány egymást követő napja teljesül (hetinél: hány egymást követő héten volt meg a cél).
  /// Ha ma (ezen a héten) még nincs kész, az előzőtől számol, így reggel nem nullázódik le.
  int streak([DateTime? now]) {
    var day = now ?? DateTime.now();
    if (isWeekly) {
      if (doneInWeek(day) < perWeek!) day = addDays(day, -7);
      var weeks = 0;
      while (doneInWeek(day) >= perWeek!) {
        weeks++;
        day = addDays(day, -7);
      }
      return weeks;
    }
    if (!isDoneOn(day)) day = addDays(day, -1);
    var count = 0;
    while (isDoneOn(day)) {
      count++;
      day = addDays(day, -1);
    }
    return count;
  }

  /// A sorozat mértékegysége kiíráshoz.
  String get streakUnit => isWeekly ? 'hét' : 'nap';

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'doneDays': doneDays.toList(),
        if (perWeek != null) 'perWeek': perWeek,
        if (target != 1) 'target': target,
        if (unit.isNotEmpty) 'unit': unit,
        if (counts.isNotEmpty) 'counts': counts,
        if (reminderMinutes != null) 'reminderMinutes': reminderMinutes,
      };

  factory Habit.fromJson(Map<String, dynamic> j) => Habit(
        id: j['id'] as String,
        name: j['name'] as String,
        doneDays: Set<String>.from(j['doneDays'] as List? ?? []),
        perWeek: (j['perWeek'] as num?)?.toInt(),
        target: (j['target'] as num?)?.toInt() ?? 1,
        unit: j['unit'] as String? ?? '',
        counts: {for (final e in (j['counts'] as Map? ?? {}).entries) e.key as String: (e.value as num).toInt()},
        reminderMinutes: (j['reminderMinutes'] as num?)?.toInt(),
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
    this.moodImage,
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

  /// Saját kép a nap hangulatához (base64, kicsi négyzet), pl. egy szelfi.
  /// Ha van, ez látszik a hangulatarc helyett ennél a napnál.
  String? moodImage;

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
        'moodImage': moodImage,
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
        moodImage: j['moodImage'] as String?,
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

/// Az [mood] (1–5) hangulat alapértelmezett arca és felirata.
MoodTag defaultMoodFace(int mood) => MoodTag(id: 'mood$mood', name: moodLabels[mood - 1], emoji: moodEmojis[mood - 1]);

const moodEmojis = ['😞', '🙁', '😐', '🙂', '😄'];
const moodLabels = ['Nagyon rossz', 'Rossz', 'Átlagos', 'Jó', 'Nagyon jó'];

/// Egy program, ahová valaki más hívott meg (a meghívólinkből), hogy később is megtaláld.
class Invite {
  const Invite({required this.id, required this.title, required this.date});

  final String id;
  final String title;
  final DateTime date;

  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'date': date.toIso8601String()};

  factory Invite.fromJson(Map<String, dynamic> j) =>
      Invite(id: j['id'] as String, title: j['title'] as String? ?? '', date: DateTime.parse(j['date'] as String));
}

/// Gyors hangulat napközben („Hogy vagy most?”), időponttal.
class CheckIn {
  const CheckIn({required this.at, required this.mood});

  final DateTime at;

  /// 1–5, mint a napi hangulat.
  final int mood;

  Map<String, dynamic> toJson() => {'at': at.toIso8601String(), 'mood': mood};

  factory CheckIn.fromJson(Map<String, dynamic> j) =>
      CheckIn(at: DateTime.parse(j['at'] as String), mood: (j['mood'] as num).toInt());
}

/// Napszak egy időpontból (a hangulat napszakos statisztikájához).
String partOfDay(DateTime t) => switch (t.hour) {
      >= 5 && < 10 => 'reggel',
      >= 10 && < 12 => 'délelőtt',
      >= 12 && < 17 => 'délután',
      >= 17 && < 22 => 'este',
      _ => 'éjjel',
    };

const partsOfDay = ['reggel', 'délelőtt', 'délután', 'este', 'éjjel'];
