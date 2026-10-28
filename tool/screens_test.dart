// ignore_for_file: invalid_use_of_visible_for_testing_member
// Képernyőképek a dizájn ellenőrzéséhez (nem része a normál teszteknek).
// Futtatás: ELETREND_SHOTS=<mappa> flutter test tool/screens_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:eletrend/account.dart';
import 'package:eletrend/bumps.dart';
import 'package:eletrend/challenges.dart';
import 'package:eletrend/community.dart';
import 'package:eletrend/friends.dart';
import 'package:eletrend/main.dart';
import 'package:eletrend/admin.dart';
import 'package:eletrend/badges.dart';
import 'package:eletrend/models.dart';
import 'package:eletrend/store.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> loadFont(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final p in paths) {
    loader.addFont(Future.value(ByteData.sublistView(File(p).readAsBytesSync())));
  }
  await loader.load();
}

void main() {
  final out = Platform.environment['ELETREND_SHOTS'];

  setUpAll(() async {
    await initializeDateFormatting('hu');
    GoogleFonts.config.allowRuntimeFetching = false;
    final inter = GoogleFonts.inter().fontFamily!;
    await loadFont(inter, ['C:/Windows/Fonts/segoeui.ttf', 'C:/Windows/Fonts/segoeuib.ttf']);
    await loadFont('MaterialIcons', ['D:/Downloads/flutter/bin/cache/artifacts/material_fonts/materialicons-regular.otf']);
  });

  for (final dark in [false, true]) {
    testWidgets('képernyők ${dark ? 'sötét' : 'világos'}', (tester) async {
      if (out == null) return;
      tester.view.physicalSize = const Size(400, 860);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final db = FakeFirebaseFirestore();
      Account.instance = Account(auth: MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'u', email: 'gabi@pelda.hu')), db: db);
      Admin.instance = Admin(db: db);
      Friends.instance = Friends(db: db);
      Challenges.instance = Challenges(db: db);
      Community.instance = Community(db: db);
      Bumps.instance = Bumps(db: db);
      SharedPreferences.setMockInitialValues({'onboarded': true, 'themeMode': dark ? 'dark' : 'light', 'seenBadges': [for (final a in achievements) a.id]});
      final store = await AppStore.load();
      store.setMyName('Gábriel');
      store.addHabit('Víz', target: 8, unit: 'pohár');
      store.addHabit('Edzés', perWeek: 3);
      store.addHabit('Olvasás');
      final now = DateTime.now();
      for (var i = 1; i < 12; i++) {
        store.saveEntry(JournalEntry(id: '$i', date: addDays(now, -i), mood: 2 + i % 4, gratitude: 'Egy jó beszélgetés', tags: ['nyugodt']));
        store.habits[2].doneDays.add(dayKey(addDays(now, -i)));
      }
      store.habits[2].doneDays.add(dayKey(now));
      for (var i = 20; i < 200; i += 1 + i % 3) {
        store.habits[2].doneDays.add(dayKey(addDays(now, -i)));
      }
      store.habits[0].counts[dayKey(now)] = 5;
      store.saveEvent(Event(id: 'e', title: 'Pizzaest', date: addDays(now, 2), place: 'Budapest', invited: ['Anna', 'Bence'])..bgTheme = 'food');
      store.saveEvent(Event(id: 'f', title: 'Foci', date: addDays(now, 4), repeat: Repeat.weekly));

      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(key: key, child: EletrendApp(store: store)));
      await tester.pumpAndSettle();

      Future<void> shot(String name) async {
        await tester.pumpAndSettle();
        final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await tester.runAsync(() => boundary.toImage());
        final png = await tester.runAsync(() => image!.toByteData(format: ui.ImageByteFormat.png));
        File('$out/${dark ? 'sotet' : 'vilagos'}-$name.png').writeAsBytesSync(png!.buffer.asUint8List());
      }

      await shot('1-ma');
      await tester.tapAt(const Offset(200, 830));
      await shot('4-celok');
      await tester.tap(find.text('Olvasás').hitTestable());
      await shot('7-elozmenyek-honap');
      await tester.tap(find.text('Év'));
      await shot('8-elozmenyek-ev');
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Programok'));
      await shot('2-programok');
      await tester.tap(find.text('Napló').last);
      await shot('5-naplo');
      await tester.tap(find.text('Barátok').last);
      await shot('6-baratok');
      Account.instance.sync?.stop();
      Friends.instance.stop();
      Challenges.instance.stop();
      Bumps.instance.stop();
    });
  }
}
