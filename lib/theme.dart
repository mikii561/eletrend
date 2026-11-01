import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'availability.dart';
import 'models.dart';

/// A világos megjelenések (a sötét külön van): mindegyik egy teljes színkészlet.
enum LightPalette {
  /// Alap: „papírnapló”, meleg krém alap, mély burgundi márkaszín, zsálya kiemelés.
  beige('Bézs', 'Krém és burgundi, a LIFEUP saját színei'),

  /// A megszokott világos app: fehér kártyák, semleges szürkék, fekete kiemelés.
  white('Fehér', 'Letisztult fehér, mint a legtöbb app'),

  /// Égetett narancs márkaszín, meleg elefántcsont alap, puha fekete szöveg.
  ember('Narancs', 'Égetett narancs, elefántcsont és puha fekete'),

  /// Élénk kobaltkék márkaszín, mandarin-narancs kiemelés, krém alap.
  cobalt('Kobalt', 'Kobaltkék, mandarin és krém'),

  /// Texturált fekete alap, törtfehér szöveg, elektromos magenta kiemelés. Sötét kinézetű, de a világos
  /// választók között van: saját színkészlete van, a sima sötét módtól független.
  magenta('Magenta', 'Mély fekete, törtfehér és elektromos magenta', isDark: true);

  const LightPalette(this.label, this.description, {this.isDark = false});

  final String label;
  final String description;

  /// Sötét alapú-e (a színek és az alapértelmezett stílusok ehhez igazodnak).
  final bool isDark;
}

/// Egy megjelenés színei.
class _Scheme {
  const _Scheme({
    required this.background,
    required this.card,
    required this.border,
    required this.text,
    required this.muted,
    required this.primary,
    required this.onPrimary,
    required this.accent,
    required this.header,
    Color? highlight,
  }) : _highlight = highlight; // ignore: prefer_initializing_formals (a név nem kezdődhet aláhúzással)

  final Color background;
  final Color card;
  final Color border;
  final Color text;
  final Color muted;
  final Color primary;
  final Color onPrimary;
  final Color accent;
  final List<Color> header;
  final Color? _highlight;

  /// Élénk kiegészítő szín (a kobaltnál a mandarin); ahol nincs, a márkaszín.
  Color get highlight => _highlight ?? primary;
}

const _dark = _Scheme(
  background: Color(0xFF111113),
  card: Color(0xFF1C1C1F),
  border: Color(0xFF2E2E33),
  text: Color(0xFFF4F4F5),
  muted: Color(0xFFA1A1AA),
  primary: Color(0xFFF4F4F5),
  onPrimary: Color(0xFF18181B),
  accent: Color(0xFFA1A1AA),
  header: [Color(0xFF3F3F46), Color(0xFF2A2A2F)],
);

const _schemes = {
  LightPalette.beige: _Scheme(
    background: Color(0xFFF4E9DA),
    card: Color(0xFFFBF6EE),
    border: Color(0xFFE8D7C1),
    text: Color(0xFF2B1714),
    muted: Color(0xFF7A6A5E),
    primary: Color(0xFF590907),
    onPrimary: Color(0xFFFBF6EE),
    accent: Color(0xFF6B6E5D),
    header: [Color(0xFF590907), Color(0xFF470705)],
  ),
  LightPalette.white: _Scheme(
    background: Color(0xFFF4F4F5),
    card: Color(0xFFFFFFFF),
    border: Color(0xFFE4E4E7),
    text: Color(0xFF18181B),
    muted: Color(0xFF71717A),
    primary: Color(0xFF18181B),
    onPrimary: Color(0xFFFFFFFF),
    accent: Color(0xFF52525B),
    header: [Color(0xFF27272A), Color(0xFF18181B)],
  ),
  // Égetett narancs #D5360C, elefántcsont #E6D5BD (az alap), puha fekete #101010 (a szöveg).
  LightPalette.ember: _Scheme(
    background: Color(0xFFE6D5BD),
    card: Color(0xFFF2E8D6),
    border: Color(0xFFD2BE9E),
    text: Color(0xFF101010),
    muted: Color(0xFF5C5143),
    primary: Color(0xFFD5360C),
    onPrimary: Color(0xFFFFF8EC),
    accent: Color(0xFF7A4B2E),
    header: [Color(0xFFD5360C), Color(0xFFB02C09)],
  ),
  // Kobalt #0736BB, mandarin #FF7900 (kiemelés), krém #F5E6C8 (az alap).
  LightPalette.cobalt: _Scheme(
    background: Color(0xFFF5E6C8),
    card: Color(0xFFFCF5E3),
    border: Color(0xFFE3D2AC),
    text: Color(0xFF0B1B4D),
    muted: Color(0xFF4F5A80),
    primary: Color(0xFF0736BB),
    onPrimary: Color(0xFFFFF8EA),
    accent: Color(0xFFD96500),
    header: [Color(0xFF0736BB), Color(0xFF052A94)],
    highlight: Color(0xFFFF7900),
  ),
  // Fekete #0A0A0A (az alap), törtfehér #F2F0ED (a fő szöveg és a címek), elektromos magenta #F20B8B (a kiemelés).
  LightPalette.magenta: _Scheme(
    background: Color(0xFF0A0A0A),
    card: Color(0xFF161616),
    border: Color(0xFF2B2B2B),
    text: Color(0xFFF2F0ED),
    muted: Color(0xFFA7A39D),
    primary: Color(0xFFF20B8B),
    onPrimary: Color(0xFFFFFFFF),
    accent: Color(0xFFC9C5BF),
    header: [Color(0xFFF20B8B), Color(0xFFC20870)],
  ),
};

/// Az app színei és stílusa egy helyen.
///
/// Megjelenések: sötét (a megszokott, semleges), és négy világos: [LightPalette].
/// A kategóriák és az állapotok színei mindegyikben ugyanazok (sötétben világosabb árnyalattal).
class AppColors {
  /// Sötét módban vagyunk-e. A `MaterialApp.builder` állítja a téma alapján,
  /// így az alábbi getterek mindig az aktuális módhoz illő színt adják.
  static bool dark = false;

  /// A sima sötét mód aktív-e (a „Magenta” sötét kinézetű, de nem ez).
  static bool plainDark = false;

  /// Melyik világos megjelenés. Sötét módban nincs hatása.
  static LightPalette palette = LightPalette.beige;

  static _Scheme _of(bool dark, LightPalette palette) => dark ? _dark : _schemes[palette]!;

  static _Scheme get _now => plainDark ? _dark : _schemes[palette]!;

  /// Márkaszín (gombok, kiemelések).
  static Color get primary => _now.primary;
  static Color primaryFor(bool dark, {LightPalette palette = LightPalette.beige}) => _of(dark, palette).primary;

  /// Szöveg/ikon a márkaszínű felületen.
  static Color get onPrimary => _now.onPrimary;
  static Color onPrimaryFor(bool dark, {LightPalette palette = LightPalette.beige}) => _of(dark, palette).onPrimary;

  /// Kiemelés (sorozat, legjobb, hely).
  static Color get accent => _now.accent;

  /// Élénk kiegészítő szín (a kobalt megjelenésben a mandarin); máshol a márkaszín.
  static Color get highlight => _now.highlight;

  static Color get background => _now.background;
  static Color get card => _now.card;
  static Color get text => _now.text;
  static Color get textMuted => _now.muted;

  /// Vékony vonalak, keretek, üres karikák szegélye.
  static Color get divider => _now.border;

  static Color backgroundFor(bool dark, {LightPalette palette = LightPalette.beige}) => _of(dark, palette).background;
  static Color cardFor(bool dark, {LightPalette palette = LightPalette.beige}) => _of(dark, palette).card;
  static Color borderFor(bool dark, {LightPalette palette = LightPalette.beige}) => _of(dark, palette).border;
  static Color textFor(bool dark, {LightPalette palette = LightPalette.beige}) => _of(dark, palette).text;
  static Color mutedFor(bool dark, {LightPalette palette = LightPalette.beige}) => _of(dark, palette).muted;
  static Color highlightFor(bool dark, {LightPalette palette = LightPalette.beige}) => _of(dark, palette).highlight;
  static Color accentFor(bool dark, {LightPalette palette = LightPalette.beige}) => _of(dark, palette).accent;

  /// Kiemelt felületek (fejléc, dátum, kész pipa): egyszínű, enyhe mélységgel; rajta fehér a szöveg.
  static LinearGradient get headerGradient =>
      LinearGradient(colors: _now.header, begin: Alignment.topLeft, end: Alignment.bottomRight);

  /// Szín egy kategóriához; sötét módban világosabb árnyalat, hogy kiolvasható legyen.
  static Color category(EventCategory c) => switch (c) {
    EventCategory.personal => dark ? const Color(0xFFA3B08E) : const Color(0xFF5F6E4E),
    EventCategory.work => dark ? const Color(0xFF9AA7BD) : const Color(0xFF4F5D73),
    EventCategory.study => dark ? const Color(0xFFD9AE63) : const Color(0xFF94661E),
    EventCategory.social => dark ? const Color(0xFFE08A7E) : const Color(0xFF8C1C17),
    EventCategory.health => dark ? const Color(0xFF86B595) : const Color(0xFF3F6B4F),
    EventCategory.important => dark ? const Color(0xFFE8946B) : const Color(0xFFB4532A),
    EventCategory.shared => dark ? const Color(0xFFC495B5) : const Color(0xFF6E3B5E),
  };

  /// Egy bejegyzés színe: a saját, ha van, különben a kategóriáé.
  static Color ofEvent(Event e) => e.color != null ? Color(e.color!) : category(e.category);

  /// Saját színek a szerkesztőben (a paletta árnyalatai).
  static const customColors = [0xFF590907, 0xFF8C5A3C, 0xFFA0672A, 0xFF6B6E5D, 0xFF3F5E5A, 0xFF4F5D73, 0xFF7A4E6E];

  /// Az elérhetőségi állapot jelzőszíne.
  static Color status(AvailabilityStatus s) => switch (s) {
    AvailabilityStatus.available => dark ? const Color(0xFF86B595) : const Color(0xFF3F7A52),
    AvailabilityStatus.open => dark ? const Color(0xFFD9AE63) : const Color(0xFFA0672A),
    AvailabilityStatus.busy => dark ? const Color(0xFFE08A7E) : const Color(0xFF8C1C17),
    AvailabilityStatus.dnd => dark ? const Color(0xFFB5A595) : const Color(0xFF7A6A5E),
  };

  /// Hibaszín (törlés, hibaüzenet).
  static Color get danger => dark ? const Color(0xFFF09080) : const Color(0xFFB3261E);
}

/// Ikon egy kategóriához.
IconData categoryIcon(EventCategory c) => switch (c) {
  EventCategory.personal => Icons.person_outline,
  EventCategory.work => Icons.work_outline,
  EventCategory.study => Icons.school_outlined,
  EventCategory.social => Icons.celebration_outlined,
  EventCategory.health => Icons.fitness_center,
  EventCategory.important => Icons.priority_high_rounded,
  EventCategory.shared => Icons.groups_outlined,
};

/// Ikon egy elérhetőségi állapothoz.
IconData statusIcon(AvailabilityStatus s) => switch (s) {
  AvailabilityStatus.available => Icons.check_circle_outline,
  AvailabilityStatus.open => Icons.waving_hand_outlined,
  AvailabilityStatus.busy => Icons.schedule,
  AvailabilityStatus.dnd => Icons.do_not_disturb_on_outlined,
};

/// Térközök és lekerekítések egy helyen (8-as alap).
class Space {
  static const xs = 4.0;
  static const s = 8.0;
  static const m = 12.0;
  static const l = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;

  static const radius = 14.0;
  static const radiusSmall = 10.0;
}

/// Az app témája: sötét, vagy a választott világos [palette].
ThemeData buildTheme({bool dark = false, LightPalette palette = LightPalette.beige}) {
  // A sötét alapú paletta (magenta) sötét kinézetű, akkor is, ha a világos témák között van.
  final useDark = dark || palette.isDark;
  final background = AppColors.backgroundFor(dark, palette: palette);
  final card = AppColors.cardFor(dark, palette: palette);
  final border = AppColors.borderFor(dark, palette: palette);
  final primary = AppColors.primaryFor(dark, palette: palette);
  final onPrimary = AppColors.onPrimaryFor(dark, palette: palette);
  final textColor = AppColors.textFor(dark, palette: palette);
  final muted = AppColors.mutedFor(dark, palette: palette);
  final font = GoogleFonts.inter().fontFamily;

  final scheme = ColorScheme.fromSeed(
    seedColor: primary,
    brightness: useDark ? Brightness.dark : Brightness.light,
    primary: primary,
    onPrimary: onPrimary,
    secondary: AppColors.highlightFor(dark, palette: palette),
    onSecondary: useDark ? const Color(0xFF18181B) : const Color(0xFF1B1B1B),
    surface: background,
    onSurface: textColor,
    outline: border,
    outlineVariant: border,
  );
  final base = ThemeData(colorScheme: scheme, useMaterial3: true, splashFactory: InkSparkle.splashFactory);
  final text = base.textTheme.apply(fontFamily: font, bodyColor: textColor, displayColor: textColor);
  final radius = BorderRadius.circular(14);

  return base.copyWith(
    scaffoldBackgroundColor: background,
    // Oldalváltás: a Material 3 lágy „előre úszó” átmenete minden platformon egyformán.
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.fuchsia: FadeForwardsPageTransitionsBuilder(),
      },
    ),
    dividerColor: border,
    dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
    textTheme: text.copyWith(
      headlineMedium: text.headlineMedium?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.6),
      headlineSmall: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.4),
      titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w700, fontSize: 19, letterSpacing: -0.3),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.1),
      bodyMedium: text.bodyMedium?.copyWith(height: 1.4),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: background,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      elevation: 0,
      centerTitle: false,
      foregroundColor: textColor,
      titleTextStyle: TextStyle(
        fontFamily: font,
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.6,
        color: textColor,
      ),
    ),
    cardTheme: CardThemeData(
      color: card,
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 5),
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: border),
      ),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: muted,
      titleTextStyle: text.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: card,
      hintStyle: TextStyle(color: muted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: TextStyle(fontFamily: font, fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: textColor,
        side: BorderSide(color: border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: TextStyle(fontFamily: font, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        textStyle: TextStyle(fontFamily: font, fontWeight: FontWeight.w600),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: primary,
      foregroundColor: onPrimary,
      elevation: 2,
      highlightElevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: card,
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppColors.highlightFor(
        dark,
        palette: palette,
      ).withValues(alpha: useDark ? 0.22 : (palette == LightPalette.cobalt ? 0.28 : 0.10)),
      height: 64,
      elevation: 0,
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(color: s.contains(WidgetState.selected) ? primary : muted, size: 24),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontFamily: font,
          fontSize: 12,
          fontWeight: s.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w500,
          color: s.contains(WidgetState.selected) ? textColor : muted,
        ),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      side: BorderSide(color: border),
      backgroundColor: card,
      selectedColor: primary.withValues(alpha: useDark ? 0.25 : 0.12),
      labelStyle: TextStyle(fontFamily: font, fontWeight: FontWeight.w500, color: textColor),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        side: BorderSide(color: border),
        selectedBackgroundColor: primary.withValues(alpha: useDark ? 0.25 : 0.12),
        selectedForegroundColor: textColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? onPrimary : null),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? primary : null),
      trackOutlineColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? primary : border),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: primary, linearTrackColor: border),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: background,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: textColor,
      contentTextStyle: TextStyle(fontFamily: font, color: useDark ? const Color(0xFF18181B) : card),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}
