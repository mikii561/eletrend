import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
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

  /// A neved, ahogy a barátaid látják a meghívásoknál és az üzenőfalon.
  String myName = '';

  /// Programok, ahová meghívtak.
  List<Invite> invites = [];

  /// Hangulatcímkék a felhasználó sorrendjében.
  List<MoodTag> moodTags = [];

  /// Az 1–5 hangulat arca és felirata (emoji vagy saját kép).
  List<MoodTag> moodFaces = [];

  // Emlékeztetők beállításai
  bool dailyReminder = true;
  TimeOfDay reminderTime = const TimeOfDay(hour: 20, minute: 0);
  bool eventReminders = true;

  /// Megjelenés: a telefon beállítása szerint, mindig világos vagy mindig sötét.
  ThemeMode themeMode = ThemeMode.system;

  /// Végigment-e már a bemutatón.
  bool onboarded = false;

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
    myName = _prefs.getString('myName') ?? '';
    invites = list('invites').map(Invite.fromJson).toList();
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
    themeMode = ThemeMode.values.asNameMap()[_prefs.getString('themeMode')] ?? ThemeMode.system;
    onboarded = _prefs.getBool('onboarded') ?? false;
  }

  /// Újraolvas mindent a tárhelyről (pl. ha a widget közben módosított).
  Future<void> reload() async {
    await _prefs.reload();
    _read();
    notifyListeners();
  }

  void _save() {
    _prefs.setString('events', jsonEncode(events.map((e) => e.toJson()).toList()));
    _prefs.setString('habits', jsonEncode(habits.map((h) => h.toJson()).toList()));
    _prefs.setString('journal', jsonEncode(journal.map((j) => j.toJson()).toList()));
    _prefs.setStringList('friends', friends);
    _prefs.setString('myName', myName);
    _prefs.setString('invites', jsonEncode(invites.map((i) => i.toJson()).toList()));
    _prefs.setString('moodTags', jsonEncode(moodTags.map((t) => t.toJson()).toList()));
    _prefs.setString('moodFaces', jsonEncode(moodFaces.map((t) => t.toJson()).toList()));
    _prefs.setBool('dailyReminder', dailyReminder);
    _prefs.setInt('reminderHour', reminderTime.hour);
    _prefs.setInt('reminderMinute', reminderTime.minute);
    _prefs.setBool('eventReminders', eventReminders);
    _prefs.setString('themeMode', themeMode.name);
    _prefs.setBool('onboarded', onboarded);
    notifyListeners();
  }

  // Emlékeztetők

  void setReminders({bool? daily, TimeOfDay? time, bool? events}) {
    dailyReminder = daily ?? dailyReminder;
    reminderTime = time ?? reminderTime;
    eventReminders = events ?? eventReminders;
    _save();
  }

  // Felhő (fiók)

  /// A fiókhoz mentett beállítások és kisebb listák egy dokumentumban.
  Map<String, dynamic> cloudSettings() => {
        'friends': friends,
        'myName': myName,
        'invites': invites.map((i) => i.toJson()).toList(),
        'dailyReminder': dailyReminder,
        'reminderHour': reminderTime.hour,
        'reminderMinute': reminderTime.minute,
        'eventReminders': eventReminders,
        'themeMode': themeMode.name,
        'onboarded': onboarded,
      };

  /// A fiókból letöltött adatok kerülnek az eszközön lévők helyére.
  void applyCloud({
    required List<Event> events,
    required List<Habit> habits,
    required List<JournalEntry> journal,
    required List<MoodTag> moodTags,
    required List<MoodTag> moodFaces,
    Map<String, dynamic>? settings,
  }) {
    this.events = events;
    this.habits = habits;
    this.journal = journal..sort((a, b) => b.date.compareTo(a.date));
    if (moodTags.isNotEmpty) this.moodTags = moodTags;
    if (moodFaces.length == 5) {
      this.moodFaces = moodFaces..sort((a, b) => a.id.compareTo(b.id));
    }
    if (settings != null) {
      friends = List<String>.from(settings['friends'] as List? ?? []);
      myName = settings['myName'] as String? ?? myName;
      invites = [for (final i in settings['invites'] as List? ?? []) Invite.fromJson(i as Map<String, dynamic>)];
      dailyReminder = settings['dailyReminder'] as bool? ?? dailyReminder;
      reminderTime = TimeOfDay(
        hour: settings['reminderHour'] as int? ?? reminderTime.hour,
        minute: settings['reminderMinute'] as int? ?? reminderTime.minute,
      );
      eventReminders = settings['eventReminders'] as bool? ?? eventReminders;
      themeMode = ThemeMode.values.asNameMap()[settings['themeMode']] ?? themeMode;
      onboarded = settings['onboarded'] as bool? ?? true;
    }
    _save();
  }

  /// Melyik fiókhoz szinkronizált utoljára ez az eszköz.
  String? get syncUid => _prefs.getString('syncUid');

  /// A legutóbb szinkronizált elemek ujjlenyomatai (csak ha ugyanahhoz a fiókhoz tartoznak).
  Map<String, String> syncHashesFor(String uid) {
    if (syncUid != uid) return {};
    final raw = _prefs.getString('syncHashes');
    return raw == null ? {} : Map<String, String>.from(jsonDecode(raw) as Map);
  }

  void saveSyncHashes(String uid, Map<String, String> hashes) {
    _prefs.setString('syncUid', uid);
    _prefs.setString('syncHashes', jsonEncode(hashes));
  }

  /// Kijelentkezéskor minden adat lekerül erről az eszközről (a fiókban megmaradnak).
  Future<void> clearAll() async {
    for (final k in [..._backupKeys, 'pinHash', 'pinSalt', 'useBiometrics', 'syncUid', 'syncHashes']) {
      await _prefs.remove(k);
    }
    journalUnlocked = false;
    _read();
    notifyListeners();
  }

  // Napló zárolása

  /// Be van-e kapcsolva a napló PIN-kódos zárolása.
  bool get journalLocked => _prefs.getString('pinHash') != null;

  /// Ujjlenyomattal is feloldható-e (csak telefonon).
  bool get useBiometrics => _prefs.getBool('useBiometrics') ?? false;

  /// Ebben a munkamenetben fel van-e oldva; nem mentjük, újraindításkor zárt.
  bool journalUnlocked = false;

  bool get journalVisible => !journalLocked || journalUnlocked;

  static String _hash(String salt, String pin) => sha256.convert(utf8.encode('$salt:$pin')).toString();

  /// A PIN-t csak sózott hash-ként tároljuk.
  void setPin(String pin) {
    final random = Random.secure();
    final salt = base64Encode([for (var i = 0; i < 16; i++) random.nextInt(256)]);
    _prefs.setString('pinSalt', salt);
    _prefs.setString('pinHash', _hash(salt, pin));
    journalUnlocked = true;
    notifyListeners();
  }

  bool checkPin(String pin) {
    final salt = _prefs.getString('pinSalt');
    return salt != null && _prefs.getString('pinHash') == _hash(salt, pin);
  }

  void setUseBiometrics(bool on) {
    _prefs.setBool('useBiometrics', on);
    notifyListeners();
  }

  void clearPin() {
    _prefs.remove('pinHash');
    _prefs.remove('pinSalt');
    _prefs.remove('useBiometrics');
    notifyListeners();
  }

  void unlockJournal() {
    journalUnlocked = true;
    notifyListeners();
  }

  /// Az app háttérbe kerülésekor újra zárunk.
  void lockJournal() {
    if (!journalUnlocked) return;
    journalUnlocked = false;
    notifyListeners();
  }

  /// Elfelejtett PIN: a zár csak a naplóbejegyzésekkel együtt törölhető.
  void resetLockAndJournal() {
    journal.clear();
    clearPin();
    _save();
  }

  // Biztonsági mentés

  /// Ezek a beállítások kerülnek a mentésbe (a zárolás PIN-kódja szándékosan nem).
  static const _backupKeys = [
    'events', 'habits', 'journal', 'friends', 'moodTags', 'moodFaces',
    'dailyReminder', 'reminderHour', 'reminderMinute', 'eventReminders', 'themeMode', 'onboarded',
    'myName', 'invites',
  ];

  /// Minden adat egy JSON-szövegben, fájlba mentéshez.
  String exportBackup() {
    _save();
    return const JsonEncoder.withIndent(' ').convert({
      'app': 'eletrend',
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'data': {for (final k in _backupKeys) if (_prefs.containsKey(k)) k: _prefs.get(k)},
    });
  }

  /// Visszatölt egy mentést, a mostani adatok helyére.
  /// [FormatException]-t dob, ha a fájl nem Életrend-mentés vagy sérült.
  Future<void> importBackup(String text) async {
    final Map<String, dynamic> data;
    try {
      final root = jsonDecode(text) as Map<String, dynamic>;
      if (root['app'] != 'eletrend') throw const FormatException();
      data = root['data'] as Map<String, dynamic>;
      // Először csak ellenőrizzük, hogy minden beolvasható, és csak utána írunk.
      for (final k in ['events', 'habits', 'journal', 'moodTags', 'moodFaces']) {
        final raw = data[k];
        if (raw == null) continue;
        final list = jsonDecode(raw as String) as List;
        final parse = switch (k) {
          'events' => Event.fromJson,
          'habits' => Habit.fromJson,
          'journal' => JournalEntry.fromJson,
          _ => MoodTag.fromJson,
        };
        for (final item in list) {
          parse(item as Map<String, dynamic>);
        }
      }
    } catch (_) {
      throw const FormatException('Ez nem Életrend-mentés, vagy a fájl sérült.');
    }
    for (final k in _backupKeys) {
      await _prefs.remove(k);
      final v = data[k];
      switch (v) {
        case String():
          await _prefs.setString(k, v);
        case bool():
          await _prefs.setBool(k, v);
        case int():
          await _prefs.setInt(k, v);
        case List():
          await _prefs.setStringList(k, v.cast<String>());
      }
    }
    _read();
    notifyListeners();
  }

  /// A bemutató csak egy teljesen új, üres appnál jelenik meg.
  bool get needsOnboarding => !onboarded && habits.isEmpty && journal.isEmpty && events.isEmpty;

  /// A bemutató vége: a kiválasztott ajánlott szokások felvétele.
  void finishOnboarding({List<String> habits = const []}) {
    for (final name in habits) {
      this.habits.add(Habit(id: '${newId()}-${this.habits.length}', name: name));
    }
    onboarded = true;
    _save();
  }

  void setThemeMode(ThemeMode mode) {
    themeMode = mode;
    _save();
  }

  /// Ma még hány szokás nincs kipipálva.
  int get habitsLeftToday => habits.where((h) => !h.isDoneOn(DateTime.now())).length;

  bool get journalDoneToday => entryFor(DateTime.now()) != null;

  // Programok

  /// A mai és későbbi programok a következő alkalmuk szerint; az ismétlődők mindig benne vannak.
  List<Event> get upcomingEvents {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    return events.where((e) => !e.nextDate(today).isBefore(start)).toList()
      ..sort((a, b) => a.nextDate(today).compareTo(b.nextDate(today)));
  }

  /// Új programot felvesz, meglévőt (ugyanaz az objektum) csak elment.
  void saveEvent(Event e) {
    // Azonosító szerint, mert a felhőből frissítés után ugyanaz a program új példány lehet.
    final i = events.indexWhere((x) => x.id == e.id);
    i < 0 ? events.add(e) : events[i] = e;
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

  void setMyName(String name) {
    myName = name.trim();
    _save();
  }

  /// Megjegyzi a meghívást (vagy frissíti a címét, időpontját).
  void saveInvite(Invite invite) {
    invites.removeWhere((i) => i.id == invite.id);
    invites.add(invite);
    invites.sort((a, b) => a.date.compareTo(b.date));
    _save();
  }

  void removeInvite(String id) {
    invites.removeWhere((i) => i.id == id);
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
