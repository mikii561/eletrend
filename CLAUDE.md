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
- `lib/theme.dart`: burgundi–krém–zsálya paletta; megjelenések (Profil → Megjelenés; `LightPalette` + `store.palette` → `AppColors.palette`, a színkészletek a theme.dart `_schemes`-ben): **bézs** (alap, krém + burgundi: csak ez burgundi!), **fehér** (a megszokott fehér app), **narancs** (égetett narancs #D5360C, elefántcsont #E6D5BD, puha fekete #101010), **kobalt** (kobalt #0736BB, mandarin #FF7900 mint `highlight`, krém #F5E6C8), **magenta** (fekete #0A0A0A, törtfehér #F2F0ED, magenta #F20B8B; `isDark: true`: sötét kinézetű, `AppColors.plainDark` = false, ezért a sima sötéttől független) és **sötét** (a megszokott sötét mód, a világos készlettől független). Új megjelenés: új `LightPalette` érték + `_schemes` bejegyzés (a választó és a színminta magától felveszi), `AppColors.category()`, `status()`, `ofEvent()`, `Space` térközök; `widgets/common.dart`: közös elemek (Pill, confirm, Loading/Error/EmptyState, SettingsTile…).
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
- Bökés képpel és hangüzenettel: a `nudges/…` dokumentumban `image` (fotó 800 px-re kicsinyítve JPEG, vagy GIF ≤ 450 KB; base64), `audio` + `audioMime` (≤ 20 mp, 24 kbps AAC/Opus, base64); szöveg nélkül is elmehet, ha van csatolmány. Előkészítés/felvétel: `lib/voice.dart` (`record` csomag, Androidon RECORD_AUDIO), lejátszás: `widgets/voice_player.dart` (`audioplayers`); képes/hangos bökésnél az `openNudge` a `NudgeDetailScreen`-t nyitja. **Szabályváltozás kell** (image/audio/audioMime mezők, méretkorlátok); addig a küldés a „napi keret” hibával elbukik, mert a `send` minden elutasítást sorszám-foglaltságnak vesz.

## Közös programok

- `lib/social.dart`: `events/{id}` (cím, idő, hossz, kategória, hely, jegyzet, `limit`, `inviteOnly`, `invitedUids`, `going`), visszajelzés + szavazat (`rsvps/{uid}`: Megyek/Talán/Nem), hozzászólás (`messages`), reakció (`reactions/{uid}`). A „going” listát a résztvevők csak a saját nevükkel módosíthatják, a létszámot a szabály ellenőrzi.
- Meghívólink: `https://mikii561.github.io/eletrend/?e=<id>` → `InviteScreen` („Hozzáadom a naptáramhoz”: `SharedEvent.toEvent()`, azonosító `inv-…`).
- Kihívások és közös cél: `lib/challenges.dart` (`challenges/{id}`, `kind: 'goal'` = közös cél), változatlanul.
- Új kihívás űrlap: az ötletek (`challengeIdeas`) mellett saját név, emoji, kép a galériából (`image` mező: 192 px-es négyzetes JPEG base64-ben, `prepareChallengeIcon`; megjelenítés: `ChallengeIcon`) és saját napszám (1–`maxChallengeDays` = 366, a szabály is ennyit enged). Szabályváltozás nem kellett.
- Kihívás-értesítés: `Challenges.listenActivity` (az `AuthGate` indítja) figyeli a kihívásaim `progress` dokumentumait: ha valaki más **ma** elvégezte, és én még nem → „💪 Anna már megcsinálta! … most te jössz”; ha megbuzdítottak (`cheers` nőtt) → „👏 Megbuzdítottak!”. Az induló állapotról nem értesít. Előtérben SnackBar, háttérben helyi értesítés (`Notifications.showChallenge`, csatorna „Kihívások”, payload `challenge:id`, koppintásra `ChallengeDetail`). **Bezárt appra nincs** (ahhoz szerveroldali push kell, lásd Bumpok). A kihívás oldalán „Buzdíts mindenkit, aki ma még nem csinálta meg” gomb (`cheerAll`). Szabályváltozás nem kellett.

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
- Áttekintés: szűrő (`StatRange`: 7 nap / 30 nap / 3 hónap / 1 év), csempék és oszlopdiagramok (`TrendSeries`, `Trends`), a változás az előző, ugyanolyan hosszú időszakhoz képest: `+3` zölden, `-2` pirosan (a hibáknál fordítva). Az „aktív” az `activeDays` mezőből jön (`profiles/{uid}.activeDays`, naponta egy dátum, külön írással, hogy a régi szabályokkal se törjön el); előtte csak a `lastSeen` van meg. A hibák és visszajelzések a legutóbbi 200-ig látszanak.
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

## Első belépés és profilkép

- `lib/screens/onboarding_screen.dart`: üdvözlés → „Első lépések” (`Beállítom később` = egyből a kész oldal) → születésnap (kihagyható) → barátok (barátkód, kihagyható) → profilkép + név (név kötelező) → „Kész is vagyunk” → `finishOnboarding` → a Főoldalon magától indul a bemutató. A név/kép/születésnap már a profil-lépésnél mentődik, az `onboarded` csak a végén áll át (különben eltűnne a kész oldal). A funkció-választás és a „mikor érsz rá” lépés kikerült (Profil → Főoldal testreszabása / Adatvédelem).
- Profilkép: `store.profilePhoto` (256 px négyzetes JPEG base64, `lib/square_image.dart`; fiókkal szinkronban), választó: `widgets/profile_photo_button.dart` (kamera / galéria / törlés), megjelenítés: `NameAvatar(photo:)`. A barátok a `people/{uid}.photo` mezőből látják (külön írás, hogy a régi szabályokkal se törjön el a névjegy; a szabály ≤ 60 000 karaktert enged).
- Regisztráció után e-mail-megerősítés (`lib/screens/verify_email_screen.dart`): Firebase megerősítő levél **linkkel** (nem kóddal: a 6 jegyű kódhoz levélküldő szerver kellene, az Blaze vagy külső szolgáltatás). Az `AuthGate` addig nem indít szinkront (`Account.needsVerification`: e-mail-es, nem megerősített, `Account.verificationFrom` utáni fiók; a régebbi fiókokat nem zárja ki, a Google-fiók eleve megerősített). Megerősítés (pár mp-enként és visszatéréskor ellenőrzi) → „Sikeres regisztráció!” → Tovább → szinkron + első lépések. Az első lépések csak az új regisztrációnál jönnek: `store.beginOnboarding()` (AuthScreen regisztrációkor és új Google-fióknál; eszközön tárolt `onboardingPending`), bejelentkezésnél nem. A levél szövege a Firebase konzolban (Authentication → Templates) magyarra állítható.

## Nyelvek (magyar, angol)

- Az app alapnyelve **angol**; a felhasználó az első lépések elején (üdvözlés után), a bejelentkezés tetején és a Profil → Nyelv alatt válthat. Tárolás: `store.language` (a beállításokkal együtt a felhőbe is megy), új telepítésnél `AppStore.defaultLanguage` (angol; a tesztekben a `test/flutter_test_config.dart` magyarra állítja).
- **A forrásnyelv a magyar**: a kódban a magyar szöveg áll, az angolt a magyar szöveg alapján keresi a `lib/l10n/en_strings.dart` (`enStrings`). Ha nincs fordítás, a magyar szöveg látszik (és angol módban az `L10n.missing`-be kerül). Új szöveg: írd magyarul, és vedd fel az angolt az `en_strings.dart`-ba, **pontosan ugyanazzal a szöveggel kulcsként**.
- Használat: `Text('Mégse')` (a `lib/l10n/text.dart` saját `Text`-je fordít kirajzoláskor; fájlban `import 'package:flutter/material.dart' hide Text;` + `import '…/l10n/text.dart';`), `tr('Mégse')` ott, ahol nem `Text` fogyasztja (tooltip, labelText, hintText, értesítés, `label:` stb.), `trf('{0} elmaradt teendő', [n])` behelyettesítéshez (angolban a `{0?task:tasks}` egyes/többes szám). A behelyettesített ismert szöveg is fordul (pl. `trf('Az állapotod: {0}', [status.label])`).
- A konstansokban, felsorolásokban (enum címkék, tippek, sablonok) a magyar szöveg marad, a `Text` fordítja; ha `tr`-t kell használni, az nem lehet `const` (alapértelmezett paraméterértékben sem). Dátumformátum: `DateFormat(tr('MMMM d.'), L10n.code)` (a minta is fordítandó), hétköznapok: `weekdayLetters()`.
- Nyelvváltáskor az `_applyLook` (main.dart) a teljes fát újraépíti, így a `const` szövegek is átváltanak.
- Ellenőrzés: `test/l10n_qa_test.dart` (angol módban végigjárja a fő képernyőket, lapokat, bejelentkezést, bevezetőt, admint; ékezetes = lefordítatlan szöveget és `L10n.missing`-et jelez; `ELETREND_QA=<fájl>` stb. kiírja az összes látható szöveget átnézéshez) és `test/l10n_test.dart` (a táblázatok teljes fordítása, nyelvváltás). **Ékezet nélküli** magyar szöveget (pl. „Szabad”, „Hetente”) a teszt nem tud felismerni: ilyenkor a kiírt szövegeket kell átnézni.

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
- Bemutató: a kiemelés `RectTween`-nel csúszik, egyetlen kártya követi (`_CardPlacer`, a fölé/alá váltás is folyamatos), mérete `AnimatedSize`-zal igazodik, a tartalma egymás után halványul át (előbb ki a régi, aztán be az új); az egész be/ki halványul. Tesztben a lépések között több képkocka kell (`pump(300ms)` ×4).
- Tipp bezárása: kicsúszik + `SizeTransition` összecsukás, csak utána `closeTip`. Fülváltás: az új fül `FadeSlideIn` (a régi nem marad meg, mert a Főoldalon GlobalKey-ek vannak). Naptár: lapozáskor irány szerinti csúszás (`_dir`, `_periodKey`). Oldalak: `FadeForwardsPageTransitionsBuilder` (theme.dart).

## Egyszerű választók, elmaradt teendők

- `lib/widgets/pickers.dart`: `pickTime` (óra : perc kerekek), `pickDay`, `pickBirthday` (év-hónap-nap kerekek, beírni nem kell): az Android-os órás tárcsa és a kézzel beírandó dátum helyett. Új időválasztásnál ezeket használd, ne `showTimePicker`-t.
- Elmaradt teendő: `TaskItem.isMissed` (nem kész, a napja — beosztás vagy határidő — elmúlt), `store.missedTasks()`, `store.moveTask`. A Főoldalon a Teendők fölött `MissedTasksBanner` (`screens/missed_tasks.dart`): „Van N elmaradt teendőd — Szeretnéd folytatni?” Igen → lap, egyenként Ma / Holnap / Másik nap, kész, törlés; Nem → törlés megerősítés után.
- Bökés megnyitása: `openNudge` védett az ismételt koppintás ellen (`_nudgeOpen`), különben ugyanaz az oldal többször nyílna.

## Olvasatlan-számlálók

- `CountBadge` (widgets/common.dart). Főoldal fül: `store.unseenInvites()` (meg nem nyitott, jövőbeli, naptárban még nem lévő meghívás; `seenInvites`, megnyitáskor `markInviteSeen`). Barátok fül: függő jelölések + `Nudges.watchUnseenCount()`.
- Bökés: csak a lista megnyitása (`markAllSeen`) vagy a „Megnyitom” jelöli olvasottnak; felugró sáv/értesítés csak az indítás után érkezőkről jön (a régi olvasatlanokat a szám mutatja).
- Admin: `Admin.watchOpenCount()` (nyitott visszajelzés + jelentés) a Profil admin menüpontján.
