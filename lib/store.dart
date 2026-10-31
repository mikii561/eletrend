import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'availability.dart';
import 'models.dart';
import 'tips.dart' show tipEveryDays;

export 'availability.dart' show AvailabilityShare, AvailabilityStatus, FreeWindow;

/// A Főoldal kártyái; a sorrendjük és a láthatóságuk állítható.
enum HomeCard {
  schedule('Mai beosztás', Icons.view_agenda_outlined),
  tasks('Teendők mára', Icons.task_alt),
  goals('Célok', Icons.flag_outlined),
  friends('Ki ér rá?', Icons.people_alt_outlined),
  birthdays('Születésnapok', Icons.cake_outlined),
  challenges('Kihívások', Icons.emoji_events_outlined),
  memories('Emlékek', Icons.photo_library_outlined),
  week('A heted', Icons.insights_outlined);

  const HomeCard(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// Az app teljes állapota, a telefonon helyben tárolva (és a fiókkal szinkronizálva).
class AppStore extends ChangeNotifier {
  AppStore._(this._prefs);

  final SharedPreferences _prefs;

  List<Event> events = [];
  List<TaskItem> tasks = [];
  List<Habit> habits = [];
  List<FriendGroup> groups = [];

  /// Programok, ahová meghívtak.
  List<Invite> invites = [];

  /// A már megnyitott meghívások azonosítói (az olvasatlan-számlálóhoz).
  Set<String> seenInvites = {};

  /// A barátaim, ahogy legutóbb láttuk őket (offline is kell, és a születésnap-emlékeztetőhöz).
  List<FriendInfo> friendsCache = [];

  /// A neved, ahogy a barátaid látják.
  String myName = '';

  /// Születésnap „ÉÉÉÉ-HH-NN” (null, ha nem adtad meg).
  String? birthday;

  // Adatvédelem

  /// Láthatják-e a barátaim a születésnapomat (csak hónap és nap).
  bool shareBirthday = false;

  /// Láthatják-e a barátaim a cél-sorozataimat (alapból nem).
  bool shareStreaks = false;

  /// Kik látják, mikor vagyok szabad (alapból senki: a megosztás önkéntes).
  AvailabilityShare shareAvailability = AvailabilityShare.nobody;

  /// [AvailabilityShare.groups] esetén mely csoportjaim.
  Set<String> shareGroups = {};

  /// Meghívhatnak-e a barátaim programokra egy gombnyomással.
  bool allowInvites = true;

  /// Mikor szoktam ráérni (a közös időpont kereséséhez).
  List<FreeWindow> freeWindows = [];

  /// Kézzel beállított állapot és meddig érvényes (null = a naptárból számoljuk).
  AvailabilityStatus? manualStatus;
  DateTime? manualStatusUntil;

  // Értesítések

  bool eventReminders = true;
  bool taskReminders = true;
  bool birthdayReminders = true;

  /// Szóljon-e, ha egy közös program évfordulója van (pl. ma 1 éve volt).
  bool memoryReminders = true;

  /// Új bejegyzés alapértelmezett emlékeztetője (perc; null = nincs).
  int? defaultReminderMin = 30;

  /// Megjelenés: a telefon beállítása szerint, mindig világos vagy mindig sötét.
  ThemeMode themeMode = ThemeMode.system;

  /// Végigment-e már a bevezetőn.
  bool onboarded = false;

  /// Látta-e már a Főoldal bemutatóját (fiókonként egyszer jön elő magától).
  bool tourDone = false;
  bool _tipsOn = true;

  /// Google Naptár: a kiválasztott naptárak (azonosító → név), a fiók, és mikor frissült utoljára.
  Map<String, String> googleCalendars = {};
  String? googleEmail;
  DateTime? googleSyncedAt;

  /// A Főoldal kártyái sorrendben, és amiket elrejtett.
  List<HomeCard> homeCards = [...HomeCard.values];
  Set<HomeCard> hiddenCards = {};

  /// Kihívás → hozzá kötött cél (a cél kipipálása a kihívásban is teljesít).
  Map<String, String> challengeHabits = {};

  static Future<AppStore> load() async {
    final store = AppStore._(await SharedPreferences.getInstance());
    store._read();
    return store;
  }

  List<Map<String, dynamic>> _list(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return [];
    return List<Map<String, dynamic>>.from(jsonDecode(raw) as List);
  }

  void _read() {
    events = _list('events').map(Event.fromJson).toList();
    tasks = _list('tasks').map(TaskItem.fromJson).toList();
    habits = _list('habits').map(Habit.fromJson).toList();
    groups = _list('groups').map(FriendGroup.fromJson).toList();
    invites = _list('invites').map(Invite.fromJson).toList();
    friendsCache = _list('friendsCache').map(FriendInfo.fromJson).toList();
    final raw = _prefs.getString('settings');
    _applySettings(raw == null ? _legacySettings() : jsonDecode(raw) as Map<String, dynamic>, local: true);
  }

  /// A régi (Életrend) változat külön kulcsokban tárolta a beállításokat; ezeket átvesszük,
  /// hogy frissítés után ne vesszen el a név, a téma és a többi.
  Map<String, dynamic> _legacySettings() => {
    'myName': ?_prefs.getString('myName'),
    'themeMode': ?_prefs.getString('themeMode'),
    'onboarded': ?_prefs.getBool('onboarded'),
    'shareStreaks': ?_prefs.getBool('shareStreaks'),
    'eventReminders': ?_prefs.getBool('eventReminders'),
    if (_prefs.getString('challengeHabits') case final links?) 'challengeHabits': jsonDecode(links),
  };

  /// Újraolvas mindent a tárhelyről.
  Future<void> reload() async {
    await _prefs.reload();
    _read();
    notifyListeners();
  }

  void _save() {
    _prefs.setString('events', jsonEncode(events.map((e) => e.toJson()).toList()));
    _prefs.setString('tasks', jsonEncode(tasks.map((t) => t.toJson()).toList()));
    _prefs.setString('habits', jsonEncode(habits.map((h) => h.toJson()).toList()));
    _prefs.setString('groups', jsonEncode(groups.map((g) => g.toJson()).toList()));
    _prefs.setString('invites', jsonEncode(invites.map((i) => i.toJson()).toList()));
    _prefs.setString('friendsCache', jsonEncode(friendsCache.map((f) => f.toJson()).toList()));
    _prefs.setString('settings', jsonEncode({...cloudSettings(), ..._deviceSettings()}));
    notifyListeners();
  }

  /// Ami csak ezen az eszközön számít (nem megy a felhőbe).
  Map<String, dynamic> _deviceSettings() => {
    if (manualStatus != null) 'manualStatus': manualStatus!.name,
    if (manualStatusUntil != null) 'manualStatusUntil': manualStatusUntil!.toIso8601String(),
  };

  /// A fiókhoz mentett beállítások egy dokumentumban.
  Map<String, dynamic> cloudSettings() => {
    'myName': myName,
    'birthday': birthday,
    'shareBirthday': shareBirthday,
    'shareStreaks': shareStreaks,
    'shareAvailability': shareAvailability.name,
    'shareGroups': shareGroups.toList()..sort(),
    'allowInvites': allowInvites,
    'freeWindows': [for (final w in freeWindows) w.toJson()],
    'eventReminders': eventReminders,
    'taskReminders': taskReminders,
    'birthdayReminders': birthdayReminders,
    'memoryReminders': memoryReminders,
    'defaultReminderMin': defaultReminderMin,
    'themeMode': themeMode.name,
    'onboarded': onboarded,
    'tourDone': tourDone,
    'tipsOn': _tipsOn,
    'googleCalendars': googleCalendars,
    'googleEmail': googleEmail,
    'googleSyncedAt': googleSyncedAt?.toIso8601String(),
    'homeCards': [for (final c in homeCards) c.name],
    'hiddenCards': [for (final c in hiddenCards) c.name]..sort(),
    'challengeHabits': challengeHabits,
    'invites': invites.map((i) => i.toJson()).toList(),
    'seenInvites': seenInvites.toList()..sort(),
  };

  void _applySettings(Map<String, dynamic> s, {bool local = false}) {
    myName = s['myName'] as String? ?? myName;
    birthday = s.containsKey('birthday') ? s['birthday'] as String? : birthday;
    shareBirthday = s['shareBirthday'] as bool? ?? shareBirthday;
    shareStreaks = s['shareStreaks'] as bool? ?? shareStreaks;
    shareAvailability = AvailabilityShare.values.asNameMap()[s['shareAvailability']] ?? shareAvailability;
    shareGroups = {for (final g in s['shareGroups'] as List? ?? shareGroups) g as String};
    allowInvites = s['allowInvites'] as bool? ?? allowInvites;
    if (s['freeWindows'] case final List w) {
      freeWindows = [for (final x in w) FreeWindow.fromJson(Map<String, dynamic>.from(x as Map))];
    }
    eventReminders = s['eventReminders'] as bool? ?? eventReminders;
    taskReminders = s['taskReminders'] as bool? ?? taskReminders;
    birthdayReminders = s['birthdayReminders'] as bool? ?? birthdayReminders;
    memoryReminders = s['memoryReminders'] as bool? ?? memoryReminders;
    if (s.containsKey('defaultReminderMin')) defaultReminderMin = (s['defaultReminderMin'] as num?)?.toInt();
    themeMode = ThemeMode.values.asNameMap()[s['themeMode']] ?? themeMode;
    onboarded = s['onboarded'] as bool? ?? (local ? onboarded : true);
    tourDone = s['tourDone'] as bool? ?? tourDone;
    _tipsOn = s['tipsOn'] as bool? ?? _tipsOn;
    if (s['googleCalendars'] case final Map g) googleCalendars = Map<String, String>.from(g);
    if (s.containsKey('googleEmail')) googleEmail = s['googleEmail'] as String?;
    if (s.containsKey('googleSyncedAt')) googleSyncedAt = DateTime.tryParse(s['googleSyncedAt'] as String? ?? '');
    if (s['homeCards'] case final List cards) {
      final order = [for (final c in cards) ?HomeCard.values.asNameMap()[c]];
      // Ha később új kártya jön, a végére kerül.
      homeCards = [
        ...order,
        for (final c in HomeCard.values)
          if (!order.contains(c)) c,
      ];
    }
    if (s['hiddenCards'] case final List hidden) {
      hiddenCards = {for (final c in hidden) ?HomeCard.values.asNameMap()[c]};
    }
    if (s['challengeHabits'] case final Map m) challengeHabits = Map<String, String>.from(m);
    if (s['seenInvites'] case final List seen) seenInvites = {for (final x in seen) x as String};
    if (s['invites'] case final List list) {
      invites = [for (final i in list) Invite.fromJson(Map<String, dynamic>.from(i as Map))];
    }
    if (local) {
      manualStatus = AvailabilityStatus.values.asNameMap()[s['manualStatus']];
      manualStatusUntil = DateTime.tryParse(s['manualStatusUntil'] as String? ?? '');
    }
  }

  /// A fiókból letöltött adatok kerülnek az eszközön lévők helyére.
  void applyCloud({
    required List<Event> events,
    required List<TaskItem> tasks,
    required List<Habit> habits,
    required List<FriendGroup> groups,
    Map<String, dynamic>? settings,
  }) {
    this.events = events;
    this.tasks = tasks;
    this.habits = habits;
    this.groups = groups;
    if (settings != null) _applySettings(settings);
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

  /// Egy-egy tipp-kártya, amit ezen az eszközön bezárt.
  bool hintClosed(String id) => _prefs.getBool('hint_$id') ?? false;

  void closeHint(String id) {
    _prefs.setBool('hint_$id', true);
    notifyListeners();
  }

  static const _dataKeys = ['events', 'tasks', 'habits', 'groups', 'invites', 'friendsCache', 'settings'];

  /// Kijelentkezéskor minden adat lekerül erről az eszközről (a fiókban megmaradnak).
  Future<void> clearAll() async {
    for (final k in [..._dataKeys, 'syncUid', 'syncHashes']) {
      await _prefs.remove(k);
    }
    _reset();
    _read();
    notifyListeners();
  }

  void _reset() {
    seenInvites = {};
    myName = '';
    birthday = null;
    shareBirthday = false;
    shareStreaks = false;
    shareAvailability = AvailabilityShare.nobody;
    shareGroups = {};
    allowInvites = true;
    freeWindows = [];
    manualStatus = null;
    manualStatusUntil = null;
    eventReminders = true;
    taskReminders = true;
    birthdayReminders = true;
    memoryReminders = true;
    defaultReminderMin = 30;
    themeMode = ThemeMode.system;
    onboarded = false;
    tourDone = false;
    _tipsOn = true;
    googleCalendars = {};
    googleEmail = null;
    googleSyncedAt = null;
    homeCards = [...HomeCard.values];
    hiddenCards = {};
    challengeHabits = {};
  }

  // Adatok exportálása

  /// Minden saját adat egy olvasható JSON-szövegben (a GDPR szerinti adathordozhatósághoz is).
  String exportData() {
    return const JsonEncoder.withIndent(' ').convert({
      'app': 'lifeup',
      'version': 2,
      'exportedAt': DateTime.now().toIso8601String(),
      'events': events.map((e) => e.toJson()).toList(),
      'tasks': tasks.map((t) => t.toJson()).toList(),
      'goals': habits.map((h) => h.toJson()).toList(),
      'groups': groups.map((g) => g.toJson()).toList(),
      'settings': cloudSettings(),
    });
  }

  /// Visszatölt egy exportot a mostani adatok helyére.
  /// [FormatException]-t dob, ha a fájl nem LIFEUP-export vagy sérült.
  void importData(String text) {
    try {
      final root = jsonDecode(text) as Map<String, dynamic>;
      if (root['app'] != 'lifeup') throw const FormatException();
      List<Map<String, dynamic>> list(String k) => [
        for (final x in root[k] as List? ?? []) Map<String, dynamic>.from(x as Map),
      ];
      final e = list('events').map(Event.fromJson).toList();
      final t = list('tasks').map(TaskItem.fromJson).toList();
      final h = list('goals').map(Habit.fromJson).toList();
      final g = list('groups').map(FriendGroup.fromJson).toList();
      applyCloud(events: e, tasks: t, habits: h, groups: g, settings: root['settings'] as Map<String, dynamic>?);
    } catch (_) {
      throw const FormatException('Ez nem LIFEUP-export, vagy a fájl sérült.');
    }
  }

  // Bevezető

  bool get needsOnboarding => !onboarded && habits.isEmpty && events.isEmpty && tasks.isEmpty;

  void finishOnboarding({
    String? name,
    String? birthday,
    List<FreeWindow> windows = const [],
    AvailabilityShare share = AvailabilityShare.nobody,
    Set<HomeCard> hidden = const {},
  }) {
    if (name != null && name.trim().isNotEmpty) myName = _cut(name.trim(), 40);
    if (birthday != null) this.birthday = birthday;
    freeWindows = [...windows];
    shareAvailability = share;
    hiddenCards = {...hidden};
    onboarded = true;
    _save();
  }

  static String _cut(String s, int n) => s.length > n ? s.substring(0, n) : s;

  // Profil és adatvédelem

  void setMyName(String name) {
    myName = _cut(name.trim(), 40);
    _save();
  }

  void setBirthday(String? value) {
    birthday = value;
    _save();
  }

  void setPrivacy({
    bool? shareBirthday,
    bool? shareStreaks,
    AvailabilityShare? shareAvailability,
    Set<String>? shareGroups,
    bool? allowInvites,
  }) {
    this.shareBirthday = shareBirthday ?? this.shareBirthday;
    this.shareStreaks = shareStreaks ?? this.shareStreaks;
    this.shareAvailability = shareAvailability ?? this.shareAvailability;
    this.shareGroups = shareGroups ?? this.shareGroups;
    this.allowInvites = allowInvites ?? this.allowInvites;
    _save();
  }

  void setFreeWindows(List<FreeWindow> windows) {
    freeWindows = [...windows];
    _save();
  }

  /// Kézi állapot; alapból a nap végéig érvényes, utána újra a naptár dönt.
  void setManualStatus(AvailabilityStatus? status, {DateTime? until}) {
    manualStatus = status;
    final now = DateTime.now();
    manualStatusUntil = status == null ? null : (until ?? DateTime(now.year, now.month, now.day + 1));
    _save();
  }

  /// A mostani állapotom: a kézi, ha még érvényes; különben a naptárból (foglalt, ha épp tart valami).
  AvailabilityStatus statusAt(DateTime now) {
    final manual = manualStatus;
    final until = manualStatusUntil;
    if (manual != null && (until == null || now.isBefore(until))) return manual;
    final busyNow = busyIntervals(now, now.add(const Duration(minutes: 1))).isNotEmpty;
    return busyNow ? AvailabilityStatus.busy : AvailabilityStatus.available;
  }

  bool get statusIsManual {
    final until = manualStatusUntil;
    return manualStatus != null && (until == null || DateTime.now().isBefore(until));
  }

  /// A foglalt időszakaim (a „foglaltnak számító” bejegyzések és a beosztott feladatok).
  List<TimeSpan> busyIntervals(DateTime from, DateTime to) => [
    for (final o in occurrencesBetween(from, to))
      if (o.event.busy) TimeSpan(o.start, o.end),
    for (final t in tasks)
      if (!t.done && t.scheduled != null)
        if (t.scheduled!.isBefore(to) && t.scheduled!.add(Duration(minutes: t.durationMin)).isAfter(from))
          TimeSpan(t.scheduled!, t.scheduled!.add(Duration(minutes: t.durationMin))),
  ];

  // Értesítések, megjelenés, Főoldal

  void setReminders({bool? events, bool? tasks, bool? birthdays, bool? memories, int? defaultMin, bool clearDefault = false}) {
    memoryReminders = memories ?? memoryReminders;
    eventReminders = events ?? eventReminders;
    taskReminders = tasks ?? taskReminders;
    birthdayReminders = birthdays ?? birthdayReminders;
    defaultReminderMin = clearDefault ? null : (defaultMin ?? defaultReminderMin);
    _save();
  }

  /// Tippek a Főoldalon (ki is kapcsolhatók).
  bool get tipsOn => _tipsOn;

  void setTipsOn(bool on) {
    _tipsOn = on;
    _save();
  }

  /// Az ezen az eszközön már bezárt tippek.
  Set<String> get closedTips => {...?_prefs.getStringList('tipsClosed')};

  /// Bezárás után egy ideig nem jön új tipp.
  DateTime? get tipSnoozeUntil => DateTime.tryParse(_prefs.getString('tipSnooze') ?? '');

  /// Egy tipp bezárása (vagy kipróbálása): többé nem jön elő, és [tipEveryDays] napig semmi sem.
  void closeTip(String id, [DateTime? now]) {
    final n = now ?? DateTime.now();
    _prefs.setStringList('tipsClosed', {...closedTips, id}.toList());
    _prefs.setString('tipSnooze', DateTime(n.year, n.month, n.day + tipEveryDays).toIso8601String());
    notifyListeners();
  }

  void setTourDone(bool done) {
    tourDone = done;
    _save();
  }

  void setThemeMode(ThemeMode mode) {
    themeMode = mode;
    _save();
  }

  bool showsCard(HomeCard c) => !hiddenCards.contains(c);

  void setCardVisible(HomeCard c, bool visible) {
    visible ? hiddenCards.remove(c) : hiddenCards.add(c);
    _save();
  }

  /// Áthelyezés: a [to] már az elem kivétele utáni helyet jelenti.
  void moveCardTo(int from, int to) {
    homeCards.insert(to, homeCards.removeAt(from));
    _save();
  }

  // Naptár

  /// Minden alkalom a [from, to) időszakban, kezdés szerint rendezve.
  List<Occurrence> occurrencesBetween(DateTime from, DateTime to) =>
      [for (final e in events) ...e.occurrencesBetween(from, to)]..sort((a, b) => a.start.compareTo(b.start));

  /// Egy nap alkalmai (az egész naposak elöl).
  List<Occurrence> occurrencesOn(DateTime day) {
    final s = startOfDay(day);
    final list = occurrencesBetween(s, DateTime(s.year, s.month, s.day + 1));
    list.sort((a, b) {
      if (a.event.allDay != b.event.allDay) return a.event.allDay ? -1 : 1;
      return a.start.compareTo(b.start);
    });
    return list;
  }

  /// A következő, még nem véget ért alkalmak.
  List<Occurrence> upcoming({int days = 30, DateTime? now}) {
    final t = now ?? DateTime.now();
    return occurrencesBetween(t, t.add(Duration(days: days)));
  }

  Event? eventById(String id) => events.where((e) => e.id == id).firstOrNull;

  /// Új bejegyzést felvesz, meglévőt (azonosító szerint) lecserél.
  void saveEvent(Event e) {
    final i = events.indexWhere((x) => x.id == e.id);
    i < 0 ? events.add(e) : events[i] = e;
    _save();
  }

  void removeEvent(Event e) {
    events.removeWhere((x) => x.id == e.id);
    _save();
  }

  /// Ismétlődő bejegyzésnél csak egy alkalom törlése.
  void skipOccurrence(Event e, DateTime start) {
    e.skipped.add(dayKey(start));
    saveEvent(e);
  }

  // Google Naptár

  /// Össze van-e kapcsolva a Google Naptár (van kiválasztott naptár).
  bool get googleConnected => googleCalendars.isNotEmpty;

  /// A kiválasztott naptárak egy frissítéssel: a régi másolatok helyére az újak.
  void replaceGoogleEvents(Map<String, List<Event>> byCalendar, {DateTime? at}) {
    for (final entry in byCalendar.entries) {
      events.removeWhere((e) => e.source == 'google:${entry.key}');
      events.addAll(entry.value);
    }
    googleSyncedAt = at ?? DateTime.now();
    _save();
  }

  /// Melyik naptárak jöjjenek (azonosító → név). A kivett naptárak eseményei törlődnek innen.
  void setGoogleCalendars(Map<String, String> calendars, {String? email}) {
    final removed = googleCalendars.keys.where((id) => !calendars.containsKey(id)).toList();
    events.removeWhere((e) => removed.any((id) => e.source == 'google:$id'));
    googleCalendars = {...calendars};
    if (email != null) googleEmail = email;
    _save();
  }

  /// Leválasztás: minden Google-ből jött esemény lekerül innen (a Google Naptárban megmaradnak).
  void disconnectGoogle() {
    events.removeWhere((e) => e.source?.startsWith('google:') ?? false);
    googleCalendars = {};
    googleEmail = null;
    googleSyncedAt = null;
    _save();
  }

  /// Mivel ütközne egy új vagy módosított időpont: a már meglévő (nem egész napos) bejegyzések és
  /// beosztott feladatok, amelyek átfednek vele. Ismétlődésnél a következő [occurrences] alkalmat
  /// nézi. Az egész napos dolgok (pl. születésnap) nem számítanak ütközésnek.
  List<Conflict> conflictsFor({
    required DateTime start,
    required int durationMin,
    bool allDay = false,
    Repeat repeat = Repeat.none,
    String? ignoreEventId,
    String? ignoreTaskId,
    int occurrences = 8,
    DateTime? now,
  }) {
    if (allDay || durationMin <= 0) return const [];
    final probe = Event(id: '_', title: '', start: start, durationMin: durationMin, repeat: repeat);
    final from = repeat == Repeat.none ? start : (now ?? DateTime.now());
    final slots = probe.occurrencesBetween(from, from.add(const Duration(days: 400))).take(occurrences);
    final found = <Conflict>[];
    for (final slot in slots) {
      for (final o in occurrencesBetween(slot.start, slot.end)) {
        if (o.event.id == ignoreEventId || o.event.allDay) continue;
        found.add(Conflict(title: o.event.title, start: o.start, end: o.end));
      }
      for (final t in tasks) {
        final s = t.scheduled;
        if (t.done || s == null || t.id == ignoreTaskId) continue;
        final e = s.add(Duration(minutes: t.durationMin));
        if (s.isBefore(slot.end) && e.isAfter(slot.start)) found.add(Conflict(title: t.title, start: s, end: e, task: true));
      }
    }
    found.sort((a, b) => a.start.compareTo(b.start));
    return found;
  }

  // Feladatok

  /// Egy nap feladatai: amit erre a napra osztottál be, vagy aminek ma van a határideje.
  /// A mai napon a lejárt, még nyitott feladatok is.
  List<TaskItem> tasksOn(DateTime day, {DateTime? now}) {
    final today = sameDay(day, now ?? DateTime.now());
    return tasks.where((t) {
      final d = t.day;
      if (d != null && sameDay(d, day)) return true;
      return today && t.isOverdue(now);
    }).toList()..sort(_taskOrder);
  }

  /// Nyitott feladatok: előbb a lejártak és a határidősök, aztán a többi.
  List<TaskItem> get openTasks => tasks.where((t) => !t.done).toList()..sort(_taskOrder);

  static int _taskOrder(TaskItem a, TaskItem b) {
    if (a.done != b.done) return a.done ? 1 : -1;
    final da = a.scheduled ?? a.due, db = b.scheduled ?? b.due;
    if (da == null && db == null) return a.createdAt.compareTo(b.createdAt);
    if (da == null) return 1;
    if (db == null) return -1;
    return da.compareTo(db);
  }

  void saveTask(TaskItem t) {
    t.title = _cut(t.title.trim(), 200);
    final i = tasks.indexWhere((x) => x.id == t.id);
    i < 0 ? tasks.add(t) : tasks[i] = t;
    _save();
  }

  void toggleTask(TaskItem t) {
    t.done = !t.done;
    t.doneAt = t.done ? DateTime.now() : null;
    _save();
  }

  void removeTask(TaskItem t) {
    tasks.removeWhere((x) => x.id == t.id);
    _save();
  }

  // Barátok, csoportok, meghívások

  void setFriendsCache(List<FriendInfo> friends) {
    final now = jsonEncode(friends.map((f) => f.toJson()).toList());
    if (now == jsonEncode(friendsCache.map((f) => f.toJson()).toList())) return;
    friendsCache = friends;
    // A csoportokból kikerülnek, akik már nem barátok.
    final uids = {for (final f in friends) f.uid};
    for (final g in groups) {
      g.members.removeWhere((m) => !uids.contains(m));
    }
    _save();
  }

  String nameOf(String uid) => friendsCache.where((f) => f.uid == uid).firstOrNull?.name ?? '?';

  void saveGroup(FriendGroup g) {
    g.name = _cut(g.name.trim(), 40);
    final i = groups.indexWhere((x) => x.id == g.id);
    i < 0 ? groups.add(g) : groups[i] = g;
    _save();
  }

  void removeGroup(FriendGroup g) {
    groups.removeWhere((x) => x.id == g.id);
    shareGroups.remove(g.id);
    _save();
  }

  /// Megjegyzi a meghívást (vagy frissíti a címét, időpontját).
  void saveInvite(Invite invite) {
    invites.removeWhere((i) => i.id == invite.id);
    invites.add(invite);
    invites.sort((a, b) => a.date.compareTo(b.date));
    _save();
  }

  /// A még meg nem nyitott, jövőbeli meghívások (amik a naptárban sincsenek még benne).
  List<Invite> unseenInvites([DateTime? now]) {
    final today = startOfDay(now ?? DateTime.now());
    return [
      for (final i in invites)
        if (!seenInvites.contains(i.id) && !i.date.isBefore(today) && !events.any((e) => e.shareId == i.id)) i,
    ];
  }

  void markInviteSeen(String id) {
    if (!seenInvites.add(id)) return;
    _save();
  }

  void removeInvite(String id) {
    invites.removeWhere((i) => i.id == id);
    _save();
  }

  // Célok

  void addHabit(String name, {int? perWeek, int target = 1, String unit = '', int? reminderMinutes}) {
    habits.add(
      Habit(
        id: newId(),
        name: name.trim(),
        perWeek: perWeek,
        target: target,
        unit: unit.trim(),
        reminderMinutes: reminderMinutes,
      ),
    );
    _save();
  }

  /// Egy cél beállításainak módosítása után.
  void updateHabit(Habit h) => _save();

  /// Mennyiségi célnál egy adaggal kevesebb.
  void decrementHabit(Habit h, [DateTime? day]) {
    h.removeOne(day ?? DateTime.now());
    _save();
  }

  void removeHabit(Habit h) {
    habits.remove(h);
    _save();
  }

  /// Kipipálás / visszavonás. Mennyiségi célnál egy adaggal több; ha már megvolt, nullázza a napot.
  void toggleHabit(Habit h, [DateTime? day]) {
    final d = day ?? DateTime.now();
    final key = dayKey(d);
    if (h.isCounted) {
      if (h.isDoneOn(d)) {
        h.counts.remove(key);
        h.doneDays.remove(key);
      } else {
        h.addOne(d);
      }
    } else if (!h.doneDays.remove(key)) {
      h.doneDays.add(key);
    }
    _save();
  }

  /// Ma még hány cél nincs kipipálva.
  int get habitsLeftToday => habits.where((h) => !h.isSatisfiedOn(DateTime.now())).length;

  void linkChallengeHabit(String challengeId, String? habitId) {
    habitId == null ? challengeHabits.remove(challengeId) : challengeHabits[challengeId] = habitId;
    _save();
  }
}

/// A store elérése a widgetfából: `StoreScope.of(context)`.
class StoreScope extends InheritedNotifier<AppStore> {
  const StoreScope({super.key, required AppStore store, required super.child}) : super(notifier: store);

  static AppStore of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<StoreScope>()!.notifier!;
}

/// Egy ütközés: egy már meglévő bejegyzés vagy beosztott feladat, ami átfed az új időponttal.
class Conflict {
  const Conflict({required this.title, required this.start, required this.end, this.task = false});

  final String title;
  final DateTime start;
  final DateTime end;
  final bool task;
}
