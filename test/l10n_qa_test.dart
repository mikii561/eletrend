import 'dart:io';

import 'package:eletrend/l10n/l10n.dart';
import 'package:eletrend/main.dart';
import 'package:eletrend/models.dart';
import 'package:eletrend/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';
import 'widget_test.dart' show phone, stopServices;

final _accents = RegExp('[áéíóöőúüűÁÉÍÓÖŐÚÜŰ]');

/// Minden látható szöveg (Text, tooltip, beviteli mezők címkéi) az éppen megjelenő képernyőn.
Set<String> visibleTexts(WidgetTester tester) {
  final out = <String>{};
  for (final w in tester.widgetList<Text>(find.byType(Text))) {
    final s = w.data ?? w.textSpan?.toPlainText();
    if (s != null && s.trim().isNotEmpty) out.add(s);
  }
  for (final w in tester.widgetList<Tooltip>(find.byType(Tooltip))) {
    if (w.message != null) out.add(w.message!);
  }
  for (final w in tester.widgetList<TextField>(find.byType(TextField))) {
    final d = w.decoration;
    for (final s in [d?.labelText, d?.hintText, d?.helperText, d?.errorText]) {
      if (s != null) out.add(s);
    }
  }
  return out;
}

void main() {
  setUp(signInFakeAccount);

  testWidgets('angol módban a fő képernyők szövegei le vannak fordítva (nincs magyar ékezetes szöveg)', (tester) async {
    phone(tester);
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});
    final store = (await tester.runAsync(AppStore.load))!;
    final now = DateTime.now();
    DateTime at(int day, int hour, [int minute = 0]) => DateTime(now.year, now.month, now.day + day, hour, minute);
    store
      ..finishOnboarding(name: 'Gabi')
      ..setTourDone(false)
      ..setLanguage(AppLanguage.en)
      ..saveEvent(Event(id: 'a', title: 'Team meeting', start: at(0, 9, 30), durationMin: 60, category: EventCategory.work))
      ..saveEvent(Event(id: 'b', title: 'Workout', start: at(0, 17), durationMin: 90, place: 'Gym', category: EventCategory.health))
      ..saveEvent(Event(id: 'c', title: 'Pizza night', start: at(1, 20), durationMin: 120, repeat: Repeat.weekly))
      ..saveTask(TaskItem(id: 't1', title: 'Pay the bill', due: at(0, 12)))
      ..saveTask(TaskItem(id: 't2', title: 'Old task', due: at(-3, 12)))
      ..saveTask(TaskItem(id: 't3', title: 'Write report', scheduled: at(0, 14), durationMin: 90));
    store.addHabit('Water', target: 8, unit: 'glass');
    store.addHabit('Run', perWeek: 3);

    final report = <String, Set<String>>{};
    Future<void> dump(String name, {bool settle = true}) async {
      if (settle) {
        await tester.pumpAndSettle();
      } else {
        await tester.pump(const Duration(milliseconds: 300));
      }
      report[name] = visibleTexts(tester);
    }

    await tester.pumpWidget(LifeupApp(store: store));
    await tester.pumpAndSettle();

    // Bemutató: minden lépés.
    for (var i = 0; i < 10; i++) {
      await dump('tour $i', settle: false);
      final next = find.widgetWithText(FilledButton, 'Next');
      if (next.evaluate().isEmpty) break;
      await tester.tap(next);
      for (var f = 0; f < 4; f++) {
        await tester.pump(const Duration(milliseconds: 300));
      }
    }
    final start = find.widgetWithText(FilledButton, 'Let us start!');
    if (start.evaluate().isNotEmpty) await tester.tap(start);
    await tester.pumpAndSettle();
    store.setTourDone(true);
    await tester.pumpAndSettle();

    await dump('home');
    await tester.drag(find.byType(ListView).first, const Offset(0, -700));
    await dump('home 2');
    await tester.drag(find.byType(ListView).first, const Offset(0, -700));
    await dump('home 3');

    // Elmaradt teendők
    if (find.text('Yes').evaluate().isNotEmpty) {
      await tester.drag(find.byType(ListView).first, const Offset(0, 2000));
      await tester.pumpAndSettle();
    }

    Future<void> nav(String tab) async {
      await tester.tap(find.text(tab).last);
      await tester.pumpAndSettle();
    }

    await nav('Calendar');
    for (final v in ['Day', 'Week', 'Month', 'List']) {
      if (find.text(v).evaluate().isNotEmpty) {
        await tester.tap(find.text(v));
        await dump('calendar $v');
      }
    }
    await nav('Friends');
    await dump('friends');
    await nav('Profile');
    await dump('profile');

    final report2 = StringBuffer();
    final bad = <String>[];
    report.forEach((screen, texts) {
      report2.writeln('== $screen');
      for (final t in texts.toList()..sort()) {
        report2.writeln('  $t');
        if (_accents.hasMatch(t.replaceAll('Balatonfüred', ''))) bad.add('$screen: $t');
      }
    });
    final path = Platform.environment['ELETREND_QA'];
    if (path != null) File(path).writeAsStringSync(report2.toString());
    if (L10n.missing.isNotEmpty) bad.add('hiányzó fordítás: ${L10n.missing.toList()}');
    expect(bad, isEmpty);
    stopServices();
  });
}
