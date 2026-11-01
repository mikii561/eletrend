import 'en.dart';

/// Az app nyelve. A magyar a „forrásnyelv”: a kódban a magyar szöveg áll, és az angol fordítást
/// a magyar szöveg alapján keressük ([enStrings]). Így a magyar kiírás mindig megvan, és új szöveg
/// felvételekor nem kell kulcsot kitalálni; ha nincs fordítás, a magyar szöveg látszik.
enum AppLanguage {
  en('en', 'English', '🇬🇧'),
  hu('hu', 'Magyar', '🇭🇺');

  const AppLanguage(this.code, this.label, this.flag);

  final String code;
  final String label;
  final String flag;
}

class L10n {
  /// A mostani nyelv. Az app a store beállítása szerint állítja (lásd `LifeupApp`).
  static AppLanguage lang = AppLanguage.en;

  /// A dátumformátumok nyelvi kódja (`DateFormat(…, L10n.code)`).
  static String get code => lang.code;

  static bool get isHungarian => lang == AppLanguage.hu;

  /// Fejlesztéshez: a lefordítatlan magyar szövegek (angol módban), a QA-teszt ezt nézi.
  static final missing = <String>{};

  /// Fordítás: magyarul az eredeti, angolul a [enStrings]-beli megfelelője.
  static String tr(String hu) {
    if (lang == AppLanguage.hu) return hu;
    final en = enStrings[hu];
    if (en != null) return en;
    if (_looksHungarian(hu)) missing.add(hu);
    return hu;
  }

  /// Sablonos szöveg: a `{0}`, `{1}`… helyére kerülnek az [args]; a `{0?egy:több}` az első
  /// (0. számú) érték alapján választ egyes és többes számot (angolhoz).
  static String trf(String hu, List<Object?> args) {
    final template = tr(hu);
    return template.replaceAllMapped(RegExp(r'\{(\d+)(?:\?([^:}]*):([^}]*))?\}'), (m) {
      final i = int.parse(m[1]!);
      final value = i < args.length ? args[i] : null;
      if (m[2] != null) {
        final n = value is num ? value : num.tryParse('$value');
        return n == 1 ? m[2]! : m[3]!;
      }
      return '$value';
    });
  }

  static final _hungarianChars = RegExp('[áéíóöőúüűÁÉÍÓÖŐÚÜŰ]');

  /// Magyar szövegnek látszik-e (csak a hiányzó fordítások jelzéséhez).
  static bool _looksHungarian(String s) => _hungarianChars.hasMatch(s);
}

/// Rövid név: `tr('Mégse')`.
String tr(String hu) => L10n.tr(hu);

/// Sablonos szöveg: `trf('{0} elmaradt teendő', [n])`.
String trf(String hu, List<Object?> args) => L10n.trf(hu, args);
