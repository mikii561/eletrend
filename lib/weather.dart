import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

/// Időjárás-előrejelzés egy program idejére és helyére (Open-Meteo, ingyenes, kulcs nélkül).
class Forecast {
  const Forecast({required this.temperature, required this.rainChance, required this.code});

  final double temperature;

  /// Csapadék valószínűsége százalékban.
  final int rainChance;

  /// WMO időjárás-kód.
  final int code;

  (String, String) get _look => switch (code) {
        0 => ('☀️', 'derült'),
        1 || 2 => ('🌤️', 'kissé felhős'),
        3 => ('☁️', 'borult'),
        45 || 48 => ('🌫️', 'köd'),
        >= 51 && <= 57 => ('🌦️', 'szitálás'),
        >= 61 && <= 67 => ('🌧️', 'eső'),
        >= 71 && <= 77 => ('🌨️', 'havazás'),
        >= 80 && <= 82 => ('🌦️', 'zápor'),
        85 || 86 => ('🌨️', 'hózápor'),
        >= 95 => ('⛈️', 'zivatar'),
        _ => ('🌡️', ''),
      };

  String get emoji => _look.$1;

  /// Pl. „12°C, eső, 80% eséllyel csapadék”.
  String get text => [
        '${temperature.round()}°C',
        if (_look.$2.isNotEmpty) _look.$2,
        if (rainChance >= 30) '$rainChance% eséllyel csapadék',
      ].join(', ');

  /// Csak a következő ~16 napra van előrejelzés.
  static bool available(DateTime at, [DateTime? now]) {
    final n = now ?? DateTime.now();
    return !at.isBefore(n.subtract(const Duration(hours: 1))) && at.difference(n).inDays < 15;
  }

  /// Az előrejelzés a program órájára; null, ha nincs (túl messze van, vagy nincs internet).
  static Future<Forecast?> fetch(double lat, double lng, DateTime at, {http.Client? client}) async {
    if (!available(at)) return null;
    final day = DateFormat('yyyy-MM-dd').format(at);
    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': lat.toStringAsFixed(4),
      'longitude': lng.toStringAsFixed(4),
      'hourly': 'temperature_2m,precipitation_probability,weather_code',
      'timezone': 'auto',
      'start_date': day,
      'end_date': day,
    });
    try {
      final c = client ?? http.Client();
      final res = await c.get(uri).timeout(const Duration(seconds: 8));
      if (client == null) c.close();
      if (res.statusCode != 200) return null;
      final hourly = (jsonDecode(res.body) as Map<String, dynamic>)['hourly'] as Map<String, dynamic>;
      final times = (hourly['time'] as List).cast<String>();
      final i = times.indexOf('${day}T${at.hour.toString().padLeft(2, '0')}:00');
      if (i < 0) return null;
      return Forecast(
        temperature: ((hourly['temperature_2m'] as List)[i] as num).toDouble(),
        rainChance: ((hourly['precipitation_probability'] as List)[i] as num?)?.toInt() ?? 0,
        code: ((hourly['weather_code'] as List)[i] as num).toInt(),
      );
    } catch (_) {
      return null;
    }
  }
}
