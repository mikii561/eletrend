import 'package:eletrend/badges.dart';
import 'package:eletrend/models.dart';
import 'package:eletrend/store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('jelvények: sorozat, első lépések; a „látott” lista megmarad', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await AppStore.load();
    expect(earnedBadges(store), isEmpty);

    store.addHabit('Séta');
    for (var i = 0; i < 7; i++) {
      store.habits.single.doneDays.add(dayKey(DateTime(2026, 9, 1 + i)));
    }
    store.saveEntry(JournalEntry(id: '1', date: DateTime(2026, 10, 1), mood: 4));
    final earned = earnedBadges(store);
    expect(earned, containsAll(['first_habit', 'habit_7', 'first_entry']));
    expect(earned, isNot(contains('habit_30')));
    expect(earned, isNot(contains('journal_7')));

    expect(store.seenBadges, isNull);
    store.markBadgesSeen(earned);
    expect((await AppStore.load()).seenBadges, earned);
  });

  test('teljes hónap: egy lezárt hónap minden napján írtál', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await AppStore.load();
    for (var d = 1; d <= 30; d++) {
      store.saveEntry(JournalEntry(id: '$d', date: DateTime(2025, 9, d, 12), mood: 3));
    }
    final earned = earnedBadges(store);
    expect(earned, containsAll(['full_month', 'journal_30', 'journal_7']));
  });
}
