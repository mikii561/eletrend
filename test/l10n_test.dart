import 'package:eletrend/availability.dart';
import 'package:eletrend/challenges.dart';
import 'package:eletrend/habit_templates.dart';
import 'package:eletrend/l10n/l10n.dart';
import 'package:eletrend/memories.dart';
import 'package:eletrend/models.dart';
import 'package:eletrend/nudges.dart';
import 'package:eletrend/social.dart';
import 'package:eletrend/theme.dart';
import 'package:eletrend/tips.dart';
import 'package:eletrend/admin.dart';
import 'package:eletrend/main.dart';
import 'package:eletrend/store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';
import 'widget_test.dart' show phone, stopServices;

void main() {
  setUp(signInFakeAccount);
  coverage();

  test('fordítás: magyarul az eredeti, angolul a szótár; sablon és egyes/többes szám', () {
    L10n.lang = AppLanguage.hu;
    expect(tr('Mégse'), 'Mégse');
    expect(trf('{0} elmaradt teendő', [3]), '3 elmaradt teendő');

    L10n.lang = AppLanguage.en;
    expect(tr('Mégse'), 'Cancel');
    expect(tr('Ismeretlen magyar szöveg ő'), 'Ismeretlen magyar szöveg ő'); // nincs fordítás: marad az eredeti
    expect(L10n.missing, contains('Ismeretlen magyar szöveg ő'));
    expect(trf('Van {0} elmaradt teendőd', [1]), 'You have 1 missed task');
    expect(trf('Van {0} elmaradt teendőd', [3]), 'You have 3 missed tasks');
    expect(trf('Bökés: {0}', ['Anna']), 'Nudge: Anna');
    // A behelyettesített ismert szöveg is fordul (pl. egy állapot neve).
    expect(trf('Az állapotod: {0}', ['Szabad']), 'Your status: Free');
    expect(L10n.code, 'en');
    L10n.missing.remove('Ismeretlen magyar szöveg ő');
  });

  test('az alapnyelv angol; a tesztek magyarra állítják', () {
    expect(AppStore.defaultLanguage, AppLanguage.hu); // a flutter_test_config.dart állítja
    AppStore.defaultLanguage = AppLanguage.en;
    addTearDown(() => AppStore.defaultLanguage = AppLanguage.hu);
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});
    return AppStore.load().then((store) {
      expect(store.language, AppLanguage.en);
      store.setLanguage(AppLanguage.hu);
      expect(store.language, AppLanguage.hu);
      // A nyelv a mentésben marad (és a felhőbe is megy a beállításokkal).
      expect(store.exportData().replaceAll(' ', ''), contains('"language":"hu"'));
    });
  });

  testWidgets('nyelvváltás a Profilban: azonnal átvált az egész app (a const szövegek is)', (tester) async {
    phone(tester);
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});
    final store = (await tester.runAsync(AppStore.load))!
      ..finishOnboarding(name: 'Gabi')
      ..setTourDone(true)
      ..setLanguage(AppLanguage.en);
    await tester.pumpWidget(LifeupApp(store: store));
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsWidgets);

    await tester.tap(find.text('Profile').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Language'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Language'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('🇭🇺  Magyar'));
    await tester.pumpAndSettle();
    expect(store.language, AppLanguage.hu);
    expect(find.text('Nyelv'), findsOneWidget);
    expect(find.text('Language'), findsNothing);
    expect(find.text('Főoldal'), findsWidgets); // az alsó menü is magyar

    await tester.ensureVisible(find.text('Nyelv'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nyelv'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('🇬🇧  English'));
    await tester.pumpAndSettle();
    expect(store.language, AppLanguage.en);
    expect(find.text('Home'), findsWidgets);
    stopServices();
  });
}

/// A konstans táblázatokban (felsorolások, tippek, sablonok) lévő magyar szövegek mind le vannak fordítva.
void coverage() {
  test('minden felsorolás-címke, tipp és sablon szövegének van angol fordítása', () {
    final strings = <String>[
      for (final v in AvailabilityStatus.values) v.label,
      for (final v in AvailabilityShare.values) v.label,
      for (final v in DayPart.values) v.label,
      for (final v in RsvpStatus.values) v.label,
      for (final v in PhotoAudience.values) v.label,
      for (final v in HomeCard.values) v.label,
      for (final v in EventCategory.values) v.label,
      for (final v in Repeat.values) v.label,
      for (final v in StatRange.values) ...[v.label, v.previousLabel],
      for (final v in LightPalette.values) ...[v.label, v.description],
      for (final p in freeWindowPresets) p.label,
      for (final t in tips) ...[t.text, ?t.actionLabel],
      for (final p in habitPacks) ...[
        p.title,
        p.text,
        for (final h in p.habits) ...[h.name, if (h.unit.isNotEmpty) h.unit],
      ],
      for (final (_, title, _) in challengeIdeas) title,
      for (final (_, text) in nudgeTemplates) text,
    ];
    L10n.lang = AppLanguage.en;
    L10n.missing.clear();
    final untranslated = <String>[];
    for (final s in strings) {
      // Angolul is ugyanaz lehet (pl. „Admin”, „Magenta”), ezeket nem kell fordítani.
      if (tr(s) == s && !const {'Magenta', 'Admin'}.contains(s)) untranslated.add(s);
    }
    expect(untranslated, isEmpty);
    expect(L10n.missing, isEmpty);
  });
}
