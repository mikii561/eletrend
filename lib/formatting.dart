/// Dátumok, időtartamok és ismétlődések magyar kiírása.
library;

import 'package:intl/intl.dart';

import 'models.dart';

final _time = DateFormat('HH:mm', 'hu');
final _dayLong = DateFormat('MMMM d., EEEE', 'hu');
final _dayShort = DateFormat('MMM d., EEE', 'hu');

String formatTime(DateTime t) => _time.format(t);

/// „ma”, „holnap”, „tegnap”, vagy pl. „november 3., hétfő”.
String formatDay(DateTime d, {DateTime? now, bool short = false}) {
  final today = startOfDay(now ?? DateTime.now());
  final diff = startOfDay(d).difference(today).inDays;
  if (diff == 0) return 'Ma';
  if (diff == 1) return 'Holnap';
  if (diff == -1) return 'Tegnap';
  return short ? _dayShort.format(d) : _dayLong.format(d);
}

/// Egy alkalom ideje, pl. „18:00–20:00”, „Egész nap”, vagy több napnál „okt. 3. – okt. 5.”.
String formatRange(DateTime start, DateTime end, {bool allDay = false}) {
  if (allDay) {
    final last = end.subtract(const Duration(minutes: 1));
    return sameDay(start, last) ? 'Egész nap' : '${_dayShort.format(start)} – ${_dayShort.format(last)}';
  }
  if (sameDay(start, end) || (end.hour == 0 && end.minute == 0 && end.difference(start).inHours < 24)) {
    return '${formatTime(start)}–${formatTime(end)}';
  }
  return '${_dayShort.format(start)} ${formatTime(start)} – ${_dayShort.format(end)} ${formatTime(end)}';
}

/// Időtartam, pl. „45 perc”, „2 óra”, „1 óra 30 perc”.
String formatDuration(int minutes) {
  if (minutes < 60) return '$minutes perc';
  final h = minutes ~/ 60, m = minutes % 60;
  return m == 0 ? '$h óra' : '$h óra $m perc';
}

/// „minden csütörtökön” alakhoz: hétfőnként, keddenként…
String weekdayEvery(int weekday) => const [
  'hétfőnként',
  'keddenként',
  'szerdánként',
  'csütörtökönként',
  'péntekenként',
  'szombatonként',
  'vasárnaponként',
][weekday - 1];

/// Az ismétlődés olvasható leírása, pl. „Hetente, csütörtökönként”.
String repeatLabel(Repeat repeat, DateTime start) => switch (repeat) {
  Repeat.none => '',
  Repeat.daily => 'Minden nap',
  Repeat.weekly => 'Hetente, ${weekdayEvery(start.weekday)}',
  Repeat.biweekly => 'Kéthetente, ${weekdayEvery(start.weekday)}',
  Repeat.monthly => 'Havonta, minden hónap ${start.day}. napján',
  Repeat.yearly => 'Évente, ${DateFormat('MMMM d.', 'hu').format(start)}',
};

/// Emlékeztető lehetőségek (perc előtte; null = nincs).
const reminderOptions = <int?>[null, 0, 10, 30, 60, 120, 1440];

String reminderLabel(int? minutes) => switch (minutes) {
  null => 'Nincs értesítés',
  0 => 'Amikor kezdődik',
  1440 => '1 nappal előtte',
  _ => '${formatDuration(minutes)}cel előtte'.replaceAll('óracel', 'órával'),
};
