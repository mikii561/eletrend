/// Elérhetőség: állapot, „mikor szoktam ráérni” idősávok, és a közös időpont keresése.
///
/// Ez a fájl csak számol (nincs benne hálózat), így könnyen tesztelhető. A felhőbe írás és
/// olvasás az `availability_service.dart`-ban van.
library;

import 'dart:math';

import 'models.dart';

/// Az állapotom, amit a barátaim látnak.
enum AvailabilityStatus {
  available('Szabad'),
  busy('Elfoglalt'),
  open('Nyitott programra'),
  dnd('Ne zavarj');

  const AvailabilityStatus(this.label);

  final String label;
}

/// Kik láthatják az elérhetőségemet (csak szabad/foglalt, a bejegyzések részletei soha).
enum AvailabilityShare {
  nobody('Senki'),
  friends('Minden barátom'),
  groups('Csak a kiválasztott csoportjaim');

  const AvailabilityShare(this.label);

  final String label;
}

/// Egy idősáv, amikor általában ráérek, a hét megadott napjain (1 = hétfő … 7 = vasárnap).
class FreeWindow {
  const FreeWindow({required this.days, required this.fromMin, required this.toMin});

  final Set<int> days;

  /// Perc éjféltől (pl. 18:00 = 1080). A [toMin] lehet 1440 (éjfél).
  final int fromMin;
  final int toMin;

  Map<String, dynamic> toJson() => {'d': days.toList()..sort(), 'f': fromMin, 't': toMin};

  factory FreeWindow.fromJson(Map<String, dynamic> j) => FreeWindow(
    days: {for (final d in j['d'] as List? ?? []) (d as num).toInt()},
    fromMin: (j['f'] as num).toInt(),
    toMin: (j['t'] as num).toInt(),
  );

  @override
  bool operator ==(Object other) =>
      other is FreeWindow &&
      other.fromMin == fromMin &&
      other.toMin == toMin &&
      other.days.length == days.length &&
      other.days.containsAll(days);

  @override
  int get hashCode => Object.hash(fromMin, toMin, Object.hashAllUnordered(days));
}

/// Kész idősávok a bevezetőhöz és a beállításokhoz.
class FreeWindowPreset {
  const FreeWindowPreset(this.label, this.window);

  final String label;
  final FreeWindow window;
}

const freeWindowPresets = [
  FreeWindowPreset('Hétköznap este', FreeWindow(days: {1, 2, 3, 4, 5}, fromMin: 17 * 60, toMin: 22 * 60)),
  FreeWindowPreset('Hétköznap napközben', FreeWindow(days: {1, 2, 3, 4, 5}, fromMin: 9 * 60, toMin: 17 * 60)),
  FreeWindowPreset('Hétvégén napközben', FreeWindow(days: {6, 7}, fromMin: 10 * 60, toMin: 18 * 60)),
  FreeWindowPreset('Hétvégén este', FreeWindow(days: {6, 7}, fromMin: 18 * 60, toMin: 23 * 60)),
];

/// Ha valaki nem adta meg, mikor szokott ráérni, ezt feltételezzük (a foglalt idejét így is levonjuk).
const defaultWindow = FreeWindow(days: {1, 2, 3, 4, 5, 6, 7}, fromMin: 8 * 60, toMin: 23 * 60);

/// Egy időszak [start, end) – mindig UTC-ben, hogy az időzónák ne keveredjenek.
class TimeSpan {
  TimeSpan(DateTime start, DateTime end) : start = start.toUtc(), end = end.toUtc();

  final DateTime start;
  final DateTime end;

  Duration get length => end.difference(start);

  @override
  bool operator ==(Object other) => other is TimeSpan && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'TimeSpan($start – $end)';
}

/// Rendezett, egymásba nem lógó időszakok (az átfedők és az egymáshoz érők összevonva).
List<TimeSpan> mergeIntervals(Iterable<TimeSpan> input) {
  final list = input.where((i) => i.end.isAfter(i.start)).toList()..sort((a, b) => a.start.compareTo(b.start));
  final out = <TimeSpan>[];
  for (final i in list) {
    if (out.isNotEmpty && !i.start.isAfter(out.last.end)) {
      final last = out.removeLast();
      out.add(TimeSpan(last.start, i.end.isAfter(last.end) ? i.end : last.end));
    } else {
      out.add(i);
    }
  }
  return out;
}

/// [a] mínusz [b] (mindkettő rendezett, összevont lista).
List<TimeSpan> subtractIntervals(List<TimeSpan> a, List<TimeSpan> b) {
  final out = <TimeSpan>[];
  for (final x in a) {
    var cur = x.start;
    for (final y in b) {
      if (!y.end.isAfter(cur) || !y.start.isBefore(x.end)) continue;
      if (y.start.isAfter(cur)) out.add(TimeSpan(cur, y.start));
      if (y.end.isAfter(cur)) cur = y.end;
      if (!cur.isBefore(x.end)) break;
    }
    if (cur.isBefore(x.end)) out.add(TimeSpan(cur, x.end));
  }
  return out;
}

/// Két rendezett, összevont lista metszete.
List<TimeSpan> intersectIntervals(List<TimeSpan> a, List<TimeSpan> b) {
  final out = <TimeSpan>[];
  var i = 0, j = 0;
  while (i < a.length && j < b.length) {
    final s = a[i].start.isAfter(b[j].start) ? a[i].start : b[j].start;
    final e = a[i].end.isBefore(b[j].end) ? a[i].end : b[j].end;
    if (e.isAfter(s)) out.add(TimeSpan(s, e));
    a[i].end.isBefore(b[j].end) ? i++ : j++;
  }
  return out;
}

/// Az idősávok konkrét időpontjai a [from, to) időszakban, az illető saját időzónája szerint.
///
/// [utcOffsetMin]: az illető eltérése az UTC-től percben (pl. Budapest télen 60, nyáron 120).
List<TimeSpan> windowsToIntervals(List<FreeWindow> windows, DateTime from, DateTime to, int utcOffsetMin) {
  final offset = Duration(minutes: utcOffsetMin);
  // Az illető helyi naptári napjai, „UTC-be csomagolva”, hogy a gép időzónája ne számítson.
  final localFrom = from.toUtc().add(offset);
  final localTo = to.toUtc().add(offset);
  var day = DateTime.utc(localFrom.year, localFrom.month, localFrom.day);
  final out = <TimeSpan>[];
  while (day.isBefore(localTo)) {
    for (final w in windows) {
      if (!w.days.contains(day.weekday)) continue;
      final s = day.add(Duration(minutes: w.fromMin)).subtract(offset);
      final e = day.add(Duration(minutes: w.toMin)).subtract(offset);
      out.add(TimeSpan(s, e));
    }
    day = DateTime.utc(day.year, day.month, day.day + 1);
  }
  return intersectIntervals(mergeIntervals(out), [TimeSpan(from, to)]);
}

/// Egy résztvevő a közös időpont kereséséhez.
class Participant {
  const Participant({
    required this.uid,
    required this.name,
    required this.known,
    this.busy = const [],
    this.windows = const [],
    this.utcOffsetMin = 60,
  });

  /// Nem osztja meg az elérhetőségét: tőle nem tudjuk, ráér-e.
  const Participant.unknown({required this.uid, required this.name})
    : known = false,
      busy = const [],
      windows = const [],
      utcOffsetMin = 60;

  final String uid;
  final String name;

  /// Ismerjük-e az elérhetőségét.
  final bool known;
  final List<TimeSpan> busy;

  /// Mikor szokott ráérni; üres = nem adta meg (ilyenkor [defaultWindow]).
  final List<FreeWindow> windows;
  final int utcOffsetMin;

  /// Szabad időszakai a [from, to) között.
  List<TimeSpan> freeBetween(DateTime from, DateTime to) {
    final wins = windowsToIntervals(windows.isEmpty ? const [defaultWindow] : windows, from, to, utcOffsetMin);
    return subtractIntervals(wins, mergeIntervals(busy));
  }
}

/// Napszak-szűrő a közös időpont kereséséhez (a kereső helyi ideje szerint).
enum DayPart {
  any('Bármikor', 8 * 60, 23 * 60),
  daytime('Napközben', 8 * 60, 17 * 60),
  evening('Este', 17 * 60, 23 * 60);

  const DayPart(this.label, this.fromMin, this.toMin);

  final String label;
  final int fromMin;
  final int toMin;
}

/// Egy talált közös időszak.
class CommonSlot {
  const CommonSlot({required this.start, required this.end, required this.unknown});

  /// UTC; megjelenítéskor `toLocal()`.
  final DateTime start;
  final DateTime end;

  /// Akikről nem tudjuk, ráérnek-e (nem osztják meg az elérhetőségüket).
  final List<String> unknown;

  bool get confirmed => unknown.isEmpty;
  Duration get length => end.difference(start);
}

/// Közös szabad időszakok keresése.
///
/// - Az ismert elérhetőségű résztvevők szabad idejének metszete (a saját „ráérek” sávjaik,
///   mínusz a foglalt idejük), a kereső által választott napszakra szűkítve.
/// - Legalább [duration] hosszú időszakok, a kizárt napok ([excludedDays], napkulcsok a kereső
///   helyi ideje szerint) és a már elmúlt idő nélkül.
/// - Akiről nincs adat, azt nem hagyjuk ki, hanem minden találatnál jelezzük („nem tudjuk”).
List<CommonSlot> findCommonTime({
  required List<Participant> people,
  required DateTime from,
  required DateTime to,
  required Duration duration,
  DayPart part = DayPart.any,
  Set<String> excludedDays = const {},
  int viewerOffsetMin = 60,
  DateTime? now,
  int maxResults = 12,
}) {
  final earliest = (now ?? DateTime.now()).toUtc();
  final start = from.toUtc().isAfter(earliest) ? from.toUtc() : _roundUp(earliest);
  if (!to.toUtc().isAfter(start)) return const [];

  // A kereső napszakja, a kizárt napok nélkül.
  final allDays = {1, 2, 3, 4, 5, 6, 7};
  var common = windowsToIntervals(
    [FreeWindow(days: allDays, fromMin: part.fromMin, toMin: part.toMin)],
    start,
    to,
    viewerOffsetMin,
  ).where((i) => !excludedDays.contains(dayKey(i.start.add(Duration(minutes: viewerOffsetMin))))).toList();

  final unknown = <String>[];
  for (final p in people) {
    if (!p.known) {
      unknown.add(p.name);
      continue;
    }
    common = intersectIntervals(common, p.freeBetween(start, to));
    if (common.isEmpty) break;
  }

  final slots = [
    for (final i in common)
      if (i.length >= duration) CommonSlot(start: i.start, end: i.end, unknown: List.unmodifiable(unknown)),
  ];
  return slots.take(maxResults).toList();
}

/// A következő egész fél óra (hogy ne „17:43-tól” ajánljunk).
DateTime _roundUp(DateTime t) {
  final m = t.minute % 30 == 0 && t.second == 0 ? 0 : 30 - t.minute % 30;
  final r = DateTime.utc(t.year, t.month, t.day, t.hour, t.minute).add(Duration(minutes: m));
  return r;
}

/// A [busy] időszakokból a következő [days] nap foglalt blokkjai (összevonva, legfeljebb [maxBlocks]).
List<TimeSpan> busyBlocks(Iterable<TimeSpan> busy, {required DateTime from, int days = 28, int maxBlocks = 300}) {
  final to = from.add(Duration(days: days));
  final merged = intersectIntervals(mergeIntervals(busy), [TimeSpan(from, to)]);
  return merged.take(maxBlocks).toList();
}

/// Az eltérés az UTC-től percben az adott pillanatban, ezen az eszközön.
int localOffsetMin([DateTime? at]) => (at ?? DateTime.now()).timeZoneOffset.inMinutes;

/// Kerekítés nélküli segéd a tesztekhez.
int minutesBetween(DateTime a, DateTime b) => max(0, b.difference(a).inMinutes);
