import 'package:eletrend/challenges.dart';
import 'package:eletrend/models.dart';
import 'package:eletrend/store.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AppStore> device(String name) async {
  SharedPreferences.resetStatic();
  SharedPreferences.setMockInitialValues({});
  return (await AppStore.load())..setMyName(name);
}

void main() {
  test('kihívás: indítás barátokkal, teljesítés, ranglista, buzdítás, célhoz kötés, kilépés', () async {
    final db = FakeFirebaseFirestore();
    final gabiStore = await device('Gabi');
    final annaStore = await device('Anna');
    final gabi = Challenges(db: db)..start('gabi', gabiStore);
    final anna = Challenges(db: db)..start('anna', annaStore);

    final today = DateTime.now();
    await gabi.create(title: '30 nap edzés', emoji: '🏋️', days: 30, start: addDays(today, -2), friends: {'anna': 'Anna'});
    final c = (await anna.watchMine().first).single;
    expect(c.title, '30 nap edzés');
    expect(c.dayNumber(today), 3);
    expect(c.isActive(today), isTrue);

    await anna.checkIn(c, today, true);
    await anna.checkIn(c, addDays(today, -1), true);
    await gabi.checkIn(c, today, true);
    var progress = await gabi.watchProgress(c.id).first;
    expect(progress.first.name, 'Anna'); // 2 nap > 1 nap
    expect(progress.first.done.length, 2);

    await gabi.cheer(c.id, 'anna');
    progress = await gabi.watchProgress(c.id).first;
    expect(progress.firstWhere((p) => p.uid == 'anna').cheers, 1);

    // Gabi a kihívást az „Edzés” céljához köti: a cél napjai a kihívásba kerülnek
    gabiStore.addHabit('Edzés');
    final h = gabiStore.habits.single;
    h.doneDays.addAll([dayKey(today), dayKey(addDays(today, -1)), dayKey(addDays(today, -2)), dayKey(addDays(today, -40))]);
    gabiStore.linkChallengeHabit(c.id, h.id);
    await gabi.syncLinkedHabits();
    progress = await anna.watchProgress(c.id).first;
    expect(progress.firstWhere((p) => p.uid == 'gabi').done.length, 3); // a 40 nappal ezelőtti nem számít

    await anna.leave(c);
    expect(await anna.watchMine().first, isEmpty);
    expect((await gabi.watchMine().first).single.members, ['gabi']);
    gabi.stop();
    anna.stop();
  });
}
