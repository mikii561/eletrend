import 'dart:convert';

import 'package:eletrend/google_calendar.dart';
import 'package:eletrend/models.dart';
import 'package:eletrend/screens/event_detail_screen.dart';
import 'package:eletrend/screens/google_calendar_screen.dart';
import 'package:eletrend/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

Future<AppStore> emptyStore() {
  SharedPreferences.resetStatic();
  SharedPreferences.setMockInitialValues({});
  return AppStore.load();
}

/// Egy kitalált Google Naptár: két naptár, a fő naptárban két esemény (két oldalon), a másikban egy.
MockClient fakeGoogle({List<String>? seen, int status = 200, String body = ''}) => MockClient((request) async {
      seen?.add(request.url.path);
      if (status != 200) return http.Response(body, status);
      expect(request.headers['Authorization'], 'Bearer token');
      final path = request.url.path;
      Map<String, dynamic> json;
      if (path.endsWith('/calendarList')) {
        json = {
          'items': [
            {'id': 'munka@group', 'summary': 'Munka', 'backgroundColor': '#4f5d73'},
            {'id': 'gabi@gmail.com', 'summary': 'Gabi', 'backgroundColor': '#0b8043', 'primary': true},
          ],
        };
      } else if (path.contains('gabi%40gmail.com') || path.contains('gabi@gmail.com')) {
        json = request.url.queryParameters['pageToken'] == null
            ? {
                'items': [
                  {'id': 'a', 'summary': 'Fogorvos', 'start': {'dateTime': '2030-03-05T13:00:00+01:00'}, 'end': {'dateTime': '2030-03-05T14:00:00+01:00'}},
                ],
                'nextPageToken': 'p2',
              }
            : {
                'items': [
                  {'id': 'b', 'summary': 'Anyu szülinapja', 'start': {'date': '2030-03-07'}, 'end': {'date': '2030-03-08'}},
                ],
              };
      } else {
        json = {
          'items': [
            {'id': 'c', 'summary': 'Megbeszélés', 'start': {'dateTime': '2030-03-06T09:00:00Z'}, 'end': {'dateTime': '2030-03-06T10:00:00Z'}},
          ],
        };
      }
      return http.Response.bytes(utf8.encode(jsonEncode(json)), 200, headers: {'content-type': 'application/json'});
    });

void main() {
  setUp(signInFakeAccount);
  setUpAll(() => initializeDateFormatting('hu'));

  group('Google-esemény átalakítása', () {
    test('időpontos esemény helyi időre, a Google színével, emlékeztető nélkül', () {
      final e = parseGoogleEvent({
        'id': 'x',
        'summary': ' Fogorvos ',
        'location': 'Rendelő',
        'description': '<b>Hozd</b> a kártyát',
        'start': {'dateTime': '2030-03-05T12:00:00Z'},
        'end': {'dateTime': '2030-03-05T13:30:00Z'},
      }, calendarId: 'cal', color: 0xFF0B8043)!;
      expect(e.title, 'Fogorvos');
      expect(e.start, DateTime.utc(2030, 3, 5, 12).toLocal());
      expect(e.durationMin, 90);
      expect(e.place, 'Rendelő');
      expect(e.notes, 'Hozd  a kártyát');
      expect(e.color, 0xFF0B8043);
      expect(e.reminderMin, isNull);
      expect(e.isExternal, isTrue);
      expect(e.source, 'google:cal');
      expect(e.externalId, 'x');
      expect(Event.fromJson(e.toJson()).toJson(), e.toJson());
    });

    test('egész napos nem foglal; „szabadnak mutat” sem; a törölt kimarad; cím nélkül is megy', () {
      final day = parseGoogleEvent({'id': 'd', 'summary': 'Szülinap', 'start': {'date': '2030-03-07'}, 'end': {'date': '2030-03-09'}}, calendarId: 'c')!;
      expect(day.allDay, isTrue);
      expect(day.start, DateTime(2030, 3, 7));
      expect(day.durationMin, 2 * 1440);
      expect(day.busy, isFalse);
      final free = parseGoogleEvent({
        'id': 'f',
        'transparency': 'transparent',
        'start': {'dateTime': '2030-03-05T12:00:00Z'},
        'end': {'dateTime': '2030-03-05T13:00:00Z'},
      }, calendarId: 'c')!;
      expect(free.busy, isFalse);
      expect(free.title, '(nincs cím)');
      expect(parseGoogleEvent({'id': 'z', 'status': 'cancelled', 'start': {}, 'end': {}}, calendarId: 'c'), isNull);
      expect(parseHexColor('#ff0000'), 0xFFFF0000);
      expect(parseHexColor('piros'), isNull);
    });
  });

  test('naptárak (a fő elöl), események több oldalon; frissítéskor nincs duplikáció; kivett naptár eseményei törlődnek', () async {
    final api = GoogleCalendar(client: fakeGoogle(), token: 'token');
    final calendars = await api.calendars();
    expect(calendars.map((c) => c.name), ['Gabi', 'Munka']);
    expect(calendars.first.primary, isTrue);

    final store = await emptyStore();
    store.saveEvent(Event(id: 'sajat', title: 'Saját', start: DateTime(2030, 3, 5, 18)));
    store.setGoogleCalendars({'gabi@gmail.com': 'Gabi', 'munka@group': 'Munka'}, email: 'gabi@gmail.com');
    expect(await syncGoogleCalendars(store, api: api, now: DateTime(2030, 3, 1)), 3);
    expect(store.events.map((e) => e.title).toSet(), {'Saját', 'Fogorvos', 'Anyu szülinapja', 'Megbeszélés'});
    expect(await syncGoogleCalendars(store, api: api, now: DateTime(2030, 3, 1)), 3);
    expect(store.events, hasLength(4));
    expect(store.googleSyncedAt, DateTime(2030, 3, 1));

    // Ütközésnél a Google-esemény is számít. (Az időpontot a beolvasott eseményből vesszük, hogy a gép
    // időzónájától független legyen.)
    final dentist = store.events.firstWhere((e) => e.title == 'Fogorvos').start;
    expect(store.conflictsFor(start: dentist.add(const Duration(minutes: 30)), durationMin: 30).single.title, 'Fogorvos');

    store.setGoogleCalendars({'gabi@gmail.com': 'Gabi'});
    expect(store.events.map((e) => e.title), isNot(contains('Megbeszélés')));
    store.disconnectGoogle();
    expect(store.events.map((e) => e.title), ['Saját']);
    expect(store.googleConnected, isFalse);
  });

  test('hibák: lejárt hozzáférés → újra engedélyezés; kikapcsolt Google Naptár API → érthető üzenet', () async {
    final expired = GoogleCalendar(client: fakeGoogle(status: 401), token: 'token');
    await expectLater(expired.calendars(), throwsA(isA<GoogleCalendarException>().having((e) => e.reconnect, 'reconnect', isTrue)));
    expect(expired.hasAccess, isFalse);

    final disabled = GoogleCalendar(client: fakeGoogle(status: 403, body: '{"error":{"errors":[{"reason":"accessNotConfigured"}]}}'), token: 'token');
    await expectLater(
      disabled.calendars(),
      throwsA(isA<GoogleCalendarException>().having((e) => e.message, 'message', contains('nincs bekapcsolva'))),
    );
    await expectLater(GoogleCalendar(client: fakeGoogle()).calendars(), throwsA(isA<GoogleCalendarException>()));
  });

  testWidgets('a Google Naptár oldal: egyszerű bevezető egy gombbal; összekapcsolva az állapot', (tester) async {
    tester.view.physicalSize = const Size(400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = (await tester.runAsync(emptyStore))!;
    await tester.pumpWidget(StoreScope(store: store, child: const MaterialApp(home: GoogleCalendarScreen())));
    expect(find.text('Hozd át a Google Naptáradat'), findsOneWidget);
    expect(find.text('Google Naptár hozzáadása'), findsOneWidget);

    store.setGoogleCalendars({'gabi@gmail.com': 'Gabi'}, email: 'gabi@gmail.com');
    await tester.pumpAndSettle();
    expect(find.text('Összekapcsolva'), findsOneWidget);
    expect(find.text('Frissítés most'), findsOneWidget);
    expect(find.text('Leválasztás'), findsOneWidget);
  });

  testWidgets('Google-esemény részletei: nincs szerkesztés és törlés, látszik, honnan jött', (tester) async {
    final store = (await tester.runAsync(emptyStore))!;
    final e = parseGoogleEvent({
      'id': 'x',
      'summary': 'Fogorvos',
      'start': {'dateTime': '2030-03-05T12:00:00Z'},
      'end': {'dateTime': '2030-03-05T13:00:00Z'},
    }, calendarId: 'c')!;
    store.replaceGoogleEvents({'c': [e]});
    await tester.pumpWidget(StoreScope(store: store, child: MaterialApp(home: EventDetailScreen(eventId: e.id))));
    await tester.pumpAndSettle();
    expect(find.text('Google Naptárból'), findsOneWidget);
    expect(find.byTooltip('Szerkesztés'), findsNothing);
    expect(find.byTooltip('Törlés'), findsNothing);
  });
}
