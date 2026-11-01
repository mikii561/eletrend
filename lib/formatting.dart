/// Dátumok, időtartamok és ismétlődések kiírása (magyarul vagy angolul, a [L10n.lang] szerint).
library;

import 'l10n/l10n.dart';

import 'package:intl/intl.dart';

import 'models.dart';

// A formátumok nyelvfüggők (a minta is: pl. „november 3.” vs. „November 3”), ezért függvényekből jönnek.
DateFormat get _time => DateFormat('HH:mm', L10n.code);
DateFormat get _dayLong => DateFormat(tr('MMMM d., EEEE'), L10n.code);
DateFormat get _dayShort => DateFormat(tr('MMM d., EEE'), L10n.code);

String formatTime(DateTime t) => _time.format(t);

/// „ma”, „holnap”, „tegnap”, vagy pl. „november 3., hétfő”.
String formatDay(DateTime d, {DateTime? now, bool short = false}) {
  final today = startOfDay(now ?? DateTime.now());
  final diff = startOfDay(d).difference(today).inDays;
  if (diff == 0) return tr('Ma');
  if (diff == 1) return tr('Holnap');
  if (diff == -1) return tr('Tegnap');
  return short ? _dayShort.format(d) : _dayLong.format(d);
}

/// Egy alkalom ideje, pl. „18:00–20:00”, „Egész nap”, vagy több napnál „okt. 3. – okt. 5.”.
String formatRange(DateTime start, DateTime end, {bool allDay = false}) {
  if (allDay) {
    final last = end.subtract(const Duration(minutes: 1));
    return sameDay(start, last) ? tr('Egész nap') : '${_dayShort.format(start)} – ${_dayShort.format(last)}';
  }
  if (sameDay(start, end) || (end.hour == 0 && end.minute == 0 && end.difference(start).inHours < 24)) {
    return '${formatTime(start)}–${formatTime(end)}';
  }
  return '${_dayShort.format(start)} ${formatTime(start)} – ${_dayShort.format(end)} ${formatTime(end)}';
}

/// Időtartam, pl. „45 perc”, „2 óra”, „1 óra 30 perc”.
String formatDuration(int minutes) {
  if (minutes < 60) return trf('{0} perc', [minutes]);
  final h = minutes ~/ 60, m = minutes % 60;
  return m == 0 ? trf('{0} óra', [h]) : trf('{0} óra {1} perc', [h, m]);
}

/// „minden csütörtökön” alakhoz: hétfőnként, keddenként…
String weekdayEvery(int weekday) => [
  tr('hétfőnként'),
  tr('keddenként'),
  tr('szerdánként'),
  tr('csütörtökönként'),
  tr('péntekenként'),
  tr('szombatonként'),
  tr('vasárnaponként'),
][weekday - 1];

/// Az ismétlődés olvasható leírása, pl. „Hetente, csütörtökönként”.
String repeatLabel(Repeat repeat, DateTime start) => switch (repeat) {
  Repeat.none => '',
  Repeat.daily => tr('Minden nap'),
  Repeat.weekly => trf('Hetente, {0}', [weekdayEvery(start.weekday)]),
  Repeat.biweekly => trf('Kéthetente, {0}', [weekdayEvery(start.weekday)]),
  Repeat.monthly => trf('Havonta, minden hónap {0}. napján', [start.day]),
  Repeat.yearly => trf('Évente, {0}', [DateFormat(tr('MMMM d.'), L10n.code).format(start)]),
};

/// Emlékeztető lehetőségek (perc előtte; null = nincs).
const reminderOptions = <int?>[null, 0, 10, 30, 60, 120, 1440];

String reminderLabel(int? minutes) => switch (minutes) {
  null => tr('Nincs értesítés'),
  0 => tr('Amikor kezdődik'),
  10 => tr('10 perccel előtte'),
  30 => tr('30 perccel előtte'),
  60 => tr('1 órával előtte'),
  120 => tr('2 órával előtte'),
  1440 => tr('1 nappal előtte'),
  _ => trf('{0} perccel előtte', [minutes]),
};
