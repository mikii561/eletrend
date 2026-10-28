import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:home_widget/home_widget.dart';

import 'models.dart';
import 'store.dart';

/// A kezdőképernyő-widget (Android) adatainak frissítése és a koppintások kezelése.
/// A natív rész: android/app/src/main/kotlin/.../HabitsWidgetProvider.kt
class HabitsWidget {
  static const _provider = 'hu.eletrend.eletrend.HabitsWidgetProvider';

  /// Ennyi szokás fér ki a widgetre.
  static const maxRows = 5;

  static bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Timer? _debounce;

  static Future<void> init(AppStore store) async {
    if (!supported) return;
    await HomeWidget.registerInteractivityCallback(habitsWidgetCallback);
    await update(store);
    store.addListener(() {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 500), () => update(store));
    });
  }

  /// A widgetnek átadott adatok; a Kotlin oldal ugyanezekkel a kulcsokkal olvas.
  static Map<String, Object> widgetData(AppStore store, DateTime now) {
    final habits = store.habits.take(maxRows).toList();
    return {
      'day': dayKey(now),
      'count': habits.length,
      for (var i = 0; i < habits.length; i++) ...{
        'habit${i}_id': habits[i].id,
        'habit${i}_name': habits[i].name,
        'habit${i}_done': habits[i].isDoneOn(now),
      },
    };
  }

  /// Felajánlja a widget kitételét a kezdőképernyőre (Android 8+, a legtöbb indítón).
  static Future<bool> canPin() async {
    if (!supported) return false;
    try {
      return await HomeWidget.isRequestPinWidgetSupported() ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> pin() => HomeWidget.requestPinWidget(qualifiedAndroidName: _provider);

  static Future<void> update(AppStore store) async {
    if (!supported) return;
    try {
      for (final e in widgetData(store, DateTime.now()).entries) {
        await HomeWidget.saveWidgetData(e.key, e.value);
      }
      await HomeWidget.updateWidget(qualifiedAndroidName: _provider);
    } catch (e) {
      debugPrint('Widget frissítése nem sikerült: $e');
    }
  }
}

/// Koppintás a widgeten (eletrend://toggle?id=...): a háttérben, az app megnyitása nélkül fut.
@pragma('vm:entry-point')
Future<void> habitsWidgetCallback(Uri? uri) async {
  if (uri?.host != 'toggle') return;
  WidgetsFlutterBinding.ensureInitialized();
  final store = await AppStore.load();
  final id = uri!.queryParameters['id'];
  for (final h in store.habits) {
    if (h.id == id) store.toggleHabit(h);
  }
  await HabitsWidget.update(store);
}
