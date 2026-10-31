import 'package:eletrend/availability.dart';
import 'package:eletrend/availability_service.dart';
import 'package:eletrend/models.dart';
import 'package:eletrend/store.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// UTC időpont röviden (a keresés mindig UTC-ben számol).
DateTime u(int day, int hour, [int minute = 0]) => DateTime.utc(2026, 11, day, hour, minute);

/// 2026. november 6. péntek. Mindenki budapesti téli időben (UTC+1).
const bp = 60;

void main() {
  group('időszakok', () {
    test('összevonás, kivonás, metszet', () {
      final merged = mergeIntervals([
        TimeSpan(u(6, 10), u(6, 12)),
        TimeSpan(u(6, 11), u(6, 13)),
        TimeSpan(u(6, 13), u(6, 14)),
      ]);
      expect(merged, [TimeSpan(u(6, 10), u(6, 14))]);
      expect(
        subtractIntervals([TimeSpan(u(6, 8), u(6, 20))], [TimeSpan(u(6, 10), u(6, 11)), TimeSpan(u(6, 15), u(6, 16))]),
        [TimeSpan(u(6, 8), u(6, 10)), TimeSpan(u(6, 11), u(6, 15)), TimeSpan(u(6, 16), u(6, 20))],
      );
      expect(
        intersectIntervals([TimeSpan(u(6, 8), u(6, 12)), TimeSpan(u(6, 14), u(6, 18))], [TimeSpan(u(6, 10), u(6, 15))]),
        [TimeSpan(u(6, 10), u(6, 12)), TimeSpan(u(6, 14), u(6, 15))],
      );
    });

    test('„ráérek” sáv a saját időzóna szerint', () {
      const evening = FreeWindow(days: {5}, fromMin: 18 * 60, toMin: 22 * 60); // péntek este
      // Budapest (UTC+1): 17:00–21:00 UTC; London (UTC+0): 18:00–22:00 UTC.
      expect(windowsToIntervals([evening], u(6, 0), u(7, 0), bp), [TimeSpan(u(6, 17), u(6, 21))]);
      expect(windowsToIntervals([evening], u(6, 0), u(7, 0), 0), [TimeSpan(u(6, 18), u(6, 22))]);
    });
  });

  group('közös időpont keresése', () {
    const evenings = [
      FreeWindow(days: {1, 2, 3, 4, 5, 6, 7}, fromMin: 17 * 60, toMin: 23 * 60),
    ];

    test('péntek 18–22 mindenkinek jó; a foglalt idő kiesik', () {
      final people = [
        Participant(
          uid: 'me',
          name: 'Te',
          known: true,
          windows: evenings,
          busy: [TimeSpan(u(6, 16), u(6, 17))],
        ), // 17–18-ig foglalt
        Participant(
          uid: 'a',
          name: 'Anna',
          known: true,
          windows: evenings,
          busy: [TimeSpan(u(6, 21), u(6, 23))],
        ), // 22-től foglalt
        const Participant(uid: 'b', name: 'Béla', known: true, windows: evenings),
      ];
      final slots = findCommonTime(
        people: people,
        from: u(6, 0),
        to: u(7, 0),
        duration: const Duration(hours: 2),
        part: DayPart.evening,
        viewerOffsetMin: bp,
        now: u(1, 0),
      );
      expect(slots.single.start, u(6, 17)); // 18:00 helyi idő
      expect(slots.single.end, u(6, 21)); // 22:00 helyi idő
      expect(slots.single.confirmed, isTrue);
    });

    test('akiről nincs adat, azt „nem tudjuk”-ként jelzi, de nem zárja ki az időpontot', () {
      final slots = findCommonTime(
        people: [
          const Participant(uid: 'me', name: 'Te', known: true, windows: evenings),
          const Participant.unknown(uid: 'c', name: 'Cili'),
        ],
        from: u(6, 0),
        to: u(7, 0),
        duration: const Duration(hours: 1),
        part: DayPart.evening,
        viewerOffsetMin: bp,
        now: u(1, 0),
      );
      expect(slots, isNotEmpty);
      expect(slots.first.confirmed, isFalse);
      expect(slots.first.unknown, ['Cili']);
    });

    test('túl rövid rés, kizárt nap és elmúlt idő nem kerül a találatok közé', () {
      final people = [
        Participant(
          uid: 'me',
          name: 'Te',
          known: true,
          windows: evenings,
          busy: [TimeSpan(u(6, 17), u(6, 21)), TimeSpan(u(6, 21, 30), u(6, 22))],
        ),
      ];
      List<CommonSlot> run({Set<String> excluded = const {}, DateTime? now}) => findCommonTime(
        people: people,
        from: u(6, 0),
        to: u(8, 0),
        duration: const Duration(hours: 1),
        part: DayPart.evening,
        excludedDays: excluded,
        viewerOffsetMin: bp,
        now: now ?? u(1, 0),
      );
      // Pénteken csak 16:00–17:00 (UTC) és 30 perces rés maradna: az utóbbi kiesik.
      expect(run().map((s) => s.start), [u(6, 16), u(7, 16)]);
      expect(run(excluded: {'2026-11-07'}).map((s) => s.start), [u(6, 16)]);
      // Szombat 17:10-kor (UTC 16:10) csak a következő fél órától ajánl.
      expect(run(now: u(7, 16, 10)).first.start, u(7, 16, 30));
    });

    test('ha nincs megadott sáv, reggel 8 és este 11 között bármikor jó', () {
      final slots = findCommonTime(
        people: [const Participant(uid: 'me', name: 'Te', known: true)],
        from: u(6, 0),
        to: u(7, 0),
        duration: const Duration(hours: 3),
        part: DayPart.daytime,
        viewerOffsetMin: bp,
        now: u(1, 0),
      );
      expect(slots.single.start, u(6, 7)); // 8:00 helyi idő
      expect(slots.single.end, u(6, 16)); // 17:00 helyi idő
    });
  });

  group('megosztás', () {
    Future<AppStore> store() async {
      SharedPreferences.resetStatic();
      SharedPreferences.setMockInitialValues({});
      return AppStore.load();
    }

    test('alapból senkivel; barátokkal vagy csak a kiválasztott csoportokkal', () async {
      final s = await store();
      expect(AvailabilityService.payload(s, ['a', 'b']), isNull);
      s.setPrivacy(shareAvailability: AvailabilityShare.friends);
      expect(AvailabilityService.viewersFor(s, ['b', 'a']), ['a', 'b']);
      s.saveGroup(FriendGroup(id: 'g', name: 'Foci', members: ['a', 'x']));
      s.setPrivacy(shareAvailability: AvailabilityShare.groups, shareGroups: {'g'});
      expect(AvailabilityService.viewersFor(s, ['a', 'b']), ['a']); // x már nem barát
    });

    test('a feltöltött adatban nincs cím, hely, jegyzet; csak időpontok', () async {
      final s = await store();
      final now = DateTime.now();
      s
        ..setPrivacy(shareAvailability: AvailabilityShare.friends)
        ..saveEvent(
          Event(
            id: 'e',
            title: 'Titkos orvos',
            start: DateTime(now.year, now.month, now.day + 1, 10),
            place: 'Rendelő',
            notes: 'jegyzet',
          ),
        );
      final data = AvailabilityService.payload(s, ['a'])!;
      final text = data.toString();
      expect(text, isNot(contains('Titkos')));
      expect(text, isNot(contains('Rendelő')));
      expect(text, isNot(contains('jegyzet')));
      expect(data['busy'], hasLength(1));
      expect(data['viewers'], ['a']);
    });

    test('feltöltés, a barát olvassa; kikapcsoláskor törlődik', () async {
      final db = FakeFirebaseFirestore();
      final s = await store();
      s.setPrivacy(shareAvailability: AvailabilityShare.friends);
      s.setManualStatus(AvailabilityStatus.open);
      await db.collection('friendships').doc('me').collection('list').doc('a').set({'name': 'Anna'});
      final service = AvailabilityService(db: db)..start('me', s);
      await pumpEventQueue();
      await service.publish();
      final seen = await AvailabilityService(db: db).fetch('me');
      expect(seen!.statusAt(DateTime.now()), AvailabilityStatus.open);

      s.setPrivacy(shareAvailability: AvailabilityShare.nobody);
      await service.publish();
      expect(await AvailabilityService(db: db).fetch('me'), isNull);
      service.stop();
    });
  });
}
