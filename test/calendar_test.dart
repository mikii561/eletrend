import 'package:eletrend/formatting.dart';
import 'package:eletrend/models.dart';
import 'package:eletrend/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AppStore> emptyStore([Map<String, Object> prefs = const {}]) {
  SharedPreferences.resetStatic();
  SharedPreferences.setMockInitialValues(prefs);
  return AppStore.load();
}

void main() {
  setUpAll(() => initializeDateFormatting('hu'));

  group('ismétlődő bejegyzések', () {
    // 2026. október 1. csütörtök
    final foci = Event(
      id: '1',
      title: 'Foci',
      start: DateTime(2026, 10, 1, 18),
      durationMin: 90,
      repeat: Repeat.weekly,
    );

    test('alkalmak egy időszakban, ugyanazon a napon és órában', () {
      final occ = foci.occurrencesBetween(DateTime(2026, 10, 26), DateTime(2026, 11, 9));
      expect(occ.map((o) => o.start), [DateTime(2026, 10, 29, 18), DateTime(2026, 11, 5, 18)]);
      expect(occ.first.end, DateTime(2026, 10, 29, 19, 30));
      expect(foci.occurrencesBetween(DateTime(2026, 9, 1), DateTime(2026, 9, 30)), isEmpty); // az első előtt
    });

    test('a következő alkalom: ami még tart, az is', () {
      expect(foci.nextOccurrence(DateTime(2026, 10, 29, 19))!.start, DateTime(2026, 10, 29, 18));
      expect(foci.nextOccurrence(DateTime(2026, 10, 29, 20))!.start, DateTime(2026, 11, 5, 18));
    });

    test('egy alkalom kihagyása („csak ezt törlöm”)', () {
      final e = Event(id: '2', title: 'Edzés', start: DateTime(2026, 10, 1, 7), repeat: Repeat.daily)
        ..skipped.add('2026-10-03');
      final days = e.occurrencesBetween(DateTime(2026, 10, 2), DateTime(2026, 10, 5)).map((o) => o.start.day);
      expect(days, [2, 4]);
    });

    test('havonta: rövidebb hónapban az utolsó napra esik; évente is', () {
      final e = Event(id: '3', title: 'Klub', start: DateTime(2026, 1, 31, 19), repeat: Repeat.monthly);
      expect(e.occurrencesBetween(DateTime(2026, 2, 1), DateTime(2026, 3, 1)).single.start, DateTime(2026, 2, 28, 19));
      final day = Event(
        id: '4',
        title: 'Évforduló',
        start: DateTime(2024, 2, 29),
        allDay: true,
        durationMin: 1440,
        repeat: Repeat.yearly,
      );
      expect(day.occurrencesBetween(DateTime(2027, 2, 1), DateTime(2027, 3, 1)).single.start, DateTime(2027, 2, 28));
    });

    test('régen indult napi ismétlődésnél is gyors (nem az elejétől számol)', () {
      final e = Event(id: '5', title: 'Séta', start: DateTime(2000, 1, 1, 8), repeat: Repeat.daily);
      final sw = Stopwatch()..start();
      for (var i = 0; i < 50; i++) {
        e.occurrencesBetween(DateTime(2026, 10, 1), DateTime(2026, 11, 1));
      }
      expect(e.occurrencesBetween(DateTime(2026, 10, 1), DateTime(2026, 11, 1)), hasLength(31));
      // Az elejétől számolva (26 év napjai, alkalmanként) ez sok másodperc lenne; így jóval alatta marad,
      // akkor is, ha a gép épp sok tesztet futtat párhuzamosan.
      expect(sw.elapsedMilliseconds, lessThan(2000));
    });

    test('éjfélen átnyúló bejegyzés mindkét napon látszik', () async {
      final store = await emptyStore();
      store.saveEvent(Event(id: 'n', title: 'Buli', start: DateTime(2026, 11, 7, 22), durationMin: 240));
      expect(store.occurrencesOn(DateTime(2026, 11, 7)), hasLength(1));
      expect(store.occurrencesOn(DateTime(2026, 11, 8)), hasLength(1));
      expect(store.occurrencesOn(DateTime(2026, 11, 9)), isEmpty);
    });
  });

  test('régi (Életrend) program beolvasása: közösségi, kétórás, emlékeztetővel', () {
    final e = Event.fromJson({
      'id': 'x',
      'title': 'Mozi',
      'date': '2026-10-01T18:00:00.000',
      'invited': ['Anna'],
      'expenses': [],
    });
    expect(e.category, EventCategory.social);
    expect(e.durationMin, 120);
    expect(e.reminderMin, 60);
    expect(Event.fromJson(e.toJson()).toJson(), e.toJson());
  });

  group('feladatok', () {
    test('mai lista: lejárt, mai határidős, beosztott; a kész a végére kerül', () async {
      final store = await emptyStore();
      final now = DateTime(2026, 11, 3, 10);
      store
        ..saveTask(TaskItem(id: 'a', title: 'Lejárt', due: DateTime(2026, 11, 1, 12)))
        ..saveTask(TaskItem(id: 'b', title: 'Ma', due: DateTime(2026, 11, 3, 12)))
        ..saveTask(TaskItem(id: 'c', title: 'Beosztva', scheduled: DateTime(2026, 11, 3, 14)))
        ..saveTask(TaskItem(id: 'd', title: 'Holnap', due: DateTime(2026, 11, 4, 12)))
        ..saveTask(TaskItem(id: 'e', title: 'Nincs határidő'));
      expect(store.tasksOn(now, now: now).map((t) => t.title), ['Lejárt', 'Ma', 'Beosztva']);
      store.toggleTask(store.tasks.firstWhere((t) => t.id == 'b'));
      expect(store.tasksOn(now, now: now).last.title, 'Ma');
      expect(store.tasks.firstWhere((t) => t.id == 'b').doneAt, isNotNull);
      expect(store.openTasks.map((t) => t.id), ['a', 'c', 'd', 'e']);
      expect(TaskItem.fromJson(store.tasks.first.toJson()).toJson(), store.tasks.first.toJson());
    });

    test('a beosztott feladat és a foglaltnak jelölt bejegyzés foglalt időnek számít', () async {
      final store = await emptyStore();
      store
        ..saveTask(TaskItem(id: 't', title: 'Írás', scheduled: DateTime(2026, 11, 3, 9), durationMin: 60))
        ..saveEvent(Event(id: 'e', title: 'Fogorvos', start: DateTime(2026, 11, 3, 13)))
        ..saveEvent(
          Event(id: 's', title: 'Szülinap', start: DateTime(2026, 11, 3), allDay: true, durationMin: 1440, busy: false),
        );
      final busy = store.busyIntervals(DateTime(2026, 11, 3), DateTime(2026, 11, 4));
      expect(busy.map((i) => i.start.toLocal().hour).toList()..sort(), [9, 13]);
      expect(store.statusAt(DateTime(2026, 11, 3, 13, 30)), AvailabilityStatus.busy);
      expect(store.statusAt(DateTime(2026, 11, 3, 15)), AvailabilityStatus.available);
      store.setManualStatus(AvailabilityStatus.open, until: DateTime(2026, 11, 4));
      expect(store.statusAt(DateTime(2026, 11, 3, 13, 30)), AvailabilityStatus.open);
      expect(store.statusAt(DateTime(2026, 11, 4, 13, 30)), AvailabilityStatus.available);
    });
  });

  test('export és visszatöltés: minden saját adat visszajön, más fájlt nem fogad el', () async {
    final store = await emptyStore();
    store
      ..addHabit('Séta')
      ..saveTask(TaskItem(id: 't', title: 'Bevásárlás', due: DateTime(2026, 11, 4, 12)))
      ..saveEvent(Event(id: 'e', title: 'Mozi', start: DateTime(2026, 11, 7, 20), category: EventCategory.social))
      ..saveGroup(FriendGroup(id: 'g', name: 'Család', members: ['u1']))
      ..setMyName('Gabi')
      ..setThemeMode(ThemeMode.dark);
    final text = store.exportData();

    final other = await emptyStore();
    expect(() => other.importData('{"app":"valami"}'), throwsFormatException);
    other.importData(text);
    expect(other.habits.single.name, 'Séta');
    expect(other.tasks.single.title, 'Bevásárlás');
    expect(other.events.single.category, EventCategory.social);
    expect(other.groups.single.members, ['u1']);
    expect(other.myName, 'Gabi');
    expect(other.themeMode, ThemeMode.dark);
  });

  test('frissítés a régi változatról: a név, a téma és a programok megmaradnak', () async {
    final store = await emptyStore({
      'myName': 'Gabi',
      'themeMode': 'dark',
      'onboarded': true,
      'events': '[{"id":"1","title":"Foci","date":"2026-10-01T18:00:00.000","repeat":"weekly"}]',
    });
    expect(store.myName, 'Gabi');
    expect(store.themeMode, ThemeMode.dark);
    expect(store.needsOnboarding, isFalse);
    expect(store.events.single.repeat, Repeat.weekly);
  });

  test('Főoldal kártyák: a sorrend és az elrejtés megmarad', () async {
    final store = await emptyStore();
    store.moveCardTo(store.homeCards.indexOf(HomeCard.week), 0);
    store.setCardVisible(HomeCard.goals, false);
    final saved = (await SharedPreferences.getInstance()).getString('settings')!;
    final again = await emptyStore({'settings': saved});
    expect(again.homeCards.first, HomeCard.week);
    expect(again.showsCard(HomeCard.goals), isFalse);
    expect(again.homeCards.toSet(), HomeCard.values.toSet());
  });

  test('magyar kiírás: időtartam, ismétlődés, emlékeztető, születésnap', () {
    expect(formatDuration(45), '45 perc');
    expect(formatDuration(90), '1 óra 30 perc');
    expect(formatRange(DateTime(2026, 1, 1, 18), DateTime(2026, 1, 1, 20)), '18:00–20:00');
    expect(repeatLabel(Repeat.weekly, DateTime(2026, 10, 1)), 'Hetente, csütörtökönként');
    expect(reminderLabel(30), '30 perccel előtte');
    expect(reminderLabel(60), '1 órával előtte');
    expect(reminderLabel(null), 'Nincs értesítés');
    expect(nextBirthdayOf('02-29', DateTime(2027, 2, 1)), DateTime(2027, 2, 28, 12));
    expect(nextBirthdayOf('03-01', DateTime(2027, 3, 1, 15)), DateTime(2027, 3, 1, 12)); // ma is számít
  });
}
