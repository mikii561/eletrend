import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Az app színei és stílusa egy helyen.
class AppColors {
  /// Sötét módban vagyunk-e. A `MaterialApp.builder` állítja a téma alapján,
  /// így az alábbi getterek mindig az aktuális módhoz illő színt adják.
  static bool dark = false;

  static const primary = Color(0xFF5B5BD6);
  static const accent = Color(0xFFFF8A65);

  static Color get background => backgroundFor(dark);
  static Color get card => cardFor(dark);
  static Color get textMuted => dark ? const Color(0xFFA19FB5) : const Color(0xFF7A7A8C);

  /// Vékony vonalak, üres karikák szegélye.
  static Color get divider => dark ? const Color(0xFF3A3849) : const Color(0xFFE6E4F0);

  static Color backgroundFor(bool dark) => dark ? const Color(0xFF14131B) : const Color(0xFFF5F4FA);
  static Color cardFor(bool dark) => dark ? const Color(0xFF221F2D) : Colors.white;

  static const headerGradient = LinearGradient(
    colors: [Color(0xFF6D5BD6), Color(0xFF9B6BE0), Color(0xFFFF9A8B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Hangulatonkénti szín (1–5).
  static const moods = [
    Color(0xFFE57373),
    Color(0xFFFFB74D),
    Color(0xFFFFD54F),
    Color(0xFF81C784),
    Color(0xFF4DB6AC),
  ];
}

/// Az app témája világos vagy sötét módban.
ThemeData buildTheme({bool dark = false}) {
  final background = AppColors.backgroundFor(dark);
  final card = AppColors.cardFor(dark);
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: dark ? Brightness.dark : Brightness.light,
    primary: dark ? const Color(0xFF9D9BF5) : AppColors.primary,
    surface: background,
  );
  final base = ThemeData(colorScheme: scheme, useMaterial3: true);
  final text = base.textTheme.apply(fontFamily: GoogleFonts.nunito().fontFamily);

  return base.copyWith(
    scaffoldBackgroundColor: background,
    textTheme: text.copyWith(
      headlineMedium: text.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
      titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: GoogleFonts.nunito().fontFamily,
        fontSize: 28,
        fontWeight: FontWeight.w800,
        color: dark ? Colors.white : Colors.black87,
      ),
    ),
    cardTheme: CardThemeData(
      color: card,
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: card,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: card,
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppColors.primary.withValues(alpha: dark ? 0.35 : 0.12),
      height: 68,
      labelTextStyle: WidgetStatePropertyAll(text.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      side: BorderSide.none,
      backgroundColor: card,
    ),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: background, surfaceTintColor: Colors.transparent),
    dialogTheme: DialogThemeData(backgroundColor: card, surfaceTintColor: Colors.transparent),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}
