import 'dart:io';

import 'package:eletrend/account.dart';
import 'package:eletrend/l10n/l10n.dart';
import 'package:eletrend/legal.dart';
import 'package:eletrend/main.dart';
import 'package:eletrend/store.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';
import 'widget_test.dart' show phone, stopServices;

void main() {
  setUp(signInFakeAccount);

  test('a jogi oldalak linkje az app nyelvét kéri', () {
    L10n.lang = AppLanguage.hu;
    expect(legalUri(LegalPage.privacy).toString(), 'https://mikii561.github.io/eletrend/privacy.html?lang=hu');
    L10n.lang = AppLanguage.en;
    expect(legalUri(LegalPage.terms).toString(), 'https://mikii561.github.io/eletrend/terms.html?lang=en');
  });

  test('a két jogi oldal létezik, magyarul és angolul is, és hivatkoznak egymásra', () {
    for (final (file, other) in [('web/privacy.html', 'terms.html'), ('web/terms.html', 'privacy.html')]) {
      final html = File(file).readAsStringSync();
      expect(html, contains('<section lang="en">'), reason: file);
      expect(html, contains('<section lang="hu">'), reason: file);
      expect(html, contains(other), reason: file);
      expect(html, contains('2026. november 1.'), reason: file);
    }
    // Az adatvédelmi tájékoztató a valós működést írja le.
    final privacy = File('web/privacy.html').readAsStringSync();
    for (final word in [
      'calendar.readonly',
      'Firebase',
      'OpenStreetMap',
      'NAIH',
      'Profile → Delete account',
      'Profil → Fiók törlése',
    ]) {
      expect(privacy, contains(word));
    }
  });

  testWidgets('Profil → Jogi: a két oldal megnyílik', (tester) async {
    phone(tester);
    final opened = <Uri>[];
    legalLauncher = (uri) async {
      opened.add(uri);
      return true;
    };
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});
    final store = (await tester.runAsync(AppStore.load))!
      ..finishOnboarding(name: 'Gabi')
      ..setTourDone(true);
    await tester.pumpWidget(LifeupApp(store: store));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profil').last);
    await tester.pumpAndSettle();
    final list = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.text('Adatvédelmi tájékoztató'), 300, scrollable: list);
    await tester.tap(find.text('Adatvédelmi tájékoztató'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Felhasználási feltételek'), 300, scrollable: list);
    await tester.tap(find.text('Felhasználási feltételek'));
    await tester.pumpAndSettle();
    expect(opened.map((u) => u.path), ['/eletrend/privacy.html', '/eletrend/terms.html']);
    expect(opened.first.queryParameters['lang'], 'hu');
    stopServices();
  });

  testWidgets('bejelentkezés: az elfogadási sor és a két link látszik és működik', (tester) async {
    phone(tester);
    final opened = <Uri>[];
    legalLauncher = (uri) async {
      opened.add(uri);
      return true;
    };
    Account.instance = Account(auth: MockFirebaseAuth(), db: FakeFirebaseFirestore());
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});
    final store = (await tester.runAsync(AppStore.load))!;
    await tester.pumpWidget(LifeupApp(store: store));
    await tester.pumpAndSettle();
    expect(find.text('A folytatással elfogadod:'), findsOneWidget);
    await tester.ensureVisible(find.text('Felhasználási feltételek'));
    await tester.tap(find.text('Felhasználási feltételek'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Adatvédelmi tájékoztató'));
    await tester.tap(find.text('Adatvédelmi tájékoztató'));
    await tester.pumpAndSettle();
    expect(opened.map((u) => u.path), ['/eletrend/terms.html', '/eletrend/privacy.html']);
  });
}
