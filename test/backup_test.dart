import 'package:eletrend/models.dart';
import 'package:eletrend/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('mentés és visszatöltés: minden adat visszajön', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await AppStore.load();
    store.addHabit('Séta');
    store.addFriend('Anna');
    store.saveEntry(JournalEntry(id: '1', date: DateTime(2026, 10, 27), mood: 5, gratitude: 'napsütés')..tags = ['nyugodt']);
    store.addTag(name: 'kalandvágyó', emoji: '🧗');
    store.updateTag(store.moodFace(1)..name = 'Pocsék');
    store.setThemeMode(ThemeMode.dark);
    final backup = store.exportBackup();

    // Új, üres eszköz
    SharedPreferences.setMockInitialValues({});
    final other = await AppStore.load();
    await other.importBackup(backup);
    expect(other.habits.single.name, 'Séta');
    expect(other.friends, ['Anna']);
    expect(other.entryFor(DateTime(2026, 10, 27))!.gratitude, 'napsütés');
    expect(other.moodTags.last.name, 'kalandvágyó');
    expect(other.moodFace(1).name, 'Pocsék');
    expect(other.themeMode, ThemeMode.dark);
    // Újraindítás után is megmarad
    expect((await AppStore.load()).habits.single.name, 'Séta');
  });

  test('hibás fájlnál nem nyúl a meglévő adatokhoz', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await AppStore.load();
    store.addHabit('Víz');
    await expectLater(store.importBackup('{"app":"valami más"}'), throwsFormatException);
    await expectLater(store.importBackup('{"app":"eletrend","data":{"habits":"[{\\"x\\":1}]"}}'), throwsFormatException);
    await expectLater(store.importBackup('nem json'), throwsFormatException);
    expect(store.habits.single.name, 'Víz');
  });
}
