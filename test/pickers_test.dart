import 'package:eletrend/widgets/pickers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

Future<void> _open(WidgetTester tester, Future<void> Function(BuildContext context) action) async {
  tester.view.physicalSize = const Size(400, 860);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(onPressed: () => action(context), child: const Text('Nyit')),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Nyit'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting('hu'));

  testWidgets('időválasztó: a kezdőidő látszik, Kész visszaadja, Mégse nem ad vissza semmit', (tester) async {
    TimeOfDay? result = const TimeOfDay(hour: 0, minute: 0);
    await _open(
      tester,
      (context) async => result = await pickTime(context, initial: const TimeOfDay(hour: 14, minute: 35)),
    );
    expect(find.text('14:35'), findsOneWidget);
    await tester.tap(find.text('Kész'));
    await tester.pumpAndSettle();
    expect(result, const TimeOfDay(hour: 14, minute: 35));

    await tester.tap(find.text('Nyit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mégse'));
    await tester.pumpAndSettle();
    expect(result, isNull);
  });

  testWidgets('időválasztó: görgetéssel állítható', (tester) async {
    TimeOfDay? result;
    await _open(
      tester,
      (context) async => result = await pickTime(context, initial: const TimeOfDay(hour: 9, minute: 0)),
    );
    // Az óra kerekét lejjebb húzzuk: kisebb óra lesz.
    await tester.drag(find.text('9').first, const Offset(0, 80));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kész'));
    await tester.pumpAndSettle();
    expect(result, isNotNull);
    expect(result!.hour, isNot(9));
    expect(result!.minute, 0);
  });

  testWidgets('születésnap: kerekekkel, beírás nélkül; az év is választható', (tester) async {
    DateTime? result;
    await _open(tester, (context) async => result = await pickBirthday(context, initial: DateTime(2002, 7, 8)));
    expect(find.text('2002. július 8.'), findsOneWidget);
    await tester.tap(find.text('Kész'));
    await tester.pumpAndSettle();
    expect(result, DateTime(2002, 7, 8));
  });
}
