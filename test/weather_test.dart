import 'dart:convert';

import 'package:eletrend/weather.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('időjárás: a program órájára, magyar szöveggel; túl messzire nincs', () async {
    final at = DateTime.now().add(const Duration(days: 2));
    final day = '${at.year}-${at.month.toString().padLeft(2, '0')}-${at.day.toString().padLeft(2, '0')}';
    Uri? asked;
    final client = MockClient((req) async {
      asked = req.url;
      return http.Response(
        jsonEncode({
          'hourly': {
            'time': [for (var h = 0; h < 24; h++) '${day}T${h.toString().padLeft(2, '0')}:00'],
            'temperature_2m': [for (var h = 0; h < 24; h++) h == at.hour ? 12.4 : 5.0],
            'precipitation_probability': [for (var h = 0; h < 24; h++) h == at.hour ? 80 : 0],
            'weather_code': [for (var h = 0; h < 24; h++) h == at.hour ? 63 : 0],
          }
        }),
        200,
      );
    });
    final f = (await Forecast.fetch(47.5, 19.05, at, client: client))!;
    expect(asked!.host, 'api.open-meteo.com');
    expect(f.emoji, '🌧️');
    expect(f.text, '12°C, eső, 80% eséllyel csapadék');
    expect(Forecast.available(DateTime.now().add(const Duration(days: 30))), isFalse);
    expect(await Forecast.fetch(47.5, 19.05, DateTime.now().add(const Duration(days: 30)), client: client), isNull);
    // Hálózati hibánál csendben nincs időjárás
    expect(await Forecast.fetch(47.5, 19.05, at, client: MockClient((_) async => http.Response('hiba', 500))), isNull);
  });
}
