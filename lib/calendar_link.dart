import 'models.dart';

String _utc(DateTime d) {
  final u = d.toUtc();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${u.year}${two(u.month)}${two(u.day)}T${two(u.hour)}${two(u.minute)}00Z';
}

/// Google Naptár „új esemény” link a program adataival (alapból 2 órás, ismétlődéssel együtt).
/// Telefonon a Naptár app nyílik meg, gépen a böngészőben a Google Naptár.
Uri googleCalendarLink({
  required String title,
  required DateTime start,
  String place = '',
  String details = '',
  Repeat repeat = Repeat.none,
  Duration length = const Duration(hours: 2),
}) {
  final rule = switch (repeat) {
    Repeat.none => null,
    Repeat.weekly => 'RRULE:FREQ=WEEKLY',
    Repeat.biweekly => 'RRULE:FREQ=WEEKLY;INTERVAL=2',
    Repeat.monthly => 'RRULE:FREQ=MONTHLY',
  };
  return Uri.https('calendar.google.com', '/calendar/render', {
    'action': 'TEMPLATE',
    'text': title,
    'dates': '${_utc(start)}/${_utc(start.add(length))}',
    if (place.isNotEmpty) 'location': place,
    if (details.isNotEmpty) 'details': details,
    'recur': ?rule,
  });
}
