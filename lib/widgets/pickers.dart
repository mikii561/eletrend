import '../l10n/l10n.dart';

import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/material.dart' hide Text;

import '../l10n/text.dart';

import 'package:intl/intl.dart';

import '../theme.dart';

/// Időpont választása görgethető kerekekkel (óra : perc, 24 órás), egy alulról felcsúszó lapon.
/// Egyszerűbb és gyorsabb, mint az órás tárcsa: nem kell pontosan rákoppintani, elég a számokat görgetni.
Future<TimeOfDay?> pickTime(BuildContext context, {required TimeOfDay initial, String title = 'Időpont'}) async {
  final picked = await showModalBottomSheet<DateTime>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _WheelSheet(
      title: title,
      initial: DateTime(2000, 1, 1, initial.hour, initial.minute),
      mode: CupertinoDatePickerMode.time,
      preview: (d) => DateFormat.Hm(L10n.code).format(d),
    ),
  );
  return picked == null ? null : TimeOfDay(hour: picked.hour, minute: picked.minute);
}

/// Dátum választása görgethető kerekekkel: év, hónap, nap. Születésnaphoz is jó: nem kell semmit beírni,
/// és nem számít, hogyan szokta valaki leírni (pont, kötőjel…).
Future<DateTime?> pickDay(
  BuildContext context, {
  required DateTime initial,
  required DateTime first,
  required DateTime last,
  String title = 'Dátum',
}) {
  return showModalBottomSheet<DateTime>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _WheelSheet(
      title: title,
      initial: initial.isBefore(first) ? first : (initial.isAfter(last) ? last : initial),
      mode: CupertinoDatePickerMode.date,
      min: first,
      max: last,
      preview: (d) => DateFormat(tr('yyyy. MMMM d.'), L10n.code).format(d),
    ),
  );
}

/// Születésnap: az év is, de induláskor egy tipikus évnél áll a kerék, hogy ne kelljen messzire görgetni.
Future<DateTime?> pickBirthday(BuildContext context, {DateTime? initial}) => pickDay(
  context,
  initial: initial ?? DateTime(2000, 1, 1),
  first: DateTime(1920),
  last: DateTime.now(),
  title: tr('Mikor van a születésnapod?'),
);

class _WheelSheet extends StatefulWidget {
  const _WheelSheet({
    required this.title,
    required this.initial,
    required this.mode,
    required this.preview,
    this.min,
    this.max,
  });

  final String title;
  final DateTime initial;
  final CupertinoDatePickerMode mode;
  final DateTime? min;
  final DateTime? max;
  final String Function(DateTime value) preview;

  @override
  State<_WheelSheet> createState() => _WheelSheetState();
}

class _WheelSheetState extends State<_WheelSheet> {
  late DateTime _value = widget.initial;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.title,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              widget.preview(_value),
              key: const Key('pickerPreview'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            SizedBox(
              height: 190,
              child: CupertinoTheme(
                data: CupertinoThemeData(
                  brightness: dark ? Brightness.dark : Brightness.light,
                  primaryColor: AppColors.primary,
                  textTheme: CupertinoTextThemeData(
                    dateTimePickerTextStyle: TextStyle(color: AppColors.text, fontSize: 22),
                  ),
                ),
                child: CupertinoDatePicker(
                  mode: widget.mode,
                  initialDateTime: _value,
                  minimumDate: widget.min,
                  maximumDate: widget.max,
                  use24hFormat: true,
                  dateOrder: DatePickerDateOrder.ymd,
                  onDateTimeChanged: (v) => setState(() => _value = v),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Mégse'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(onPressed: () => Navigator.pop(context, _value), child: const Text('Kész')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
