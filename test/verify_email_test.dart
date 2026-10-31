import 'package:eletrend/account.dart';
import 'package:eletrend/main.dart';
import 'package:eletrend/screens/verify_email_screen.dart';
import 'package:eletrend/store.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

/// Fiók, ahol a megerősítést mi vezéreljük (a valódi levél és link nem érhető el tesztben).
class _Account extends Account {
  _Account({required super.auth, required super.db});

  bool verified = false;
  int sent = 0;

  @override
  bool needsVerification(User? u) => u != null;

  @override
  Future<bool> checkVerified() async => verified;

  @override
  Future<void> sendVerification() async => sent++;
}

void main() {
  setUpAll(() => initializeDateFormatting('hu'));

  test('megerősítés csak az újabb, e-mail-címes, még meg nem erősített fióknál kell', () {
    final account = Account(auth: MockFirebaseAuth(), db: FakeFirebaseFirestore());
    final cutoff = Account.verificationFrom;
    MockUser user({bool verified = false, String email = 'a@b.hu', DateTime? created}) => MockUser(
      uid: 'u',
      email: email,
      isEmailVerified: verified,
      metadata: created == null ? null : UserMetadata(created.millisecondsSinceEpoch, created.millisecondsSinceEpoch),
    );
    expect(account.needsVerification(null), isFalse);
    expect(account.needsVerification(user(created: cutoff.add(const Duration(days: 1)))), isTrue);
    expect(account.needsVerification(user(created: cutoff.subtract(const Duration(days: 1)))), isFalse); // régi fiók
    expect(account.needsVerification(user(verified: true, created: cutoff.add(const Duration(days: 1)))), isFalse);
    expect(account.needsVerification(user(email: '', created: cutoff.add(const Duration(days: 1)))), isFalse);
  });

  testWidgets(
    'regisztráció után: megerősítő oldal, nincs szinkron; megerősítés → Sikeres regisztráció → Első lépések',
    (tester) async {
      tester.view.physicalSize = const Size(400, 860);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final db = FakeFirebaseFirestore();
      final account = Account.instance = _Account(
        auth: MockFirebaseAuth(
          signedIn: true,
          mockUser: MockUser(uid: 'u1', email: 'anna@pelda.hu', displayName: 'Anna'),
        ),
        db: db,
      );
      SharedPreferences.resetStatic();
      SharedPreferences.setMockInitialValues({});
      final store = (await tester.runAsync(AppStore.load))!..beginOnboarding();
      await tester.pumpWidget(LifeupApp(store: store));
      await tester.pumpAndSettle();

      expect(find.text('Erősítsd meg az e-mail-címed'), findsOneWidget);
      expect(find.text('anna@pelda.hu'), findsOneWidget);
      expect(account.sync, isNull); // megerősítésig semmit nem töltünk fel a fiókhoz
      expect(find.text('Üdvözlünk a LIFEUP alkalmazásban!'), findsNothing);

      // Még nem erősítette meg.
      await tester.tap(find.text('Megerősítettem'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Még nem látjuk megerősítve'), findsOneWidget);

      // Új levél kérése: utána néhány másodpercig nem kérhető újra.
      await tester.tap(find.text('Levél újraküldése'));
      await tester.pumpAndSettle();
      expect(account.sent, 1);
      expect(find.textContaining('Új levél kérése'), findsOneWidget);
      await tester.pump(const Duration(seconds: 61));

      // Megerősíti a levélben: az app továbblép.
      account.verified = true;
      await tester.tap(find.text('Megerősítettem'));
      await tester.pumpAndSettle();
      expect(find.text('Sikeres regisztráció!'), findsOneWidget);
      expect(account.sync, isNull);

      // Tovább: betöltődik a fiók, és jönnek az első lépések (csak regisztrációnál).
      await tester.tap(find.text('Tovább'));
      await tester.pumpAndSettle();
      expect(find.text('Üdvözlünk a LIFEUP alkalmazásban!'), findsOneWidget);
      expect(account.sync, isNotNull);
      account.sync?.stop();
    },
  );

  testWidgets('bejelentkezés (nem regisztráció): nincs első lépések, a megerősített fiók rögtön az appba jut', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    signInFakeAccount(uid: 'u2', email: 'bela@pelda.hu'); // a már megerősített, korábbi fiókok így lépnek be
    final account = Account.instance;
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});
    final store = (await tester.runAsync(AppStore.load))!; // nem regisztráltunk: nincs beginOnboarding
    await tester.pumpWidget(LifeupApp(store: store));
    await tester.pumpAndSettle();
    expect(find.text('Üdvözlünk a LIFEUP alkalmazásban!'), findsNothing);
    expect(find.text('Erősítsd meg az e-mail-címed'), findsNothing);
    expect(store.needsOnboarding, isFalse);
    account.sync?.stop();
  });

  testWidgets('a megerősítő oldal: rossz e-mail esetén kijelentkezhet', (tester) async {
    final db = FakeFirebaseFirestore();
    Account.instance = _Account(
      auth: MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'u3', email: 'rossz@pelda.hu'),
      ),
      db: db,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: VerifyEmailScreen(email: 'rossz@pelda.hu', onVerified: () {}, pollEvery: const Duration(hours: 1)),
      ),
    );
    await tester.tap(find.text('Rossz az e-mail-cím? Kijelentkezés'));
    await tester.pumpAndSettle();
    expect(Account.instance.auth.currentUser, isNull);
  });
}
