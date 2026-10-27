import 'package:eletrend/main.dart';
import 'package:eletrend/models.dart';
import 'package:eletrend/screens/today_screen.dart';
import 'package:eletrend/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() => initializeDateFormatting('hu'));

  test('sorozat számolása tegnaptól, ha ma még nincs kész', () {
    final now = DateTime(2026, 10, 27);
    final h = Habit(id: '1', name: 'Víz', doneDays: {'2026-10-25', '2026-10-26'});
    expect(h.streak(now), 2);
    h.doneDays.add('2026-10-27');
    expect(h.streak(now), 3);
  });

  test('emlékeztető beállítások megmaradnak újraindítás után', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await AppStore.load();
    expect(store.dailyReminder, isTrue);
    expect(store.reminderTime, const TimeOfDay(hour: 20, minute: 0));

    store.setReminders(daily: false, time: const TimeOfDay(hour: 21, minute: 30), events: false);
    final reloaded = await AppStore.load();
    expect(reloaded.dailyReminder, isFalse);
    expect(reloaded.reminderTime, const TimeOfDay(hour: 21, minute: 30));
    expect(reloaded.eventReminders, isFalse);
  });

  testWidgets('a főoldal betölt és a szokás kipipálható', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = await AppStore.load();
    store.addHabit('Olvasás');

    await tester.pumpWidget(EletrendApp(store: store));
    expect(find.text('Mai szokások'), findsOneWidget);
    expect(find.text('Olvasás'), findsOneWidget);

    await tester.ensureVisible(find.byType(CheckCircle));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CheckCircle));
    await tester.pump();
    expect(store.habits.first.isDoneOn(DateTime.now()), isTrue);

    // Gyors hangulat a főoldalon
    await tester.ensureVisible(find.text(moodEmojis[3]));
    await tester.pumpAndSettle();
    await tester.tap(find.text(moodEmojis[3]));
    await tester.pump();
    expect(store.entryFor(DateTime.now())?.mood, 4);

    await tester.tap(find.text('Napló'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Bejegyzések'), findsOneWidget);
  });
}
