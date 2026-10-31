import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'formatting.dart' show formatTime;
import 'memories.dart' show pickMemory;
import 'models.dart';
import 'store.dart';

/// Egy beütemezendő értesítés (tesztelhető, a plugintől független leírás).
class PlannedNotification {
  const PlannedNotification(this.id, this.when, this.title, this.body, {this.channel = 'events', this.payload});

  final int id;
  final DateTime when;
  final String title;
  final String body;
  final String channel;
  final String? payload;
}

/// Helyi emlékeztető értesítések (csak Androidon).
///
/// Nem kell szerver: az értesítéseket a telefon maga ütemezi. Minden adatváltozáskor
/// újraütemezünk mindent (bejegyzések, feladatok, célok, születésnapok), így egy törölt
/// vagy kipipált dologról már nem jön emlékeztető.
class Notifications {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;
  static Timer? _debounce;

  static bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static const _channels = {
    'events': AndroidNotificationDetails(
      'events',
      'Naptár emlékeztetők',
      channelDescription: 'Figyelmeztetés a közelgő bejegyzésekre és feladatokra',
      importance: Importance.high,
      priority: Priority.high,
    ),
    'goals': AndroidNotificationDetails('daily', 'Célok', channelDescription: 'Emlékeztető a céljaidhoz'),
    'birthdays': AndroidNotificationDetails(
      'birthdays',
      'Születésnapok',
      channelDescription: 'A barátaid születésnapjai',
    ),
    'nudges': AndroidNotificationDetails(
      'nudges',
      'Bökések a barátoktól',
      channelDescription: 'Amikor egy barátod megbök (a telefon beállításaiban külön kikapcsolható)',
      importance: Importance.high,
      priority: Priority.high,
    ),
  };

  // Értesítés-azonosítók tartományai.
  static const _eventBase = 2000; // legfeljebb 200
  static const _taskBase = 2500; // legfeljebb 100
  static const _habitBase = 3000; // célonként 7 nap
  static const _birthdayBase = 4000; // legfeljebb 100
  static const _memoryBase = 4500; // legfeljebb 30
  static const _nudgeBase = 5000; // 5000 + (azonosító hash % 1000)
  static const _testId = 9999;

  /// Értesítésre koppintáskor (pl. `nudge:azonosító`).
  static void Function(String payload)? onTap;

  /// Webes push értesítésből nyitott link (…/?n=nudge:azonosító): a bejelentkezés után dolgozzuk fel.
  static String? pendingTap;

  /// Indításkor egyszer: időzóna, plugin, és figyeli a store-t. Engedélyt nem kér magától:
  /// azt a bevezető vagy a beállítások kérik, magyarázattal.
  static Future<void> init(AppStore store) async {
    if (!supported) return;
    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Europe/Budapest'));
    }
    await _plugin.initialize(
      settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
      onDidReceiveNotificationResponse: (r) {
        if (r.payload != null) onTap?.call(r.payload!);
      },
    );
    // Ha egy értesítésre koppintva indult el az app, azt is kezeljük.
    final launch = await _plugin.getNotificationAppLaunchDetails();
    final payload = launch?.notificationResponse?.payload;
    if (launch?.didNotificationLaunchApp == true && payload != null) onTap?.call(payload);
    _ready = true;
    await reschedule(store);
    store.addListener(() {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 500), () => reschedule(store));
    });
  }

  /// Android 13+ esetén rákérdez az értesítési engedélyre. Igazat ad, ha szabad értesíteni.
  static Future<bool> requestPermission() async {
    if (!_ready) return false;
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? false;
  }

  /// Bökés értesítés (ha az app a háttérben fut). Koppintásra az [onTap] kapja: `nudge:azonosító`.
  static Future<void> showNudge(String id, String title, String body) async {
    if (!_ready) return;
    await _plugin.show(
      id: _nudgeBase + id.hashCode.abs() % 1000,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(android: _channels['nudges']),
      payload: 'nudge:$id',
    );
  }

  static Future<void> showTest() async {
    if (!_ready) return;
    await _plugin.show(
      id: _testId,
      title: 'Szia! 👋',
      body: 'Így fognak kinézni a LIFEUP emlékeztetői.',
      notificationDetails: NotificationDetails(android: _channels['events']),
    );
  }

  /// Az összes jövőbeli emlékeztető újraütemezése a store alapján.
  static Future<void> reschedule(AppStore store) async {
    if (!_ready) return;
    await _plugin.cancelAllPendingNotifications();
    for (final n in plan(store, DateTime.now())) {
      await _plugin.zonedSchedule(
        id: n.id,
        scheduledDate: tz.TZDateTime.from(n.when, tz.local),
        notificationDetails: NotificationDetails(android: _channels[n.channel]),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: n.title,
        body: n.body,
        payload: n.payload,
      );
    }
  }

  /// Mit és mikor kell értesíteni a következő napokban.
  @visibleForTesting
  static List<PlannedNotification> plan(AppStore store, DateTime now) {
    final out = <PlannedNotification>[];
    final time = DateFormat('HH:mm', 'hu');

    // Bejegyzések: a saját emlékeztetőjük szerint, a következő 14 napban.
    if (store.eventReminders) {
      var i = 0;
      for (final o in store.occurrencesBetween(now, now.add(const Duration(days: 14)))) {
        final before = o.event.reminderMin;
        if (before == null || i >= 200) continue;
        final DateTime when;
        final String title;
        if (o.event.allDay) {
          // Egész napos: aznap reggel 8-kor (vagy az előtte lévő nap(ok)on, ha úgy kérte).
          when = DateTime(o.start.year, o.start.month, o.start.day, 8).subtract(Duration(days: before ~/ 1440));
          title = o.event.title;
        } else {
          when = o.start.subtract(Duration(minutes: before));
          title = before == 0 ? 'Most: ${o.event.title}' : '${_inText(before)}: ${o.event.title}';
        }
        if (!when.isAfter(now)) continue;
        final body = o.event.allDay ? 'Egész napos' : '${time.format(o.start)}–${time.format(o.end)}';
        out.add(
          PlannedNotification(_eventBase + i++, when, title, o.event.place.isEmpty ? body : '$body · ${o.event.place}'),
        );
      }
    }

    // Feladatok: beosztottnál a választott idővel a kezdés előtt, csak határidősnél a határidő
    // napján reggel 9-kor. „Nincs értesítés” (null) esetén semmi (a Főoldalon így is látszik).
    if (store.taskReminders) {
      var i = 0;
      for (final t in store.openTasks) {
        if (i >= 100) break;
        final before = t.reminderMin;
        if (before == null) continue;
        final s = t.scheduled;
        final when = s != null
            ? s.subtract(Duration(minutes: before))
            : (t.due == null ? null : DateTime(t.due!.year, t.due!.month, t.due!.day, 9));
        if (when == null || !when.isAfter(now) || when.isAfter(now.add(const Duration(days: 14)))) continue;
        out.add(
          PlannedNotification(
            _taskBase + i++,
            when,
            s == null ? 'Ma a határidő: ${t.title}' : (before == 0 ? 'Most: ${t.title}' : '${_inText(before)}: ${t.title}'),
            s == null ? 'Pipáld ki, ha megvan. ✅' : '${formatTime(s)}-kor, ${t.durationMin} percet szántál rá.',
          ),
        );
      }
    }


    // Célonkénti saját emlékeztető: csak ha aznap (hetinél: azon a héten) még nincs meg.
    for (var i = 0; i < store.habits.length && i < 30; i++) {
      final h = store.habits[i];
      final m = h.reminderMinutes;
      if (m == null) continue;
      for (var d = 0; d < 7; d++) {
        final when = DateTime(now.year, now.month, now.day + d, m ~/ 60, m % 60);
        if (!when.isAfter(now)) continue;
        final day = DateTime(when.year, when.month, when.day, 12);
        if (h.isSatisfiedOn(day)) continue;
        out.add(
          PlannedNotification(_habitBase + i * 7 + d, when, '${h.name} ⏰', habitReminderBody(h, day), channel: 'goals'),
        );
      }
    }

    // A barátaim születésnapja: aznap reggel 9-kor, a következő 30 napban.
    if (store.birthdayReminders) {
      var i = 0;
      for (final f in store.friendsCache) {
        final next = f.nextBirthday(now);
        if (next == null || i >= 100) continue;
        final when = DateTime(next.year, next.month, next.day, 9);
        if (!when.isAfter(now) || when.isAfter(now.add(const Duration(days: 30)))) continue;
        out.add(
          PlannedNotification(
            _birthdayBase + i++,
            when,
            'Ma van ${f.name} születésnapja 🎂',
            'Írj neki, vagy szervezz valamit!',
            channel: 'birthdays',
          ),
        );
      }
    }

    // Emlékek: ha egy közös program kerek évfordulója van (1 hete, 1/3/6 hónapja, N éve), aznap 10-kor.
    if (store.memoryReminders) {
      for (var d = 0; d < 30; d++) {
        final when = DateTime(now.year, now.month, now.day + d, 10);
        if (!when.isAfter(now)) continue;
        final pick = pickMemory(store.events, when);
        if (pick == null || !pick.anniversary) continue;
        out.add(
          PlannedNotification(
            _memoryBase + d,
            when,
            'Emlék: ${pick.event.title} 📸',
            'Ma ${pick.ago} volt${pick.event.place.isEmpty ? '' : ' · ${pick.event.place}'}. Nézd meg a közös fotókat!',
            channel: 'birthdays',
          ),
        );
      }
    }
    return out;
  }

  static String _inText(int minutes) => switch (minutes) {
    < 60 => '$minutes perc múlva',
    60 => '1 óra múlva',
    < 1440 => '${minutes ~/ 60} óra múlva',
    _ => 'Holnap',
  };

  /// Mit írjunk egy cél emlékeztetőjébe.
  @visibleForTesting
  static String habitReminderBody(Habit h, DateTime day) {
    if (h.isCounted) {
      final left = h.target - h.countOn(day);
      return 'Még $left${h.unit.isEmpty ? '' : ' ${h.unit}'} van hátra mára. 💪';
    }
    if (h.isWeekly) return 'Ezen a héten még ${h.perWeek! - h.doneInWeek(day)}× van hátra. 💪';
    return 'Ne felejtsd el ma! 💪';
  }
}
