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
- `lib/models.dart`: Event, Habit, JournalEntry
- `lib/theme.dart`: színek és téma; `lib/widgets/`: közös elemek, telefonkeret, térkép
- Térkép: OpenStreetMap (`flutter_map`), címkeresés: Nominatim (`lib/geocoding.dart`)

## Ütemterv

1. Emlékeztető értesítések
2. Kipróbálás a felhasználó telefonján
3. Firebase: bejelentkezés, valódi barátok és meghívók
4. Ikon, sötét mód, Google Play

## �rtes�t�sek

- `lib/notifications.dart`: helyi, �temezett �rtes�t�sek (flutter_local_notifications), csak Androidon. Minden store-v�ltoz�skor mindent �jra�temez (napi 7 nap el�re, programonk�nt el�z� este 18:00 + 1 �r�val el�tte).
- Emul�tor: `Medium_Phone_API_37.0`; ind�t�s: `C:\Android\sdk\emulator\emulator.exe -avd Medium_Phone_API_37.0` (a `flutter emulators --launch` csendben nem ind�tja el).
