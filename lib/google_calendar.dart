import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'models.dart';
import 'store.dart';

/// Hiba a Google Naptárnál, magyarul.
class GoogleCalendarException implements Exception {
  const GoogleCalendarException(this.message, {this.reconnect = false});

  final String message;

  /// Újra engedélyezni kell (lejárt a hozzáférés).
  final bool reconnect;

  @override
  String toString() => message;
}

/// Egy naptár a Google-fiókban.
class GoogleCalendarInfo {
  const GoogleCalendarInfo({required this.id, required this.name, this.color, this.primary = false});

  final String id;
  final String name;

  /// A naptár színe (ARGB), ha van.
  final int? color;
  final bool primary;
}

/// „#rrggbb” → ARGB.
int? parseHexColor(String? hex) {
  if (hex == null || !RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(hex)) return null;
  return 0xFF000000 | int.parse(hex.substring(1), radix: 16);
}

/// Egy Google-esemény → bejegyzés (null, ha törölt vagy nem értelmezhető). Csak olvasható másolat:
/// a forrás és az eredeti azonosító alapján frissítéskor lecseréljük.
@visibleForTesting
Event? parseGoogleEvent(Map<String, dynamic> item, {required String calendarId, int? color}) {
  if (item['status'] == 'cancelled') return null;
  final id = item['id'] as String?;
  final start = item['start'] as Map<String, dynamic>?;
  final end = item['end'] as Map<String, dynamic>?;
  if (id == null || start == null || end == null) return null;
  final allDay = start['date'] != null;
  DateTime? read(Map<String, dynamic> m) {
    final v = (m['dateTime'] ?? m['date']) as String?;
    if (v == null) return null;
    final d = DateTime.tryParse(v);
    // Az egész napos dátum helyi éjfél; az időpont (időzónával) helyi időre váltva.
    return d == null ? null : (allDay ? DateTime(d.year, d.month, d.day) : d.toLocal());
  }

  final s = read(start), e = read(end);
  if (s == null || e == null) return null;
  final minutes = e.difference(s).inMinutes;
  final notes = (item['description'] as String? ?? '').replaceAll(RegExp(r'<[^>]*>'), ' ').trim();
  return Event(
    id: 'g-${calendarId.hashCode.abs()}-$id',
    title: (item['summary'] as String?)?.trim().isNotEmpty == true ? (item['summary'] as String).trim() : '(nincs cím)',
    start: s,
    durationMin: minutes <= 0 ? (allDay ? 1440 : 30) : minutes,
    allDay: allDay,
    color: color,
    place: item['location'] as String? ?? '',
    notes: notes.length > 1000 ? notes.substring(0, 1000) : notes,
    // A Google maga emlékeztet; itt nem küldünk még egyet.
    reminderMin: null,
    // „Szabadnak mutat” a Google-ben → itt sem foglal.
    busy: item['transparency'] != 'transparent' && !allDay,
    source: 'google:$calendarId',
    externalId: id,
  );
}

/// Google Naptár: a felhasználó engedélyével (csak olvasás) a naptárai eseményei bekerülnek ide.
///
/// Az engedélyt a Google saját ablakában adja meg (a LIFEUP-fiókhoz kapcsolt Google-fiókkal). A
/// hozzáférés kb. egy óráig érvényes; utána a frissítéshez újra elég egy koppintás.
class GoogleCalendar {
  GoogleCalendar({FirebaseAuth? auth, http.Client? client, String? token})
      : _authOverride = auth,
        _client = client ?? http.Client(),
        _token = token,
        _tokenAt = token == null ? null : DateTime.now();

  static GoogleCalendar instance = GoogleCalendar();

  static const scope = 'https://www.googleapis.com/auth/calendar.readonly';
  static const _api = 'https://www.googleapis.com/calendar/v3';

  final FirebaseAuth? _authOverride;
  final http.Client _client;
  String? _token;
  DateTime? _tokenAt;

  /// A Google-fiók e-mail-címe, amivel összekapcsolta.
  String? email;

  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;

  /// Van-e még érvényes hozzáférés (ebben a munkamenetben).
  bool get hasAccess => _token != null && DateTime.now().difference(_tokenAt!) < const Duration(minutes: 50);

  /// A Google engedélyező ablaka. Ha a fiókhoz még nincs Google kapcsolva, hozzákapcsolja
  /// (így később Google-lel is be lehet lépni); ha már van, csak az engedélyt kéri.
  Future<void> connect() async {
    final user = _auth.currentUser;
    if (user == null) throw const GoogleCalendarException('Előbb jelentkezz be.');
    final provider = GoogleAuthProvider()
      ..addScope(scope)
      ..setCustomParameters({'prompt': 'select_account'});
    final linked = user.providerData.any((p) => p.providerId == 'google.com');
    final UserCredential result;
    try {
      if (linked) {
        result = kIsWeb ? await user.reauthenticateWithPopup(provider) : await user.reauthenticateWithProvider(provider);
      } else {
        result = kIsWeb ? await user.linkWithPopup(provider) : await user.linkWithProvider(provider);
      }
    } on FirebaseAuthException catch (e) {
      throw GoogleCalendarException(switch (e.code) {
        'popup-closed-by-user' || 'cancelled-popup-request' || 'web-context-canceled' => 'Megszakítottad. Bármikor újrapróbálhatod.',
        'popup-blocked' => 'A böngésző letiltotta a felugró ablakot. Engedélyezd, és próbáld újra.',
        'credential-already-in-use' || 'email-already-in-use' =>
          'Ez a Google-fiók már egy másik LIFEUP-fiókhoz tartozik. Válassz másik Google-fiókot.',
        'user-mismatch' => 'Azzal a Google-fiókkal lépj be, amelyik ehhez a fiókhoz tartozik.',
        'network-request-failed' => 'Nincs internet. Ellenőrizd a kapcsolatot!',
        _ => 'Nem sikerült összekapcsolni (${e.code}). Próbáld újra.',
      });
    }
    final token = (result.credential as OAuthCredential?)?.accessToken;
    if (token == null) throw const GoogleCalendarException('A Google nem adott hozzáférést a naptárhoz. Próbáld újra.');
    _token = token;
    _tokenAt = DateTime.now();
    email = result.user?.providerData.where((p) => p.providerId == 'google.com').firstOrNull?.email ?? result.user?.email;
  }

  void disconnect() {
    _token = null;
    _tokenAt = null;
  }

  Future<Map<String, dynamic>> _get(String path, [Map<String, String>? query]) async {
    final token = _token;
    if (!hasAccess || token == null) throw const GoogleCalendarException('Engedélyezd újra a hozzáférést.', reconnect: true);
    final http.Response r;
    try {
      r = await _client.get(Uri.parse('$_api$path').replace(queryParameters: query), headers: {'Authorization': 'Bearer $token'});
    } catch (_) {
      throw const GoogleCalendarException('Nincs internet. Ellenőrizd a kapcsolatot!');
    }
    if (r.statusCode == 401) {
      disconnect();
      throw const GoogleCalendarException('Lejárt a hozzáférés. Engedélyezd újra.', reconnect: true);
    }
    if (r.statusCode == 403) {
      final body = r.body;
      if (body.contains('accessNotConfigured') || body.contains('SERVICE_DISABLED')) {
        throw const GoogleCalendarException(
          'A Google Naptár elérése még nincs bekapcsolva az app Google-beállításaiban. Szólj az app üzemeltetőjének.',
        );
      }
      disconnect();
      throw const GoogleCalendarException('A Google nem engedte a hozzáférést. Engedélyezd újra, és pipáld be a naptárt.', reconnect: true);
    }
    if (r.statusCode != 200) throw GoogleCalendarException('A Google Naptár most nem válaszol (${r.statusCode}). Próbáld később.');
    return jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
  }

  /// A naptáraim (a fő naptár elöl).
  Future<List<GoogleCalendarInfo>> calendars() async {
    final data = await _get('/users/me/calendarList', {'minAccessRole': 'reader'});
    final list = [
      for (final c in data['items'] as List? ?? [])
        GoogleCalendarInfo(
          id: (c as Map)['id'] as String,
          name: (c['summaryOverride'] ?? c['summary'] ?? c['id']) as String,
          color: parseHexColor(c['backgroundColor'] as String?),
          primary: c['primary'] == true,
        ),
    ];
    list.sort((a, b) => a.primary == b.primary ? a.name.compareTo(b.name) : (a.primary ? -1 : 1));
    return list;
  }

  /// Egy naptár eseményei a [from, to) időszakban (az ismétlődők alkalmanként).
  Future<List<Event>> events(GoogleCalendarInfo calendar, {required DateTime from, required DateTime to}) async {
    final out = <Event>[];
    String? page;
    do {
      final data = await _get('/calendars/${Uri.encodeComponent(calendar.id)}/events', {
        'timeMin': from.toUtc().toIso8601String(),
        'timeMax': to.toUtc().toIso8601String(),
        'singleEvents': 'true',
        'orderBy': 'startTime',
        'maxResults': '2500',
        'pageToken': ?page,
      });
      for (final item in data['items'] as List? ?? []) {
        final e = parseGoogleEvent(Map<String, dynamic>.from(item as Map), calendarId: calendar.id, color: calendar.color);
        if (e != null) out.add(e);
      }
      page = data['nextPageToken'] as String?;
    } while (page != null && out.length < 5000);
    return out;
  }
}

/// A kiválasztott Google-naptárak frissítése (30 nappal ezelőttől egy évre előre).
/// Visszaadja, hány esemény jött át.
Future<int> syncGoogleCalendars(AppStore store, {GoogleCalendar? api, DateTime? now}) async {
  final google = api ?? GoogleCalendar.instance;
  final t = now ?? DateTime.now();
  final from = DateTime(t.year, t.month, t.day - 30);
  final to = DateTime(t.year + 1, t.month, t.day);
  final all = await google.calendars();
  final byCalendar = <String, List<Event>>{};
  for (final entry in store.googleCalendars.entries) {
    final info = all.where((c) => c.id == entry.key).firstOrNull ?? GoogleCalendarInfo(id: entry.key, name: entry.value);
    byCalendar[entry.key] = await google.events(info, from: from, to: to);
  }
  store.replaceGoogleEvents(byCalendar, at: t);
  return byCalendar.values.fold<int>(0, (sum, list) => sum + list.length);
}
