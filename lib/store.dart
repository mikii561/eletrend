import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// Az app teljes állapota, a telefonon helyben tárolva.
class AppStore extends ChangeNotifier {
  AppStore._(this._prefs);

  final SharedPreferences _prefs;

  List<Event> events = [];
  List<Habit> habits = [];
  List<JournalEntry> journal = [];
  List<String> friends = [];

  // Emlékeztetők beállításai
  bool dailyReminder = true;
  TimeOfDay reminderTime = const TimeOfDay(hour: 20, minute: 0);
  bool eventReminders = true;

  static Future<AppStore> load() async {
    final store = AppStore._(await SharedPreferences.getInstance());
    store._read();
    return store;
  }

  void _read() {
    List<Map<String, dynamic>> list(String key) {
      final raw = _prefs.getString(key);
      if (raw == null) return [];
      return List<Map<String, dynamic>>.from(jsonDecode(raw) as List);
    }

    events = list('events').map(Event.fromJson).toList();
    habits = list('habits').map(Habit.fromJson).toList();
    journal = list('journal').map(JournalEntry.fromJson).toList();
    friends = _prefs.getStringList('friends') ?? [];
    dailyReminder = _prefs.getBool('dailyReminder') ?? true;
    reminderTime = TimeOfDay(
      hour: _prefs.getInt('reminderHour') ?? 20,
      minute: _prefs.getInt('reminderMinute') ?? 0,
    );
    eventReminders = _prefs.getBool('eventReminders') ?? true;
  }

  void _save() {
    _prefs.setString('events', jsonEncode(events.map((e) => e.toJson()).toList()));
    _prefs.setString('habits', jsonEncode(habits.map((h) => h.toJson()).toList()));
    _prefs.setString('journal', jsonEncode(journal.map((j) => j.toJson()).toList()));
    _prefs.setStringList('friends', friends);
    _prefs.setBool('dailyReminder', dailyReminder);
    _prefs.setInt('reminderHour', reminderTime.hour);
    _prefs.setInt('reminderMinute', reminderTime.minute);
    _prefs.setBool('eventReminders', eventReminders);
    notifyListeners();
  }

  // Emlékeztetők

  void setReminders({bool? daily, TimeOfDay? time, bool? events}) {
    dailyReminder = daily ?? dailyReminder;
    reminderTime = time ?? reminderTime;
    eventReminders = events ?? eventReminders;
    _save();
  }

  /// Ma még hány szokás nincs kipipálva.
  int get habitsLeftToday => habits.where((h) => !h.isDoneOn(DateTime.now())).length;

  bool get journalDoneToday => entryFor(DateTime.now()) != null;

  // Programok

  List<Event> get upcomingEvents {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    return events.where((e) => !e.date.isBefore(start)).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  /// Új programot felvesz, meglévőt (ugyanaz az objektum) csak elment.
  void saveEvent(Event e) {
    if (!events.contains(e)) events.add(e);
    _save();
  }

  void removeEvent(Event e) {
    events.remove(e);
    _save();
  }

  // Barátok

  void addFriend(String name) {
    name = name.trim();
    if (name.isEmpty || friends.contains(name)) return;
    friends.add(name);
    friends.sort();
    _save();
  }

  void removeFriend(String name) {
    friends.remove(name);
    _save();
  }

  // Szokások

  void addHabit(String name) {
    habits.add(Habit(id: newId(), name: name.trim()));
    _save();
  }

  void removeHabit(Habit h) {
    habits.remove(h);
    _save();
  }

  void toggleHabit(Habit h, [DateTime? day]) {
    final key = dayKey(day ?? DateTime.now());
    if (!h.doneDays.remove(key)) h.doneDays.add(key);
    _save();
  }

  // Napló

  JournalEntry? entryFor(DateTime day) {
    final key = dayKey(day);
    for (final j in journal) {
      if (dayKey(j.date) == key) return j;
    }
    return null;
  }

  /// Naponta egy bejegyzés: ha az adott napra már van, felülírja.
  void saveEntry(JournalEntry entry) {
    journal.removeWhere((j) => dayKey(j.date) == dayKey(entry.date));
    journal.add(entry);
    journal.sort((a, b) => b.date.compareTo(a.date));
    _save();
  }

  void removeEntry(JournalEntry entry) {
    journal.remove(entry);
    _save();
  }
}

/// A store elérése a widgetfából: `StoreScope.of(context)`.
class StoreScope extends InheritedNotifier<AppStore> {
  const StoreScope({super.key, required AppStore store, required super.child})
      : super(notifier: store);

  static AppStore of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<StoreScope>()!.notifier!;
}
