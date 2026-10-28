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

  /// Hangulatcímkék a felhasználó sorrendjében.
  List<MoodTag> moodTags = [];

  /// Az 1–5 hangulat arca és felirata (emoji vagy saját kép).
  List<MoodTag> moodFaces = [];

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
    moodTags = _prefs.containsKey('moodTags')
        ? list('moodTags').map(MoodTag.fromJson).toList()
        : [for (final t in defaultMoodTags.entries) MoodTag(id: t.key, name: t.key, emoji: t.value)];
    final faces = list('moodFaces').map(MoodTag.fromJson).toList();
    moodFaces = faces.length == 5 ? faces : [for (var i = 1; i <= 5; i++) defaultMoodFace(i)];
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
    _prefs.setString('moodTags', jsonEncode(moodTags.map((t) => t.toJson()).toList()));
    _prefs.setString('moodFaces', jsonEncode(moodFaces.map((t) => t.toJson()).toList()));
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

  // Hangulatcímkék

  /// A címke az azonosítója alapján; ismeretlennél egy helyettesítő.
  MoodTag tagFor(String id) {
    for (final t in moodTags) {
      if (t.id == id) return t;
    }
    return MoodTag(id: id, name: id);
  }

  List<MoodTag> get visibleTags => moodTags.where((t) => t.visible).toList();

  /// Van-e már ilyen nevű címke (kis- és nagybetűtől függetlenül).
  bool tagNameTaken(String name, {MoodTag? except}) =>
      moodTags.any((t) => t != except && t.name.toLowerCase() == name.trim().toLowerCase());

  MoodTag addTag({required String name, required String emoji, String? image}) {
    final tag = MoodTag(id: 'sajat-${newId()}', name: name.trim(), emoji: emoji, image: image);
    moodTags.add(tag);
    _save();
    return tag;
  }

  /// Egy címke módosítása után (név, emoji, kép, láthatóság) menti a változást.
  void updateTag(MoodTag tag) => _save();

  void moveTag(int from, int to) {
    moodTags.insert(to, moodTags.removeAt(from));
    _save();
  }

  /// Hány bejegyzésben szerepel a címke.
  int tagUsage(MoodTag tag) => journal.where((j) => j.tags.contains(tag.id)).length;

  // Hangulatok (1–5)

  MoodTag moodFace(int mood) => moodFaces[mood - 1];

  /// Egy hangulat arcának visszaállítása az alapra.
  void resetMoodFace(int mood) {
    moodFaces[mood - 1] = defaultMoodFace(mood);
    _save();
  }

  /// Törli a címkét, és kiveszi a bejegyzésekből is.
  void removeTag(MoodTag tag) {
    moodTags.remove(tag);
    for (final j in journal) {
      j.tags.remove(tag.id);
    }
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
