import 'package:eletrend/habits_widget.dart';
import 'package:eletrend/store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('widget adatai: legfeljebb 5 szokás, a mai állapottal', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await AppStore.load();
    for (var i = 1; i <= 7; i++) {
      store.addHabit('Szokás $i');
    }
    final now = DateTime(2026, 10, 28, 9);
    store.toggleHabit(store.habits[1], now);

    final data = HabitsWidget.widgetData(store, now);
    expect(data['day'], '2026-10-28');
    expect(data['count'], 5);
    expect(data['habit0_name'], 'Szokás 1');
    expect(data['habit0_done'], isFalse);
    expect(data['habit1_done'], isTrue);
    expect(data.containsKey('habit5_name'), isFalse);
  });

  test('koppintás a widgeten kipipálja a szokást (és visszavonja)', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await AppStore.load();
    store.addHabit('Séta');
    final id = store.habits.first.id;

    await habitsWidgetCallback(Uri.parse('eletrend://toggle?id=${Uri.encodeQueryComponent(id)}'));
    await store.reload();
    expect(store.habits.first.isDoneOn(DateTime.now()), isTrue);

    await habitsWidgetCallback(Uri.parse('eletrend://toggle?id=$id'));
    await store.reload();
    expect(store.habits.first.isDoneOn(DateTime.now()), isFalse);
  });
}
