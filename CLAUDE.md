# Életrend

Magyar nyelvű életmód app Flutterben (elsősorban Android): programszervezés barátokkal, célkövető, hangulat- és hálanapló. A felhasználó kezdő, vele magyarul beszélünk.

## Munkamenet

- **A git mentést mindig Claude intézi**: minden befejezett és ellenőrzött változtatás után (`flutter analyze` + `flutter test` zöld) `git add . && git commit` rövid magyar üzenettel. A felhasználót nem kérjük mentésre. GitHubra/távoli tárolóba feltöltés előtt viszont kérdezni kell.
- Ellenőrzés: `flutter analyze`, `flutter test`, Android build: `flutter build apk --debug`.

## Gép sajátosságai

- A felhasználói mappa útvonalában szóköz és ékezet van, ezért:
  - Android SDK: `C:\Android\sdk`
  - TEMP/TMP: `C:\Temp` (különben a Gradle „Unable to establish loopback connection” hibával elszáll)
- Claude shelljéből a Gradle build csak sandbox nélkül fut.

## Felépítés

- `lib/store.dart`: teljes állapot, `shared_preferences`-ben tárolva; elérés: `StoreScope.of(context)`
- `lib/models.dart`: Event, Habit, JournalEntry, MoodTag (a bejegyzések a címke `id`-ját tárolják; saját kép base64-ben, böngészőben is megy)
- `lib/screens/tags_screen.dart`: címkék kezelése (láthatóság, sorrend, átnevezés, emoji/saját kép)
- `lib/theme.dart`: színek és téma; `lib/widgets/`: közös elemek, telefonkeret, térkép
- Térkép: OpenStreetMap (`flutter_map`), címkeresés: Nominatim (`lib/geocoding.dart`)

## Weboldal

- GitHub Pages: `.github/workflows/pages.yml` minden `main`-re feltöltés után tesztel, megépíti és kiteszi a webes verziót.
- Helyi release build Git Bashből nem megy (átírja a `/eletrend/` útvonalat), PowerShellből kell: `flutter build web --release --base-href /eletrend/`.

## Fiók és felhő

- Az app csak bejelentkezve használható (`lib/screens/auth_gate.dart`, `auth_screen.dart`); e-mail + jelszó (Firebase Auth). Névtelen munkamenetből regisztrálva a fiók megtartja az azonosítót (`linkWithCredential`).
- `lib/account.dart` `CloudSync`: `users/{uid}/{events|habits|journal|moodTags|moodFaces|meta}/{id}`, elemenként egy dokumentum (képek miatt). Csak a változás megy fel (sha1-ujjlenyomat, az eszközön tárolva: `syncUid`, `syncHashes`). Új eszközön: ha a fiókban van adat → letöltés, különben feltöltés. Visszatéréskor: push, aztán pull.
- A PIN és az ujjlenyomat beállítás eszközönként marad, nem megy a felhőbe.
- Widget-tesztekben `signInFakeAccount()` (test/helpers.dart), és a végén `Account.instance.sync?.stop()`.

## Barátok fiókkal

- `lib/friends.dart`: barátkód (`codes/{KÓD}`), névjegy (`people/{uid}`, sorozatok csak ha `shareStreaks`), jelölés (`requests/{címzett}/items/{küldő}`), barátság (`friendships/{uid}/list/{barát}`, csak meglévő jelölés elfogadásával), meghívás egy gombnyomással (`inbox/{uid}/items/{programId}` → a „Meghívásaim” közé kerül).
- Célok: heti cél (`perWeek`), mennyiség (`target`, `unit`, `counts`), saját emlékeztető (`reminderMinutes`, csak Androidon). A `doneDays` mindig a „kész” napokat tartalmazza.

## Közösségi és egyéb

- Kihívások: `lib/challenges.dart` (`challenges/{id}`, tagok `members`, haladás `progress/{uid}`, buzdítás csak +1). Célhoz köthető (`store.challengeHabits`).
- „Ki mit hoz?”: `events/{id}/items`. Időjárás: Open-Meteo (`lib/weather.dart`), a megosztott programban `lat`/`lng` is van.
- Jelvények: `lib/badges.dart` (számolt, `store.seenBadges`). Napközbeni hangulat: `store.checkIns`. Év visszatekintés: `YearReview`.

## Közösségi ötletek

- `lib/community.dart`: `ideas/{id}` (cím, leírás, emoji, címkék, hely: város/ország/koordináta), szavazat `ideas/{id}/votes/{uid}` (`liked`, `rating` 0–5), jelentés `ideas/{id}/reports/{uid}`. Az összesítés egyetlen `collectionGroup('votes')` lekérdezés; szűrés/rendezés a telefonon (`sortAndFilter`, legfeljebb 300 ötlet).
- „Közelben”: a `store.homePlace`-től 30 km. Ötletadó: beépített vagy közösségi forrás.

## Bumpok és effektek

- `lib/bumps.dart`: `bumps/{címzett}/items/{id}` (szöveg, matrica, kép/GIF base64 ≤450 KB, hang base64 ≤20 mp, effekt, program), `bumpSettings/{uid}` (`off`, `muted`). Csak barát küldhet (szabály).
- Fogadás: az `AuthGate` figyeli; előtérben effekt + SnackBar, háttérben helyi értesítés (`Notifications.showBump`, payload `bump:id`), koppintásra `openBump` (program + felugró effekt).
- **Bezárt appra push nincs** — ahhoz Blaze csomag + Cloud Function + FCM token kell (még nincs megírva).
- `lib/widgets/effects.dart`: `playEffect`/`playEffectOn` (konfetti, tűzijáték, szívek, emojieső, felugró-leeső kép). `store.effectsOn` kapcsolja.
- Program háttér: `lib/event_background.dart` (témák vagy JPEG ≤1000 px), a megosztott programban is.

## Admin

- `lib/admin.dart` + `lib/screens/admin_screen.dart`: áttekintés, felhasználók (felfüggesztés `bans/{uid}`, adattörlés), hibák (`errors`, csak release buildben jelent az app), visszajelzések (`feedback`), megosztott programok moderálása.
- Admin az, akinek van `admins/{uid}` dokumentuma; **csak a Firebase konzolban** lehet felvenni (a szabályok az appból tiltják).
- Az admin a napló tartalmát nem látja, csak a darabszámokat (`profiles/{uid}`).
- `appVersion` (lib/admin.dart) a pubspec verzióval együtt léptetendő.

## Közös programok (Firebase)

- Projekt: `lifest-c95f3` (a felhasználó Google-fiókja). Beállítások: `lib/firebase_options.dart`; névtelen bejelentkezés + Firestore.
- `lib/social.dart`: meghívás (`events/{id}`), visszajelzés + szavazat (`rsvps/{uid}`), üzenőfal (`messages`). Csak első használatkor kapcsolódik.
- Meghívólink: `https://mikii561.github.io/eletrend/?e=<id>` → `InviteScreen`.
- **A szabályok (`firestore.rules`) módosítás után a Firebase konzolban kézzel kell beilleszteni** (Firestore → Rules → Publish); nincs Firebase CLI.
- Tesztek: `fake_cloud_firestore` + `firebase_auth_mocks`, a valódi szerverhez nem nyúlnak.

## Ütemterv

1. ~~Emlékeztető értesítések~~ (kész)
2. Kipróbálás a felhasználó telefonján
3. Firebase: bejelentkezés, valódi barátok és meghívók
4. ~~Ikon, sötét mód~~ (kész), Google Play

## Napló zárolása

- `lib/screens/pin_screen.dart`: PIN (sózott SHA-256, nincs a mentésben) + ujjlenyomat (`local_auth`, csak Androidon). Ehhez a `MainActivity` `FlutterFragmentActivity`, a `LaunchTheme` szülője `Theme.AppCompat…`.
- **Figyelem:** a `dart run flutter_native_splash:create` felülírja a `styles.xml`-eket, utána az AppCompat szülőt vissza kell írni.

## Kezdőképernyő-widget

- `lib/habits_widget.dart` (adatok + koppintás a háttérben) és `android/.../HabitsWidgetProvider.kt` + `res/layout/habits_widget.xml`. Max 5 cél; a `day` kulcs alapján éjfél után üresnek mutatja. Az app visszatéréskor `store.reload()`-dal beolvassa a widgeten tett változást.

## Értesítések

- `lib/notifications.dart`: helyi, ütemezett értesítések (flutter_local_notifications), csak Androidon. Minden store-változáskor mindent újraütemez (napi 7 nap előre, programonként előző este 18:00 + 1 órával előtte).
- Emulátor: `Medium_Phone_API_37.0`; indítás: `C:\Android\sdk\emulator\emulator.exe -avd Medium_Phone_API_37.0` (a `flutter emulators --launch` csendben nem indítja el).

## Funkciók, heti összefoglaló, közös cél

- Kikapcsolható részek: `lib/features.dart` (`Feature` enum), `store.hiddenFeatures`, `store.shows(f)`. A Beállítások → Funkciók és a bevezető 3. lépése állítja.
- Beállítások: főoldalon csoportok, mindegyik saját aloldallal (`settings_screen.dart`).
- Heti összefoglaló: `WeekSummary` (stats.dart) + `week_summary_screen.dart`; értesítés vasárnap 19:00 (`payload: weekly`), böngészőben a Ma képernyő kártyája (`widgets/nudge_cards.dart`, ott az esti napló-kártya is).
- Közös cél: a kihívás-rendszert használja `kind: 'goal'`-lal (`Challenges.shareGoal` / `joinSharedGoal`, `screens/shared_goal_widgets.dart`); a Kihívások listája ezeket kiszűri. Szabálymódosítás nem kellett.
- Offline: a `CloudSync` mindig a szerverről olvas (`Source.server`), és nem tölt le, amíg helyi, fel nem töltött változás van.

## Telepíthető webapp (PWA) és push

- `web/sw.js`: saját service worker (a Flutteré elavult, a `web/flutter_bootstrap.js` nem tölti be): „előbb a hálózat” gyorsítótár + Firebase Messaging. A `web/push.js` regisztrálja, és ad JS függvényeket (`eletrendPush`) a `lib/push_web.dart`-nak.
- A beépített böngészőpanel nem támogat service workert; ott csak szimulálva ellenőrizhető.
- `lib/push.dart`: `Push.vapidKey` (Firebase konzol → Cloud Messaging → Web Push), token: `users/{uid}/push/{sha1}`. iPhone-on csak kezdőképernyőről (iOS 16.4+). Kártya a Ma képernyőn: `InstallAndPushCard`.
- Értesítésből nyíló link: `?n=bump:<id>` / `?n=weekly` → `Notifications.pendingTap`; program: `?e=<id>`.
- `functions/index.js`: Cloud Functions (bump, meghívó, jelölés, üzenőfal, közös cél/kihívás, 15 percenkénti esti/heti emlékeztető). Blaze kell. A `REGION` a Firestore helyéhez igazodjon. Telepítés Google Cloud Shellből: `firebase deploy --only functions`. A GitHub workflow csak betölti (ellenőrzés).
- Ikon: `tool/icon_test.dart` (márkaszín), utána `dart run flutter_launcher_icons` és `flutter_native_splash:create` (a styles.xml-eket vissza kell állítani).
