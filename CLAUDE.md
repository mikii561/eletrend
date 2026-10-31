# LIFEUP

Magyar nyelvű naptár- és életszervező app Flutterben (web/PWA + Android): naptár, teendők, célok, barátok elérhetősége, közös programok. Szlogen: „Az életed. Az embereid. Az időd.” (Korábbi neve Életrend; a csomag, a mappa és a webcím maradt `eletrend`.) A felhasználó kezdő, vele magyarul beszélünk.

## Munkamenet

- **A git mentést mindig Claude intézi**: minden befejezett és ellenőrzött változtatás után (`flutter analyze` + `flutter test` zöld) `git add . && git commit` rövid magyar üzenettel. A felhasználót nem kérjük mentésre. GitHubra/távoli tárolóba feltöltés előtt viszont kérdezni kell.
- Ellenőrzés: `flutter analyze`, `flutter test`, Android build: `flutter build apk --debug`.
- Képernyőképek a dizájn ellenőrzéséhez: `ELETREND_SHOTS=<mappa> flutter test tool/screens_test.dart`.
- `dart format` csak a ténylegesen módosított fájlokra (különben az egész mappát átírja).

## Gép sajátosságai

- A felhasználói mappa útvonalában szóköz és ékezet van, ezért:
  - Android SDK: `C:\Android\sdk`
  - TEMP/TMP: `C:\Temp` (különben a Gradle „Unable to establish loopback connection” hibával elszáll)
- Claude shelljéből a Gradle build csak sandbox nélkül fut.
- A sorvégek a munkakönyvtárban LF-ek; a perl/sed cserék így illeszkednek.

## Felépítés

Alsó menü (`lib/main.dart` `HomeShell`): Főoldal · Naptár · **Létrehozás** (kiemelt, középen, `create_sheet.dart`) · Barátok · Profil.

- `lib/models.dart`: `Event` (naptárbejegyzés: kezdés, hossz, egész napos, `EventCategory`, saját szín, hely, jegyzet, `Repeat` + kihagyott alkalmak, emlékeztető, `busy`, közösnél `shareId`/`limit`/`inviteOnly`), `Occurrence` (egy alkalom), `TaskItem` (határidő, időblokk: `scheduled`), `Habit` (cél), `FriendGroup`, `Invite`, `FriendInfo`. `newId()` idő + sorszám + véletlen (Windows-on durva az óra).
- `lib/store.dart`: teljes állapot `shared_preferences`-ben; elérés `StoreScope.of(context)`. Naptár-lekérdezések (`occurrencesOn/Between`, `tasksOn`, `busyIntervals`, `statusAt`), adatvédelmi beállítások, `HomeCard` (Főoldal kártyák sorrendje/elrejtése), export/import (`exportData`, `importData`). A régi Életrend-beállításokat (`_legacySettings`) átveszi.
- `lib/availability.dart`: tiszta számolás (UTC időszakok, „ráérek” sávok időzónával, `findCommonTime`). `availability_service.dart`: Firestore.
- `lib/formatting.dart`: magyar dátum/idő/ismétlődés/emlékeztető kiírás.
- `lib/theme.dart`: burgundi–krém–zsálya paletta, `AppColors.category()`, `status()`, `ofEvent()`, `Space` térközök; `widgets/common.dart`: közös elemek (Pill, confirm, Loading/Error/EmptyState, SettingsTile…).
- Képernyők: `home_screen.dart`, `calendar_screen.dart` (Nap/Hét/Hónap/Lista; üres időre koppintva új bejegyzés), `event_editor.dart`, `event_detail_screen.dart` (`EventHeader` is), `task_editor.dart` (`TaskTile`), `find_time_screen.dart`, `friends_screen.dart` (barát lap, csoportok), `profile_screen.dart` (+ értesítések, Főoldal testreszabása), `privacy_screen.dart`, `status_sheet.dart`, `onboarding_screen.dart`, `nudge_screens.dart`, `invite_screen.dart`, `social_widgets.dart` (`SharedEventSection`, `showFriendPicker`, `inviteFriendsTo`).
- Térkép: OpenStreetMap (`flutter_map`), címkeresés: Nominatim (`lib/geocoding.dart`).

## Weboldal

- GitHub Pages: `.github/workflows/pages.yml` minden `main`-re feltöltés után tesztel, megépíti és kiteszi a webes verziót.
- Helyi release build Git Bashből nem megy (átírja a `/eletrend/` útvonalat), PowerShellből kell: `flutter build web --release --base-href /eletrend/`.

## Fiók és felhő

- Az app csak bejelentkezve használható (`lib/screens/auth_gate.dart`, `auth_screen.dart`); e-mail + jelszó vagy Google (Firebase Auth). Névtelen munkamenetből regisztrálva a fiók megtartja az azonosítót (`linkWithCredential`).
- `lib/account.dart` `CloudSync`: `users/{uid}/{events|tasks|habits|groups|meta}/{id}`, elemenként egy dokumentum. Csak a változás megy fel (sha1-ujjlenyomat, az eszközön: `syncUid`, `syncHashes`). Mindig a szerverről olvas, és nem tölt le, amíg helyi, fel nem töltött változás van. A régi `journal`, `moodTags`, `moodFaces` gyűjteményekhez nem nyúl (csak fióktörléskor).
- Widget-tesztekben `signInFakeAccount()` (test/helpers.dart), a végén a szolgáltatások `stop()`-ja.

## Barátok, elérhetőség, adatvédelem

- `lib/friends.dart`: barátkód (`codes/{KÓD}`), névjegy (`people/{uid}`: név, kód; engedéllyel sorozatok és születésnap „HH-NN”; `invites`: hívhatnak-e), jelölés (`requests/{címzett}/items/{küldő}`), barátság (`friendships/{uid}/list/{barát}`), meghívás (`inbox/{uid}/items/{programId}`), letiltás (`blocks/{uid}/list/{másik}`), jelentés (`reports/{id}`). A barátlista az eszközön is megvan (`store.friendsCache`, visszatéréskor `refreshCache`).
- Elérhetőség: `availability/{uid}` (kézi állapot, foglalt időszakok 28 napra UTC-ben **cím nélkül**, „ráérek” sávok, időzóna-eltérés, `viewers`). Alapból senki nem látja (`AvailabilityShare.nobody`); barátok vagy kiválasztott csoportok. Csoportok csak az eszközön/fiókban (`users/{uid}/groups`).
- Közös időpont: `FindTimeScreen` → `findCommonTime`; akiről nincs adat, „nem tudjuk”.
- Bökés: `lib/nudges.dart`, `nudges/{címzett}/items/{küldő}_{ÉÉÉÉHHNN}_{0–2}` (napi 3, a szabály kényszeríti: meglévőt nem lehet felülírni), `nudgeSettings/{uid}` (`off`, `muted`).

## Közös programok

- `lib/social.dart`: `events/{id}` (cím, idő, hossz, kategória, hely, jegyzet, `limit`, `inviteOnly`, `invitedUids`, `going`), visszajelzés + szavazat (`rsvps/{uid}`: Megyek/Talán/Nem), hozzászólás (`messages`), reakció (`reactions/{uid}`). A „going” listát a résztvevők csak a saját nevükkel módosíthatják, a létszámot a szabály ellenőrzi.
- Meghívólink: `https://mikii561.github.io/eletrend/?e=<id>` → `InviteScreen` („Hozzáadom a naptáramhoz”: `SharedEvent.toEvent()`, azonosító `inv-…`).
- Kihívások és közös cél: `lib/challenges.dart` (`challenges/{id}`, `kind: 'goal'` = közös cél), változatlanul.

## Emlékek (közös fotók)

- `lib/memories.dart`: `events/{id}/photos/{fotó}` (feltöltő, 320 px-es előnézet base64, `audience`: `all`/`going`, `allowDownload`) és `events/{id}/photoData/{fotó}` (a teljes kép, ≤ 650 KB JPEG, base64). **Firestore-ban, nem Storage-ban**: az új Storage-tárolók Blaze csomagot kérnének. Jegyzet: `users/{uid}/myPhotos/{fotó}` (fióktörléshez, index nélkül).
- A „csak résztvevőknek” fotókat külön lekérdezés hozza (`Memories.watch`), mert a szabály lekérdezésnél nem szűr. A letöltés tiltása csak a felületen érvényes (képernyőképet nem lehet megakadályozni).
- `pickMemory()`: a múltbeli, nem ismétlődő közös programok közül kerek évforduló (1 hete, 1/3/6 hónapja, N éve), különben háromnaponta másik (legalább 2 hete volt). Főoldal kártya (`HomeCard.memories`), értesítés aznap 10-kor (`memoryReminders`).
- Felület: `screens/memory_screen.dart` (`MemoryStrip`, `MemoryScreen`, `uploadMemoryPhotos`), a közös program oldalán az „Emlékek” rész a program kezdete után jelenik meg.

## Szabályok és szerver

- **A szabályok (`firestore.rules`) módosítás után a Firebase konzolban kézzel kell beilleszteni** (Firestore → Rules → Publish); nincs Firebase CLI.
- Projekt: `lifest-c95f3`. Tesztek: `fake_cloud_firestore` + `firebase_auth_mocks` (a szabályokat nem ellenőrzik!).
- `functions/index.js`: push értesítések (bökés, meghívó, jelölés, hozzászólás, kihívás). Blaze csomag kellene hozzá, amit a felhasználó **nem kér** (nem akar fizetni). Bezárt appra push ezért nincs; ingyenes alternatíva: GitHub Actions ütemezett küldés (még nincs megírva).

## Admin

- `lib/admin.dart` + `lib/screens/admin_screen.dart`: áttekintés, felhasználók (felfüggesztés `bans/{uid}`, adattörlés), hibák (`errors`, csak release buildben), visszajelzések (`feedback`), megosztott programok moderálása, jelentések (`reports`).
- Admin az, akinek van `admins/{uid}` dokumentuma; **csak a Firebase konzolban** lehet felvenni.
- Az admin a tartalmat nem látja, csak darabszámokat (`profiles/{uid}`).
- `appVersion` (lib/admin.dart) a pubspec verzióval együtt léptetendő.

## Értesítések

- `lib/notifications.dart`: helyi, ütemezett értesítések (csak Androidon). `Notifications.plan()` számolja (tesztelhető): bejegyzések a saját emlékeztetőjük szerint 14 napra, feladatok (beosztott idő / határidő napján 9:00), cél-emlékeztetők, barátok születésnapja. Engedélyt a bevezető vagy a Profil → Értesítések kér, magyarázattal.
- Böngészőben: PWA (`web/sw.js`, `web/push.js`, `lib/push.dart`); a web push `Push.vapidKey` üres, így ki van kapcsolva.
- Emulátor: `Medium_Phone_API_37.0`; indítás: `C:\Android\sdk\emulator\emulator.exe -avd Medium_Phone_API_37.0`.

## Ikon és indítóképernyő

- `tool/icon_test.dart` rajzolja (burgundi háttér, krém pipa, zsálya pötty), utána `dart run flutter_launcher_icons` és `dart run flutter_native_splash:create`.

## Ütemterv (MVP után)

- **Google Naptár automatizálása (a felhasználó kérte):** most „Testing” módban csak a kézzel felvett test userek kapcsolhatják össze (max. 100). Cél: OAuth-ellenőrzés (verification), hogy bárki használhassa felvétel nélkül. Kell hozzá: adatvédelmi tájékoztató oldal, saját domain (a github.io nem elég), demó videó, néhány hét Google-átnézés. A test userek felvétele API-val nem automatizálható.
- AI asszisztens (fizetős API + szerver kell: előbb megbeszélni a költséget), spontán tervek („Ki ér rá ma este?”), csoportos szavazás helyszínre/programra, születésnap-ajándék szervezés, emlékek (fotók), naptár-import (Google/Apple), bezárt appra push (ingyenes úton).

## Bemutató és tippek

- `lib/widgets/app_tour.dart`: 9 lépéses bemutató a Főoldalon (kiemelés + kártya); első megnyitáskor magától (`store.tourDone`), a Profilból újraindítható (`HomeShell.startTour`). Az alsó menü fülét a `TourKeys.navBar` öt egyforma részéből számolja.
- `lib/widgets/memories_demo.dart`: rajzolt, végtelenített animáció (emlék → galéria → nagy fotó); a bemutató Emlékek-lépésében és a `showMemoriesExample` ablakban. Tesztben `pumpAndSettle` helyett `pump(…)` kell, amíg látszik.
- `lib/tips.dart`: „Tudtad?” tippek a Főoldalon, kétnaponta legfeljebb egy (`pickTip`); a bezárt nem jön vissza (`store.closeTip`, eszközönként), Profil → Főoldal testreszabása → Tippek kapcsoló (`tipsOn`).

## Google Naptár

- `lib/google_calendar.dart`: engedélykérés a Firebase Google-szolgáltatóval (`calendar.readonly` scope; nincs Google a fiókon → `linkWithPopup`, van → `reauthenticateWithPopup`), az OAuth hozzáférés kb. 1 óráig él (csak memóriában). Calendar API: naptárlista + események (`singleEvents=true`, 30 nappal ezelőttől 1 évre előre).
- Az átjött események `Event`-ek `source: 'google:{naptár}'`, `externalId` mezővel: csak olvashatók, emlékeztető nélkül (a Google maga emlékeztet), frissítéskor naptáranként cserélődnek (`store.replaceGoogleEvents`). Beállítások: `googleCalendars`, `googleEmail`, `googleSyncedAt`.
- Felület: `screens/google_calendar_screen.dart` (Profil, Naptár fejléc, Létrehozás menü, tipp).
- **Üzemeltetői beállítás kell**: Google Cloud (lifest-c95f3) → Google Calendar API bekapcsolása, OAuth consent screen: `calendar.readonly` scope; tesztelési módban a felhasználókat „Test users”-ként fel kell venni (vagy közzététel → ellenőrizetlen app figyelmeztetés, max. 100 felhasználó).

## Animációk

- `lib/widgets/motion.dart`: időtartamok (`Motion.fast/medium/slow`), görbék, `Motion.of(context, d)` (csökkentett mozgásnál nulla), `FadeSlideIn` (egyszeri beúszás, lépcsőzhető).
- Bemutató: a kiemelés `RectTween`-nel csúszik, a kártya `AnimatedSwitcher`-rel úszik át, az egész be/ki halványul. Tesztben a lépések között több képkocka kell (`pump(300ms)` ×4).
- Tipp bezárása: kicsúszik + `SizeTransition` összecsukás, csak utána `closeTip`. Fülváltás: az új fül `FadeSlideIn` (a régi nem marad meg, mert a Főoldalon GlobalKey-ek vannak). Naptár: lapozáskor irány szerinti csúszás (`_dir`, `_periodKey`). Oldalak: `FadeForwardsPageTransitionsBuilder` (theme.dart).
