import 'package:eletrend/models.dart';
import 'package:eletrend/notifications.dart';
import 'package:eletrend/nudges.dart';
import 'package:eletrend/store.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() => initializeDateFormatting('hu'));

  test('bökés: napi sorszámos azonosító, a címzett látja, olvasottnak jelöli', () async {
    final db = FakeFirebaseFirestore();
    final gabi = Nudges(db: db);
    final anna = Nudges(db: db);
    final received = <Nudge>[];
    gabi.start('gabi', (_) {});
    anna.start('anna', received.add);

    final day = DateTime(2026, 11, 3);
    await gabi.send('anna', fromName: 'Gabi', text: 'Szervezzünk valamit!', emoji: '🎉', now: day);
    await pumpEventQueue();
    // A napi keretet (legfeljebb 3) a szerver szabálya kényszeríti ki: a meglévő azonosító nem írható
    // felül. A teszt-adatbázis ezt nem ellenőrzi, itt csak az azonosító formáját nézzük.
    final ids = (await db.collection('nudges').doc('anna').collection('items').get()).docs.map((d) => d.id).toList();
    expect(ids, ['gabi_20261103_0']);
    expect(received.map((n) => n.headline), contains('🎉 Gabi: Szervezzünk valamit!'));

    await anna.markSeen(received.first.id);
    expect((await anna.fetch(received.first.id))!.seen, isTrue);
    await expectLater(gabi.send('anna', fromName: 'Gabi', text: '   '), throwsA(isA<NudgeException>()));
    gabi.stop();
    anna.stop();
  });

  test('értesítések terve: emlékeztető előtte, feladat határidő, születésnap; a múlt nem', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await AppStore.load();
    final now = DateTime(2026, 11, 3, 8);
    store
      ..saveEvent(
        Event(id: 'e', title: 'Fogorvos', start: DateTime(2026, 11, 3, 13), reminderMin: 30, place: 'Rendelő'),
      )
      ..saveEvent(Event(id: 'r', title: 'Reggeli', start: DateTime(2026, 11, 3, 7), reminderMin: 10)) // már elmúlt
      ..saveEvent(Event(id: 'n', title: 'Csendes', start: DateTime(2026, 11, 3, 15), reminderMin: null))
      ..saveTask(TaskItem(id: 't', title: 'Számla', due: DateTime(2026, 11, 4, 12)))
      ..setFriendsCache(const [FriendInfo(uid: 'a', name: 'Anna', birthday: '11-10')]);
    final plan = Notifications.plan(store, now);
    final byTitle = {for (final p in plan) p.title: p};
    expect(byTitle['30 perc múlva: Fogorvos']!.when, DateTime(2026, 11, 3, 12, 30));
    expect(byTitle['30 perc múlva: Fogorvos']!.body, '13:00–14:00 · Rendelő');
    expect(byTitle.keys.where((t) => t.contains('Reggeli') || t.contains('Csendes')), isEmpty);
    expect(byTitle['Ma a határidő: Számla']!.when, DateTime(2026, 11, 4, 9));
    expect(byTitle['Ma van Anna születésnapja 🎂']!.when, DateTime(2026, 11, 10, 9));

    store.setReminders(events: false, tasks: false, birthdays: false);
    expect(Notifications.plan(store, now), isEmpty);
  });
}
