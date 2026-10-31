/// Az app adatmodelljei: naptárbejegyzések, feladatok, célok, baráti csoportok.
library;

import 'dart:math';

/// Egy napot azonosító kulcs, pl. "2026-10-27".
String dayKey(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// [n] naptári nappal később (negatívval korábban), délben.
/// Nem 24 órákat ad hozzá, így az óraátállítás napján sem csúszik el.
DateTime addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n, 12);

/// A nap kezdete (éjfél, helyi idő).
DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

/// Ugyanaz a naptári nap-e.
bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

final _idRandom = Random();
var _idSeq = 0;

/// Egyedi azonosító. Az idő mellett sorszám és véletlen rész is van benne, mert egyes gépeken
/// az óra felbontása durva: két gyorsan egymás után (vagy két eszközön egyszerre) létrehozott
/// elem különben ugyanazt kaphatná, és a felhőben felülírnák egymást.
String newId() =>
    '${DateTime.now().microsecondsSinceEpoch}${(_idSeq++ % 1000).toString().padLeft(3, '0')}${_idRandom.nextInt(1000).toString().padLeft(3, '0')}';

/// Bejegyzések kategóriái; a színük és ikonjuk a theme.dart-ban van.
enum EventCategory {
  personal('Személyes'),
  work('Munka'),
  study('Tanulás'),
  social('Közösségi'),
  health('Egészség, sport'),
  important('Fontos'),
  shared('Közös');

  const EventCategory(this.label);

  final String label;
}

/// Ismétlődés; a kezdés ilyenkor az első alkalom.
enum Repeat {
  none('Nem ismétlődik'),
  daily('Naponta'),
  weekly('Hetente'),
  biweekly('Kéthetente'),
  monthly('Havonta'),
  yearly('Évente');

  const Repeat(this.label);

  final String label;
}

/// Egy naptárbejegyzés (saját vagy barátokkal közös).
class Event {
  Event({
    required this.id,
    required this.title,
    required this.start,
    this.durationMin = 60,
    this.allDay = false,
    this.category = EventCategory.personal,
    this.color,
    this.place = '',
    this.lat,
    this.lng,
    this.notes = '',
    this.repeat = Repeat.none,
    this.reminderMin = 30,
    this.busy = true,
    this.shareId,
    this.limit,
    this.inviteOnly = false,
    this.source,
    this.externalId,
    Set<String>? skipped,
  }) : skipped = skipped ?? {};

  final String id;
  String title;

  /// Az (első) alkalom kezdete, helyi idő. Egész napos bejegyzésnél éjfél.
  DateTime start;

  /// Hossz percben; egész naposnál a napok száma × 1440.
  int durationMin;
  bool allDay;
  EventCategory category;

  /// Saját szín (ARGB); null = a kategória színe.
  int? color;
  String place;

  /// A helyszín koordinátái, ha térképen lett kiválasztva.
  double? lat;
  double? lng;
  String notes;
  Repeat repeat;

  /// Emlékeztető ennyi perccel előtte; null = nincs.
  int? reminderMin;

  /// Foglaltnak számít-e (a barátok ezt látják, a részleteket soha).
  bool busy;

  /// A felhőbe kitett közös példány azonosítója, ha megosztottad (a meghívólinkben is ez van).
  String? shareId;

  /// Közös programnál a létszámkorlát (null = nincs).
  int? limit;

  /// Közös programnál: csak a meghívottak láthatják (a link önmagában nem elég).
  bool inviteOnly;

  /// Honnan jött, ha nem itt hozták létre: 'google:{naptár azonosító}'. Null = saját.
  String? source;

  /// Az eredeti azonosító a másik naptárban (frissítéskor ez alapján cseréljük).
  String? externalId;

  /// Ismétlődő bejegyzés kihagyott alkalmai (napkulcsok), pl. „csak ezt törlöm”.
  Set<String> skipped;

  bool get hasLocation => lat != null && lng != null;
  bool get isShared => shareId != null;

  /// Más naptárból jött (pl. Google Naptár), itt csak olvasható.
  bool get isExternal => source != null;
  Duration get duration => Duration(minutes: durationMin);

  /// Az [i]-edik alkalom kezdete (0 = az első). Naptári napokkal számol, így
  /// óraátállításkor sem csúszik el az időpont.
  DateTime occurrence(int i) {
    final s = start;
    return switch (repeat) {
      Repeat.none => s,
      Repeat.daily => DateTime(s.year, s.month, s.day + i, s.hour, s.minute),
      Repeat.weekly => DateTime(s.year, s.month, s.day + 7 * i, s.hour, s.minute),
      Repeat.biweekly => DateTime(s.year, s.month, s.day + 14 * i, s.hour, s.minute),
      Repeat.monthly => DateTime(
        s.year,
        s.month + i,
        min(s.day, DateTime(s.year, s.month + i + 1, 0).day),
        s.hour,
        s.minute,
      ),
      Repeat.yearly => DateTime(
        s.year + i,
        s.month,
        min(s.day, DateTime(s.year + i, s.month + 1, 0).day),
        s.hour,
        s.minute,
      ),
    };
  }

  /// Hányadik alkalomtól érdemes keresni, hogy [from]-ig ne kelljen az elejétől számolni.
  int _firstIndexNear(DateTime from) {
    final days = startOfDay(from).difference(startOfDay(start)).inDays - (durationMin ~/ 1440) - 1;
    if (days <= 0) return 0;
    return switch (repeat) {
      Repeat.none => 0,
      Repeat.daily => days,
      Repeat.weekly => days ~/ 7,
      Repeat.biweekly => days ~/ 14,
      Repeat.monthly => max(0, days ~/ 31 - 1),
      Repeat.yearly => max(0, days ~/ 366 - 1),
    };
  }

  /// Az alkalmak, amelyek belelógnak a [from, to) időszakba (a kihagyottak nélkül).
  List<Occurrence> occurrencesBetween(DateTime from, DateTime to) {
    final result = <Occurrence>[];
    for (var i = _firstIndexNear(from); ; i++) {
      final s = occurrence(i);
      if (!s.isBefore(to)) break;
      final e = s.add(duration);
      if (e.isAfter(from) && !skipped.contains(dayKey(s))) result.add(Occurrence(this, s, e));
      if (repeat == Repeat.none) break;
    }
    return result;
  }

  /// A következő (még nem véget ért) alkalom; null, ha már nincs.
  Occurrence? nextOccurrence([DateTime? now]) {
    final t = now ?? DateTime.now();
    final list = occurrencesBetween(t, t.add(const Duration(days: 400)));
    return list.isEmpty ? null : list.first;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'date': start.toIso8601String(),
    'durationMin': durationMin,
    if (allDay) 'allDay': true,
    'category': category.name,
    if (color != null) 'color': color,
    'place': place,
    'lat': lat,
    'lng': lng,
    if (notes.isNotEmpty) 'notes': notes,
    'repeat': repeat.name,
    'reminderMin': reminderMin,
    if (!busy) 'busy': false,
    'shareId': shareId,
    if (limit != null) 'limit': limit,
    if (inviteOnly) 'inviteOnly': true,
    if (source != null) 'source': source,
    if (externalId != null) 'externalId': externalId,
    if (skipped.isNotEmpty) 'skipped': skipped.toList()..sort(),
  };

  /// A régi (Életrend) programok is beolvashatók: azok közösségi, kétórás programok voltak.
  factory Event.fromJson(Map<String, dynamic> j) => Event(
    id: j['id'] as String,
    title: j['title'] as String? ?? '',
    start: DateTime.parse(j['date'] as String),
    durationMin: (j['durationMin'] as num?)?.toInt() ?? 120,
    allDay: j['allDay'] as bool? ?? false,
    category: EventCategory.values.asNameMap()[j['category']] ?? EventCategory.social,
    color: (j['color'] as num?)?.toInt(),
    place: j['place'] as String? ?? '',
    lat: (j['lat'] as num?)?.toDouble(),
    lng: (j['lng'] as num?)?.toDouble(),
    notes: j['notes'] as String? ?? '',
    repeat: Repeat.values.asNameMap()[j['repeat']] ?? Repeat.none,
    reminderMin: j.containsKey('reminderMin') ? (j['reminderMin'] as num?)?.toInt() : 60,
    busy: j['busy'] as bool? ?? true,
    shareId: j['shareId'] as String?,
    limit: (j['limit'] as num?)?.toInt(),
    inviteOnly: j['inviteOnly'] as bool? ?? false,
    source: j['source'] as String?,
    externalId: j['externalId'] as String?,
    skipped: {for (final s in j['skipped'] as List? ?? []) s as String},
  );
}

/// Egy bejegyzés egy konkrét alkalma (ismétlődőnél mindegyik külön).
class Occurrence {
  const Occurrence(this.event, this.start, this.end);

  final Event event;
  final DateTime start;
  final DateTime end;
}

/// Feladat: lehet határideje, és beosztható a naptárba (időblokk).
class TaskItem {
  TaskItem({
    required this.id,
    required this.title,
    this.due,
    this.scheduled,
    this.durationMin = 30,
    this.category = EventCategory.personal,
    this.notes = '',
    this.done = false,
    this.reminderMin = 0,
    this.doneAt,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  String title;

  /// Határidő napja (null = nincs).
  DateTime? due;

  /// Időblokk a naptárban: mikor dolgozol rajta (null = nincs beosztva).
  DateTime? scheduled;
  int durationMin;
  EventCategory category;
  String notes;
  bool done;

  /// Értesítés: beosztott feladatnál ennyi perccel a kezdés előtt; csak határidősnél a határidő
  /// napján reggel 9-kor (bármilyen nem null érték). Null = nincs értesítés (a Főoldalon így is látszik).
  int? reminderMin;
  DateTime? doneAt;
  final DateTime createdAt;

  /// Melyik napra esik: a beosztás, különben a határidő napja.
  DateTime? get day => scheduled ?? due;

  bool isOverdue([DateTime? now]) {
    final d = due;
    return !done && d != null && startOfDay(d).isBefore(startOfDay(now ?? DateTime.now()));
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    if (due != null) 'due': dayKey(due!),
    if (scheduled != null) 'scheduled': scheduled!.toIso8601String(),
    'durationMin': durationMin,
    'category': category.name,
    if (notes.isNotEmpty) 'notes': notes,
    'done': done,
    'reminderMin': reminderMin,
    if (doneAt != null) 'doneAt': doneAt!.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
  };

  factory TaskItem.fromJson(Map<String, dynamic> j) => TaskItem(
    id: j['id'] as String,
    title: j['title'] as String? ?? '',
    due: j['due'] == null ? null : DateTime.parse('${j['due']}T12:00:00'),
    scheduled: j['scheduled'] == null ? null : DateTime.parse(j['scheduled'] as String),
    durationMin: (j['durationMin'] as num?)?.toInt() ?? 30,
    category: EventCategory.values.asNameMap()[j['category']] ?? EventCategory.personal,
    notes: j['notes'] as String? ?? '',
    done: j['done'] as bool? ?? false,
    // Régebbi feladatoknál (mező nélkül) maradt a korábbi viselkedés: emlékeztető a kezdéskor.
    reminderMin: j.containsKey('reminderMin') ? (j['reminderMin'] as num?)?.toInt() : 0,
    doneAt: j['doneAt'] == null ? null : DateTime.parse(j['doneAt'] as String),
    createdAt: j['createdAt'] == null ? null : DateTime.parse(j['createdAt'] as String),
  );
}

/// Saját baráti csoport (pl. „Foci csapat”): csak te látod, a meghívásnál és a közös
/// időpont keresésénél egy koppintással kiválasztható.
class FriendGroup {
  FriendGroup({required this.id, required this.name, List<String>? members}) : members = members ?? [];

  final String id;
  String name;

  /// A tagok azonosítói (uid).
  List<String> members;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'members': members};

  factory FriendGroup.fromJson(Map<String, dynamic> j) => FriendGroup(
    id: j['id'] as String,
    name: j['name'] as String? ?? '',
    members: List<String>.from(j['members'] as List? ?? []),
  );
}

/// Személyes cél, a teljesített napok kulcsaival.
///
/// Lehet heti cél („hetente 3×”) és mennyiségi („8 pohár víz”) is; a [doneDays] mindig azokat
/// a napokat tartalmazza, amikor az aznapi adag megvolt, így a sorozat és a statisztika
/// ugyanúgy működik minden fajtánál.
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
  }) : doneDays = doneDays ?? {},
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

  /// A valaha volt leghosszabb sorozat (napban, hetinél hétben).
  int longestStreak() {
    if (doneDays.isEmpty) return 0;
    final days = doneDays.map((k) => DateTime.parse('${k}T12:00:00')).toList()..sort();
    var best = 0;
    if (isWeekly) {
      // Hétfők, amelyik héten megvolt a cél; aztán az egymást követő hetek.
      final mondays = {
        for (final d in days) dayKey(addDays(d, 1 - d.weekday)),
      }.map((k) => DateTime.parse('${k}T12:00:00')).where((m) => doneInWeek(m) >= perWeek!).toList()..sort();
      DateTime? prev;
      var run = 0;
      for (final m in mondays) {
        run = prev != null && dayKey(addDays(prev, 7)) == dayKey(m) ? run + 1 : 1;
        if (run > best) best = run;
        prev = m;
      }
      return best;
    }
    DateTime? prev;
    var run = 0;
    for (final d in days) {
      run = prev != null && dayKey(addDays(prev, 1)) == dayKey(d) ? run + 1 : 1;
      if (run > best) best = run;
      prev = d;
    }
    return best;
  }

  /// Hány nap teljesült a [from]–[to] időszakban (mindkettő benne van).
  int doneBetween(DateTime from, DateTime to) {
    final a = dayKey(from), b = dayKey(to);
    return doneDays.where((k) => k.compareTo(a) >= 0 && k.compareTo(b) <= 0).length;
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

/// Egy közös program, ahová egy barátod meghívott (a meghívólinkből vagy a Meghívásaim közül).
class Invite {
  const Invite({required this.id, required this.title, required this.date, this.fromName = ''});

  final String id;
  final String title;
  final DateTime date;
  final String fromName;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'date': date.toIso8601String(),
    if (fromName.isNotEmpty) 'fromName': fromName,
  };

  factory Invite.fromJson(Map<String, dynamic> j) => Invite(
    id: j['id'] as String,
    title: j['title'] as String? ?? '',
    date: DateTime.parse(j['date'] as String),
    fromName: j['fromName'] as String? ?? '',
  );
}

/// Egy barát, ahogy az eszközön megjegyezzük (offline is látszik, és az emlékeztetőkhöz kell).
class FriendInfo {
  const FriendInfo({required this.uid, required this.name, this.birthday});

  final String uid;
  final String name;

  /// Születésnap „HH-NN” alakban, ha megosztja.
  final String? birthday;

  Map<String, dynamic> toJson() => {'uid': uid, 'name': name, if (birthday != null) 'birthday': birthday};

  factory FriendInfo.fromJson(Map<String, dynamic> j) =>
      FriendInfo(uid: j['uid'] as String, name: j['name'] as String? ?? '?', birthday: j['birthday'] as String?);

  /// A következő születésnapja [now]-tól (a mai is beleszámít); null, ha nem ismert.
  DateTime? nextBirthday([DateTime? now]) => nextBirthdayOf(birthday, now);
}

/// A „HH-NN” születésnap következő napja (február 29. nem szökőévben február 28.).
DateTime? nextBirthdayOf(String? mmdd, [DateTime? now]) {
  if (mmdd == null) return null;
  final m = RegExp(r'^(\d\d)-(\d\d)$').firstMatch(mmdd);
  if (m == null) return null;
  final month = int.parse(m.group(1)!), day = int.parse(m.group(2)!);
  final today = startOfDay(now ?? DateTime.now());
  DateTime on(int year) => DateTime(year, month, min(day, DateTime(year, month + 1, 0).day), 12);
  final thisYear = on(today.year);
  return thisYear.isBefore(today) ? on(today.year + 1) : thisYear;
}
