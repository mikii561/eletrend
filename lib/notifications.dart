import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'models.dart';
import 'store.dart';

/// Helyi emlékeztető értesítések (csak Androidon).
///
/// Nem kell szerver: az értesítéseket a telefon maga ütemezi. Minden
/// adatváltozáskor újraütemezünk mindent, így pl. ha ma már mindent
/// kipipáltál, a mai esti emlékeztető elmarad.
class Notifications {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;
  static Timer? _debounce;

  static bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static const _dailyDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'daily',
      'Napi emlékeztető',
      channelDescription: 'Esti emlékeztető a szokásokhoz és a naplóhoz',
    ),
  );

  static const _eventDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'events',
      'Program emlékeztetők',
      channelDescription: 'Figyelmeztetés a közelgő programokra',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  // Értesítés-azonosítók: napi 1000–1006, programok 2000-től.
  static const _dailyBase = 1000;
  static const _eventBase = 2000;
  static const _habitBase = 3000; // szokásonként 7 nap: 3000 + szokás * 7 + nap
  static const _checkInBase = 4000; // naponta 2: 4000 + nap * 2 + (0: 11:00, 1: 15:00)
  static const _testId = 9999;

  /// Indításkor egyszer: időzóna, plugin, engedélykérés, és figyeli a store-t.
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
    );
    _ready = true;
    await requestPermission();
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

  static Future<void> showTest() async {
    if (!_ready) return;
    await _plugin.show(
      id: _testId,
      title: 'Szia! 👋',
      body: 'Így fognak kinézni az Életrend emlékeztetői.',
      notificationDetails: _dailyDetails,
    );
  }

  /// Az összes jövőbeli emlékeztetőt törli és újra beütemezi a store alapján.
  static Future<void> reschedule(AppStore store) async {
    if (!_ready) return;
    await _plugin.cancelAllPendingNotifications();
    final now = tz.TZDateTime.now(tz.local);

    if (store.dailyReminder) {
      final t = store.reminderTime;
      for (var i = 0; i < 7; i++) {
        final when = tz.TZDateTime(tz.local, now.year, now.month, now.day + i, t.hour, t.minute);
        if (when.isBefore(now)) continue;
        final body = i == 0 ? _todayBody(store) : _genericBody;
        if (body == null) continue; // ma már minden kész
        await _schedule(_dailyBase + i, when, 'Hogy telt a napod? 🌙', body, _dailyDetails);
      }
    }

    // Napközbeni „Hogy vagy most?” kérdés (11:00 és 15:00).
    if (store.checkInReminders) {
      for (var d = 0; d < 7; d++) {
        for (final (k, hour) in [(0, 11), (1, 15)]) {
          final when = tz.TZDateTime(tz.local, now.year, now.month, now.day + d, hour);
          if (when.isBefore(now)) continue;
          await _schedule(_checkInBase + d * 2 + k, when, 'Hogy vagy most? 🙂', 'Egy koppintás az Életrendben, és a statisztika a napszakokat is látja.', _dailyDetails);
        }
      }
    }

    // Szokásonkénti saját emlékeztető: csak ha aznap (hetinél: azon a héten) még nincs meg.
    for (var i = 0; i < store.habits.length && i < 30; i++) {
      final h = store.habits[i];
      final m = h.reminderMinutes;
      if (m == null) continue;
      for (var d = 0; d < 7; d++) {
        final when = tz.TZDateTime(tz.local, now.year, now.month, now.day + d, m ~/ 60, m % 60);
        if (when.isBefore(now)) continue;
        final day = DateTime(when.year, when.month, when.day, 12);
        if (h.isSatisfiedOn(day)) continue;
        await _schedule(_habitBase + i * 7 + d, when, '${h.name} ⏰', habitReminderBody(h, day), _dailyDetails);
      }
    }

    if (store.eventReminders) {
      final events = store.upcomingEvents.take(40).toList();
      for (var i = 0; i < events.length; i++) {
        final e = events[i];
        // Ismétlődő programnál a következő alkalomra emlékeztetünk.
        final date = e.nextDate();
        final time = DateFormat('HH:mm', 'hu').format(date);
        final where = e.place.isEmpty ? '' : ' · ${e.place}';

        final eveBefore = tz.TZDateTime(tz.local, date.year, date.month, date.day - 1, 18);
        if (eveBefore.isAfter(now)) {
          await _schedule(_eventBase + i * 2, eveBefore, 'Holnap: ${e.title} 🎉', '$time$where', _eventDetails);
        }
        final hourBefore = tz.TZDateTime.from(date, tz.local).subtract(const Duration(hours: 1));
        if (hourBefore.isAfter(now)) {
          await _schedule(_eventBase + i * 2 + 1, hourBefore, '1 óra múlva: ${e.title}', '$time$where', _eventDetails);
        }
      }
    }
  }

  /// Mit írjunk egy szokás emlékeztetőjébe.
  @visibleForTesting
  static String habitReminderBody(Habit h, DateTime day) {
    if (h.isCounted) {
      final left = h.target - h.countOn(day);
      return 'Még $left${h.unit.isEmpty ? '' : ' ${h.unit}'} van hátra mára. 💪';
    }
    if (h.isWeekly) return 'Ezen a héten még ${h.perWeek! - h.doneInWeek(day)}× van hátra. 💪';
    return 'Ne felejtsd el ma! 💪';
  }

  static const _genericBody = 'Pipáld ki a mai szokásaidat, és írd le, miért vagy hálás! 🙏';

  /// A mai esti üzenet a tényleges állapot alapján; null, ha nincs mit emlékeztetni.
  static String? _todayBody(AppStore store) {
    final left = store.habitsLeftToday;
    final journal = store.journalDoneToday;
    if (left == 0 && journal) return null;
    if (left > 0 && !journal) return 'Még $left szokás vár rád, és a naplódat sem írtad meg ma.';
    if (left > 0) return 'Még $left szokás vár rád ma. Hajrá! 💪';
    return 'Írd le, milyen napod volt, és miért vagy hálás! 🙏';
  }

  static Future<void> _schedule(int id, tz.TZDateTime when, String title, String body, NotificationDetails details) {
    return _plugin.zonedSchedule(
      id: id,
      scheduledDate: when,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      title: title,
      body: body,
    );
  }
}
