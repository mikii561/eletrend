import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Egy hely a térképen, olvasható névvel.
class Place {
  const Place({required this.name, required this.point});

  final String name;
  final LatLng point;
}

/// Címkeresés és koordináta → cím az OpenStreetMap Nominatim szolgáltatásával.
/// Ingyenes, kulcs nem kell, de másodpercenként legfeljebb 1 kérés illik.
class Geocoding {
  static const _host = 'nominatim.openstreetmap.org';

  // Böngészőben a User-Agent fejlécet nem lehet beállítani, ott a böngészőé megy.
  static Map<String, String> get _headers =>
      kIsWeb ? {} : {'User-Agent': 'Eletrend/0.1 (hu.eletrend.eletrend)'};

  static Future<List<Place>> search(String query) async {
    final uri = Uri.https(_host, '/search', {
      'q': query,
      'format': 'jsonv2',
      'limit': '6',
      'addressdetails': '1',
      'accept-language': 'hu',
    });
    final res = await http.get(uri, headers: _headers);
    if (res.statusCode != 200) return [];
    final list = jsonDecode(res.body) as List;
    return [
      for (final p in list.cast<Map<String, dynamic>>())
        Place(
          name: _shortName(p) ?? p['display_name'] as String,
          point: LatLng(double.parse(p['lat'] as String), double.parse(p['lon'] as String)),
        ),
    ];
  }

  /// Rövid, emberi cím egy pontra, pl. "Corvin mozi, Budapest".
  static Future<String?> reverse(LatLng point) async {
    final uri = Uri.https(_host, '/reverse', {
      'lat': '${point.latitude}',
      'lon': '${point.longitude}',
      'format': 'jsonv2',
      'zoom': '18',
      'accept-language': 'hu',
    });
    final res = await http.get(uri, headers: _headers);
    if (res.statusCode != 200) return null;
    return _shortName(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// A Nominatim válaszából rövid nevet készít: hely neve, utca házszám, város.
  static String? _shortName(Map<String, dynamic> j) {
    final a = (j['address'] as Map?)?.cast<String, dynamic>() ?? {};
    final name = j['name'] as String?;
    final street = [a['road'], a['house_number']].whereType<String>().join(' ');
    final city = (a['city'] ?? a['town'] ?? a['village']) as String?;
    final parts = [
      if (name != null && name.isNotEmpty) name,
      if (street.isNotEmpty && street != name) street,
      ?city,
    ];
    return parts.isEmpty ? j['display_name'] as String? : parts.join(', ');
  }
}
