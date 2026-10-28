# Életrend

Magyar nyelvű életmód app Flutterben (elsősorban Android): programszervezés barátokkal, szokáskövető, hangulat- és hálanapló. A felhasználó kezdő, vele magyarul beszélünk.

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

## Ütemterv

1. ~~Emlékeztető értesítések~~ (kész)
2. Kipróbálás a felhasználó telefonján
3. Firebase: bejelentkezés, valódi barátok és meghívók
4. ~~Ikon, sötét mód~~ (kész), Google Play

## Napló zárolása

- `lib/screens/pin_screen.dart`: PIN (sózott SHA-256, nincs a mentésben) + ujjlenyomat (`local_auth`, csak Androidon). Ehhez a `MainActivity` `FlutterFragmentActivity`, a `LaunchTheme` szülője `Theme.AppCompat…`.
- **Figyelem:** a `dart run flutter_native_splash:create` felülírja a `styles.xml`-eket, utána az AppCompat szülőt vissza kell írni.

## Kezdőképernyő-widget

- `lib/habits_widget.dart` (adatok + koppintás a háttérben) és `android/.../HabitsWidgetProvider.kt` + `res/layout/habits_widget.xml`. Max 5 szokás; a `day` kulcs alapján éjfél után üresnek mutatja. Az app visszatéréskor `store.reload()`-dal beolvassa a widgeten tett változást.

## Értesítések

- `lib/notifications.dart`: helyi, ütemezett értesítések (flutter_local_notifications), csak Androidon. Minden store-változáskor mindent újraütemez (napi 7 nap előre, programonként előző este 18:00 + 1 órával előtte).
- Emulátor: `Medium_Phone_API_37.0`; indítás: `C:\Android\sdk\emulator\emulator.exe -avd Medium_Phone_API_37.0` (a `flutter emulators --launch` csendben nem indítja el).
