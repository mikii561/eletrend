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

## Ütemterv

1. ~~Emlékeztető értesítések~~ (kész)
2. Kipróbálás a felhasználó telefonján
3. Firebase: bejelentkezés, valódi barátok és meghívók
4. Ikon, sötét mód, Google Play

## Értesítések

- `lib/notifications.dart`: helyi, ütemezett értesítések (flutter_local_notifications), csak Androidon. Minden store-változáskor mindent újraütemez (napi 7 nap előre, programonként előző este 18:00 + 1 órával előtte).
- Emulátor: `Medium_Phone_API_37.0`; indítás: `C:\Android\sdk\emulator\emulator.exe -avd Medium_Phone_API_37.0` (a `flutter emulators --launch` csendben nem indítja el).
