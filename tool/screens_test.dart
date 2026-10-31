// ignore_for_file: invalid_use_of_visible_for_testing_member
// Képernyőképek a dizájn ellenőrzéséhez (nem része a normál teszteknek).
// Futtatás: ELETREND_SHOTS=<mappa> flutter test tool/screens_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:eletrend/account.dart';
import 'package:eletrend/availability_service.dart';
import 'package:eletrend/challenges.dart';
import 'package:eletrend/friends.dart';
import 'package:eletrend/main.dart';
import 'package:eletrend/admin.dart';
import 'package:eletrend/models.dart';
import 'package:eletrend/memories.dart';
import 'package:eletrend/nudges.dart';
import 'package:image/image.dart' as img;
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
    await loadFont('MaterialIcons', [
      'D:/Downloads/flutter/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
    ]);
  });

  for (final dark in [false, true]) {
    testWidgets('képernyők ${dark ? 'sötét' : 'világos'}', (tester) async {
      if (out == null) return;
      tester.view.physicalSize = const Size(400, 860);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final db = FakeFirebaseFirestore();
      Account.instance = Account(
        auth: MockFirebaseAuth(
          signedIn: true,
          mockUser: MockUser(uid: 'u', email: 'gabi@pelda.hu'),
        ),
        db: db,
      );
      Admin.instance = Admin(db: db);
      Friends.instance = Friends(db: db);
      Challenges.instance = Challenges(db: db);
      Nudges.instance = Nudges(db: db);
      AvailabilityService.instance = AvailabilityService(db: db);
      SharedPreferences.setMockInitialValues({'onboarded': true, 'themeMode': dark ? 'dark' : 'light'});
      final store = await AppStore.load();
      store.setMyName('Gábriel');
      store.addHabit('Víz', target: 8, unit: 'pohár');
      store.addHabit('Edzés', perWeek: 3);
      store.addHabit('Olvasás');
      final now = DateTime.now();
      for (var i = 1; i < 12; i++) {
        store.habits[2].doneDays.add(dayKey(addDays(now, -i)));
      }
      store.habits[2].doneDays.add(dayKey(now));
      for (var i = 20; i < 200; i += 1 + i % 3) {
        store.habits[2].doneDays.add(dayKey(addDays(now, -i)));
      }
      store.habits[0].counts[dayKey(now)] = 5;
      final today = DateTime(now.year, now.month, now.day);
      DateTime at(int day, int hour, [int minute = 0]) =>
          DateTime(today.year, today.month, today.day + day, hour, minute);
      store
        ..saveEvent(
          Event(
            id: 'a',
            title: 'Csapatmegbeszélés',
            start: at(0, 9, 30),
            durationMin: 60,
            category: EventCategory.work,
          ),
        )
        ..saveEvent(
          Event(
            id: 'b',
            title: 'Edzés',
            start: at(0, 17),
            durationMin: 90,
            category: EventCategory.health,
            place: 'Fitness park',
          ),
        )
        ..saveEvent(
          Event(
            id: 'c',
            title: 'Pizzaest',
            start: at(0, 20),
            durationMin: 150,
            category: EventCategory.social,
            place: 'Budapest',
          )..shareId = 'x',
        )
        ..saveEvent(
          Event(
            id: 'd',
            title: 'Egyetem: statisztika',
            start: at(1, 10),
            durationMin: 90,
            category: EventCategory.study,
            repeat: Repeat.weekly,
          ),
        )
        ..saveEvent(
          Event(
            id: 'f',
            title: 'Foci',
            start: at(2, 18),
            durationMin: 90,
            category: EventCategory.health,
            repeat: Repeat.weekly,
          ),
        )
        ..saveEvent(
          Event(
            id: 'g',
            title: 'Anyu születésnapja',
            start: at(3, 0),
            durationMin: 1440,
            allDay: true,
            busy: false,
            category: EventCategory.important,
          ),
        )
        ..saveTask(TaskItem(id: 't1', title: 'Számla befizetése', due: at(0, 12)))
        ..saveTask(
          TaskItem(
            id: 't2',
            title: 'Beadandó megírása',
            scheduled: at(0, 14),
            durationMin: 90,
            category: EventCategory.study,
          ),
        )
        ..saveTask(TaskItem(id: 't3', title: 'Ajándék Anyunak', due: at(2, 12)))
        ..setFriendsCache(const [
          FriendInfo(uid: 'f1', name: 'Anna', birthday: '12-24'),
          FriendInfo(uid: 'f2', name: 'Bence'),
        ]);
      // Egy éve volt közös program, fotókkal: a Főoldalon emlékként jön elő.
      store.saveEvent(
        Event(
          id: 'mem',
          title: 'Balatoni hétvége',
          start: DateTime(now.year - 1, now.month, now.day, 10),
          durationMin: 600,
          place: 'Balatonfüred',
          category: EventCategory.social,
        )..shareId = 'mem1',
      );
      Memories.instance = Memories(db: db, auth: Account.instance.auth);
      for (final (i, color) in [(0, img.ColorRgb8(58, 110, 140)), (1, img.ColorRgb8(200, 150, 80)), (2, img.ColorRgb8(90, 120, 70))]) {
        final picture = img.Image(width: 900, height: 700);
        img.fill(picture, color: color);
        img.fillCircle(picture, x: 300 + i * 150, y: 300, radius: 160, color: img.ColorRgb8(245, 230, 200));
        final prepared = Memories.prepare(Uint8List.fromList(img.encodePng(picture)));
        await tester.runAsync(() => Memories.instance.upload('mem1', name: 'Anna', full: prepared.full, thumb: prepared.thumb));
      }

      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: LifeupApp(store: store),
        ),
      );
      await tester.pumpAndSettle();

      Future<void> shot(String name, {bool settle = true}) async {
        if (settle) await tester.pumpAndSettle();
        final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await tester.runAsync(() => boundary.toImage());
        final png = await tester.runAsync(() => image!.toByteData(format: ui.ImageByteFormat.png));
        File('$out/${dark ? 'sotet' : 'vilagos'}-$name.png').writeAsBytesSync(png!.buffer.asUint8List());
      }

      // Első megnyitás: a bemutató.
      await shot('00a-bemutato-1');
      await tester.tap(find.text('Tovább'));
      await tester.tap(find.text('Tovább'));
      await shot('00b-bemutato-3');
      await tester.tap(find.text('Tovább'));
      await tester.tap(find.text('Tovább'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tovább'));
      await shot('00c-bemutato-6');
      await tester.tap(find.text('Tovább'));
      await tester.tap(find.text('Tovább'));
      for (final (ms, name) in [(1800, '00d-pelda-1'), (2500, '00e-pelda-2'), (2400, '00f-pelda-3')]) {
        await tester.pump(Duration(milliseconds: ms));
        await shot(name, settle: false);
      }
      await tester.tap(find.text('Kihagyom'));
      await shot('01-fooldal');
      await tester.drag(find.byType(ListView).first, const Offset(0, -700));
      await shot('02-fooldal-lent');
      await tester.drag(find.byType(ListView).first, const Offset(0, -700));
      await shot('02b-fooldal-emlek');
      await tester.tap(find.text('Balatoni hétvége'));
      await tester.pumpAndSettle();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
      await shot('02c-emlekek');
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Naptár').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nap'));
      await shot('03-naptar-nap');
      await tester.tap(find.text('Hét'));
      await shot('04-naptar-het');
      await tester.tap(find.text('Hónap'));
      await shot('05-naptar-honap');
      await tester.tap(find.text('Lista'));
      await shot('06-naptar-lista');
      await tester.tap(find.text('Létrehozás'));
      await shot('07-letrehozas');
      await tester.tap(find.text('Közös program'));
      await shot('08-kozos-program');
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Barátok').last);
      await shot('09-baratok');
      await tester.tap(find.text('Profil').last);
      await shot('10-profil');
      await tester.tap(find.text('Adatvédelem'));
      await shot('11-adatvedelem');
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Céljaim'));
      await shot('12-celok');
      Account.instance.sync?.stop();
      Friends.instance.stop();
      Challenges.instance.stop();
      Nudges.instance.stop();
      AvailabilityService.instance.stop();
    });
  }
}
