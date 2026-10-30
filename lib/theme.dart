import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Az app színei és stílusa egy helyen.
///
/// „Papírnapló” paletta: meleg krém alap, mély burgundi márkaszín, zsálya kiemelés;
/// színátmenetek és pasztell felületek helyett vékony keretek és tiszta tipográfia.
class AppColors {
  /// Sötét módban vagyunk-e. A `MaterialApp.builder` állítja a téma alapján,
  /// így az alábbi getterek mindig az aktuális módhoz illő színt adják.
  static bool dark = false;

  /// Márkaszín: világosban mély burgundi, sötétben meleg krém, hogy kiolvasható legyen.
  static Color get primary => primaryFor(dark);
  static Color primaryFor(bool dark) => dark ? const Color(0xFFE8D2B5) : const Color(0xFF590907);

  /// Szöveg/ikon a márkaszínű felületen.
  static Color get onPrimary => onPrimaryFor(dark);
  static Color onPrimaryFor(bool dark) => dark ? const Color(0xFF3A0605) : const Color(0xFFFBF6EE);

  /// Kiemelés (sorozat, legjobb, hely): zsálya; világosban mélyebb árnyalat, hogy olvasható legyen.
  static Color get accent => dark ? const Color(0xFFA5A79B) : const Color(0xFF6B6E5D);

  static Color get background => backgroundFor(dark);
  static Color get card => cardFor(dark);
  static Color get text => dark ? const Color(0xFFF4E9DA) : const Color(0xFF2B1714);
  static Color get textMuted => dark ? const Color(0xFFB5A595) : const Color(0xFF7A6A5E);

  /// Vékony vonalak, keretek, üres karikák szegélye.
  static Color get divider => borderFor(dark);

  static Color backgroundFor(bool dark) => dark ? const Color(0xFF1C1412) : const Color(0xFFF4E9DA);
  static Color cardFor(bool dark) => dark ? const Color(0xFF2A1F1C) : const Color(0xFFFBF6EE);
  static Color borderFor(bool dark) => dark ? const Color(0xFF3D2E29) : const Color(0xFFE8D7C1);

  /// Kiemelt felületek (fejléc, dátum, kész pipa): egyszínű márkaszín, enyhe mélységgel.
  static LinearGradient get headerGradient => LinearGradient(
        colors: dark ? const [Color(0xFF7A1512), Color(0xFF5E0C09)] : const [Color(0xFF590907), Color(0xFF470705)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  /// Hangulatonkénti szín (1–5).
  static const moods = [
    Color(0xFFA8433A),
    Color(0xFFC97B4A),
    Color(0xFFD4A95A),
    Color(0xFF9AA477),
    Color(0xFF6B8A5E),
  ];
}

/// Az app témája világos vagy sötét módban.
ThemeData buildTheme({bool dark = false}) {
  final background = AppColors.backgroundFor(dark);
  final card = AppColors.cardFor(dark);
  final border = AppColors.borderFor(dark);
  final primary = AppColors.primaryFor(dark);
  final textColor = dark ? const Color(0xFFF4E9DA) : const Color(0xFF2B1714);
  final muted = dark ? const Color(0xFFB5A595) : const Color(0xFF7A6A5E);
  final font = GoogleFonts.inter().fontFamily;

  final scheme = ColorScheme.fromSeed(
    seedColor: primary,
    brightness: dark ? Brightness.dark : Brightness.light,
    primary: primary,
    onPrimary: AppColors.onPrimaryFor(dark),
    secondary: const Color(0xFFA5A79B),
    onSecondary: const Color(0xFF2B2D24),
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
      titleTextStyle: TextStyle(fontFamily: font, fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.6, color: textColor),
    ),
    cardTheme: CardThemeData(
      color: card,
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 5),
      shape: RoundedRectangleBorder(borderRadius: radius, side: BorderSide(color: border)),
    ),
    listTileTheme: ListTileThemeData(iconColor: muted, titleTextStyle: text.bodyLarge?.copyWith(fontWeight: FontWeight.w500)),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: card,
      hintStyle: TextStyle(color: muted),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primary, width: 1.5)),
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
      style: TextButton.styleFrom(textStyle: TextStyle(fontFamily: font, fontWeight: FontWeight.w600)),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: primary,
      foregroundColor: AppColors.onPrimaryFor(dark),
      elevation: 2,
      highlightElevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: card,
      surfaceTintColor: Colors.transparent,
      indicatorColor: primary.withValues(alpha: dark ? 0.22 : 0.10),
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
      selectedColor: primary.withValues(alpha: dark ? 0.25 : 0.12),
      labelStyle: TextStyle(fontFamily: font, fontWeight: FontWeight.w500, color: textColor),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        side: BorderSide(color: border),
        selectedBackgroundColor: primary.withValues(alpha: dark ? 0.25 : 0.12),
        selectedForegroundColor: textColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.onPrimaryFor(dark) : null),
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
      backgroundColor: dark ? const Color(0xFFF4E9DA) : const Color(0xFF2B1714),
      contentTextStyle: TextStyle(fontFamily: font, color: dark ? const Color(0xFF2B1714) : const Color(0xFFFBF6EE)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}
