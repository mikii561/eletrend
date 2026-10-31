import 'dart:convert';
import 'dart:typed_data';

import 'package:eletrend/challenges.dart';
import 'package:eletrend/models.dart';
import 'package:eletrend/store.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:image/image.dart' as img;
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
    await gabi.create(
      title: '30 nap edzés',
      emoji: '🏋️',
      days: 30,
      start: addDays(today, -2),
      friends: {'anna': 'Anna'},
    );
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
    h.doneDays.addAll([
      dayKey(today),
      dayKey(addDays(today, -1)),
      dayKey(addDays(today, -2)),
      dayKey(addDays(today, -40)),
    ]);
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
  test('saját kihívás: egyéni napszám, saját kép (négyzetre vágva, kicsire) és emoji mentése', () async {
    final db = FakeFirebaseFirestore();
    final gabi = Challenges(db: db)..start('gabi', await device('Gabi'));
    final photo = img.Image(width: 1200, height: 600);
    img.fill(photo, color: img.ColorRgb8(200, 80, 60));
    final icon = prepareChallengeIcon(Uint8List.fromList(img.encodePng(photo)));
    final decoded = img.decodeJpg(base64Decode(icon))!;
    expect([decoded.width, decoded.height], [192, 192]);
    expect(icon.length, lessThan(20000));
    expect(() => prepareChallengeIcon(Uint8List.fromList([1, 2, 3])), throwsFormatException);

    await gabi.create(title: 'Saját 100 nap', emoji: '🏆', days: 100, start: DateTime.now(), friends: {}, image: icon);
    await gabi.create(title: 'Csak emoji', emoji: '🔥', days: 10, start: DateTime.now(), friends: {});
    final list = {for (final c in await gabi.watchMine().first) c.title: c};
    expect(list['Saját 100 nap']!.days, 100);
    expect(list['Saját 100 nap']!.image, icon);
    expect(list['Csak emoji']!.image, isEmpty);
    expect(list['Csak emoji']!.emoji, '🔥');
    gabi.stop();
  });

  test('közös cél: megosztás, csatlakozás saját céllal, pipák átmennek, a kihívások közt nincs', () async {
    final db = FakeFirebaseFirestore();
    final gabiStore = await device('Gabi');
    final annaStore = await device('Anna');
    final gabi = Challenges(db: db)..start('gabi', gabiStore);
    final anna = Challenges(db: db)..start('anna', annaStore);
    final today = DateTime.now();

    gabiStore.addHabit('🚶 10 perc séta');
    final h = gabiStore.habits.single;
    gabiStore.toggleHabit(h, today);
    await gabi.shareGoal(h, {'anna': 'Anna'});

    final invite = (await anna.watchSharedGoals().first).single;
    expect(invite.isGoal, isTrue);
    expect(invite.title, '🚶 10 perc séta');
    expect(invite.names[invite.ownerUid], 'Gabi');
    expect(await gabi.watchSharedGoals().first, hasLength(1));

    // Anna csatlakozik: saját célja lesz, a pipája megjelenik Gabinál.
    await anna.joinSharedGoal(invite);
    expect(annaStore.habits.single.name, '🚶 10 perc séta');
    expect(annaStore.challengeHabits[invite.id], annaStore.habits.single.id);
    annaStore.toggleHabit(annaStore.habits.single, today);
    await anna.syncLinkedHabits();

    final progress = await gabi.watchProgress(invite.id).first;
    expect(progress.firstWhere((p) => p.uid == 'anna').done, {dayKey(today)});
    expect(progress.firstWhere((p) => p.uid == 'gabi').done, {dayKey(today)});

    // Gabi leállítja: törlődik mindkettőjüknél.
    await gabi.delete((await gabi.get(invite.id))!);
    expect(await anna.watchSharedGoals().first, isEmpty);
    expect(gabiStore.challengeHabits, isEmpty);
    gabi.stop();
    anna.stop();
  });
}
