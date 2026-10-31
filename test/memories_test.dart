import 'dart:typed_data';

import 'package:eletrend/memories.dart';
import 'package:eletrend/models.dart';
import 'package:eletrend/notifications.dart';
import 'package:eletrend/store.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

Event shared(String id, DateTime start, {String place = '', Repeat repeat = Repeat.none}) =>
    Event(id: id, title: 'Program $id', start: start, durationMin: 120, place: place, repeat: repeat)..shareId = 's$id';

void main() {
  setUpAll(() => initializeDateFormatting('hu'));

  test('mennyi ideje volt', () {
    final now = DateTime(2026, 11, 10, 12);
    expect(agoLabel(DateTime(2026, 11, 7), now), '3 napja');
    expect(agoLabel(DateTime(2026, 10, 27), now), '2 hete');
    expect(agoLabel(DateTime(2026, 8, 10), now), '3 hónapja');
    expect(agoLabel(DateTime(2025, 11, 10), now), '1 éve');
    expect(agoLabel(DateTime(2023, 12, 1), now), '2 éve');
  });

  group('melyik emlék jön elő', () {
    final now = DateTime(2026, 11, 10, 9);

    test('kerek évforduló elsőbbséget kap (1 éve, 3 hónapja, 1 hete)', () {
      final events = [
        shared('a', DateTime(2026, 9, 1, 18)),
        shared('b', DateTime(2025, 11, 10, 20), place: 'Balaton'),
        shared('c', DateTime(2026, 8, 25, 18)),
      ];
      final pick = pickMemory(events, now)!;
      expect(pick.event.id, 'b');
      expect(pick.ago, '1 éve');
      expect(pick.anniversary, isTrue);

      final week = pickMemory([shared('w', DateTime(2026, 11, 3, 19))], now)!;
      expect(week.ago, '1 hete');
      expect(week.anniversary, isTrue);
      expect(pickMemory([shared('m', DateTime(2026, 8, 10, 19))], now)!.ago, '3 hónapja');
    });

    test('évforduló nélkül egy legalább két hete volt program jön, háromnaponta másik', () {
      final events = [shared('a', DateTime(2026, 9, 1, 18)), shared('b', DateTime(2026, 9, 20, 18))];
      final first = pickMemory(events, now)!;
      expect(first.anniversary, isFalse);
      final picks = {for (var d = 0; d < 9; d++) pickMemory(events, now.add(Duration(days: d)))!.event.id};
      expect(picks, {'a', 'b'});
    });

    test('nem közös, ismétlődő, jövőbeli vagy friss program nem emlék', () {
      expect(pickMemory([Event(id: 'p', title: 'Saját', start: DateTime(2025, 11, 10, 9))], now), isNull);
      expect(pickMemory([shared('r', DateTime(2025, 11, 10), repeat: Repeat.weekly)], now), isNull);
      expect(pickMemory([shared('f', DateTime(2026, 12, 1))], now), isNull);
      expect(pickMemory([shared('n', DateTime(2026, 11, 5))], now), isNull); // 5 napja: még friss
    });
  });

  test('kép előkészítése: nagy fotóból kisebb JPEG és előnézet', () {
    final big = img.Image(width: 3000, height: 2000);
    img.fill(big, color: img.ColorRgb8(89, 9, 7));
    img.fillCircle(big, x: 1500, y: 1000, radius: 600, color: img.ColorRgb8(232, 210, 181));
    final prepared = Memories.prepare(Uint8List.fromList(img.encodePng(big)));
    expect(prepared.full.length, lessThanOrEqualTo(Memories.maxBytes));
    expect(img.decodeJpg(prepared.full)!.width, 1600);
    expect(img.decodeJpg(prepared.thumb)!.width, 320);
    expect(() => Memories.prepare(Uint8List.fromList([1, 2, 3])), throwsA(isA<MemoryException>()));
  });

  test('feltöltés, ki mit lát, teljes kép, törlés, fióktörlés', () async {
    final db = FakeFirebaseFirestore();
    Memories as(String uid) => Memories(db: db, auth: MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: uid)));
    final anna = as('anna'), bela = as('bela');
    final full = Uint8List.fromList([1, 2, 3, 4]);
    final thumb = Uint8List.fromList([5, 6]);

    await anna.upload('e1', name: 'Anna', full: full, thumb: thumb);
    await anna.upload('e1', name: 'Anna', full: full, thumb: thumb, audience: PhotoAudience.going, allowDownload: false);

    // Béla nem ment el: csak a mindenkinek szóló fotót látja; ha ment, mindkettőt.
    expect(await bela.watch('e1', going: false).first, hasLength(1));
    final both = await bela.watch('e1', going: true).first;
    expect(both, hasLength(2));
    expect(both.where((p) => !p.allowDownload), hasLength(1));
    // Anna a sajátjait mindig látja.
    expect(await anna.watch('e1', going: false).first, hasLength(2));

    final photo = both.first;
    expect(photo.name, 'Anna');
    expect(photo.thumbBytes, thumb);
    expect(await bela.full('e1', photo), full);

    await anna.update('e1', photo, audience: PhotoAudience.going, allowDownload: false);
    expect(await bela.watch('e1', going: false).first, isEmpty);

    await anna.delete('e1', photo.id);
    expect(await anna.watch('e1', going: true).first, hasLength(1));

    // Fióktörlés: minden saját fotó eltűnik, a jegyzetekkel együtt.
    await anna.upload('e2', name: 'Anna', full: full, thumb: thumb);
    await anna.deleteAllOf('anna');
    expect((await db.collection('events').doc('e1').collection('photos').get()).docs, isEmpty);
    expect((await db.collection('events').doc('e2').collection('photoData').get()).docs, isEmpty);
    expect((await db.collection('users').doc('anna').collection('myPhotos').get()).docs, isEmpty);
  });

  test('évfordulós értesítés: aznap 10-kor, kikapcsolható', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await AppStore.load();
    store.saveEvent(shared('b', DateTime(2025, 11, 12, 20), place: 'Balaton'));
    final plan = Notifications.plan(store, DateTime(2026, 11, 10, 9));
    final memory = plan.where((p) => p.title.startsWith('Emlék')).single;
    expect(memory.when, DateTime(2026, 11, 12, 10));
    expect(memory.body, contains('1 éve'));
    expect(memory.body, contains('Balaton'));

    store.setReminders(memories: false);
    expect(Notifications.plan(store, DateTime(2026, 11, 10, 9)).where((p) => p.title.startsWith('Emlék')), isEmpty);
  });
}
