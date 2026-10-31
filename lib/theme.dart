import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'availability.dart';
import 'models.dart';

/// Az app színei és stílusa egy helyen.
///
/// Három megjelenés:
/// - **Bézs** (alap): „papírnapló” paletta, meleg krém alap, mély burgundi márkaszín, zsálya kiemelés;
/// - **Fehér**: a megszokott világos app, fehér kártyák, semleges szürkék, fekete kiemelés;
/// - **Sötét**: a megszokott sötét mód, semleges grafitszürkék, fehér kiemelés.
/// A kategóriák és az állapotok színei mindegyikben ugyanazok (sötétben világosabb árnyalattal).
class AppColors {
  /// Sötét módban vagyunk-e. A `MaterialApp.builder` állítja a téma alapján,
  /// így az alábbi getterek mindig az aktuális módhoz illő színt adják.
  static bool dark = false;

  /// Fehér világos mód a bézs helyett. Sötét módban nincs hatása.
  static bool white = false;

  /// Márkaszín: bézsben mély burgundi, fehérben majdnem fekete, sötétben majdnem fehér.
  static Color get primary => primaryFor(dark, white: white);
  static Color primaryFor(bool dark, {bool white = false}) =>
      dark ? const Color(0xFFF4F4F5) : (white ? const Color(0xFF18181B) : const Color(0xFF590907));

  /// Szöveg/ikon a márkaszínű felületen.
  static Color get onPrimary => onPrimaryFor(dark, white: white);
  static Color onPrimaryFor(bool dark, {bool white = false}) =>
      dark ? const Color(0xFF18181B) : (white ? const Color(0xFFFFFFFF) : const Color(0xFFFBF6EE));

  /// Kiemelés (sorozat, legjobb, hely): bézsben zsálya, a másik kettőben semleges szürke.
  static Color get accent =>
      dark ? const Color(0xFFA1A1AA) : (white ? const Color(0xFF52525B) : const Color(0xFF6B6E5D));

  static Color get background => backgroundFor(dark, white: white);
  static Color get card => cardFor(dark, white: white);
  static Color get text => textFor(dark, white: white);
  static Color get textMuted => mutedFor(dark, white: white);

  /// Vékony vonalak, keretek, üres karikák szegélye.
  static Color get divider => borderFor(dark, white: white);

  static Color backgroundFor(bool dark, {bool white = false}) =>
      dark ? const Color(0xFF111113) : (white ? const Color(0xFFF4F4F5) : const Color(0xFFF4E9DA));
  static Color cardFor(bool dark, {bool white = false}) =>
      dark ? const Color(0xFF1C1C1F) : (white ? const Color(0xFFFFFFFF) : const Color(0xFFFBF6EE));
  static Color borderFor(bool dark, {bool white = false}) =>
      dark ? const Color(0xFF2E2E33) : (white ? const Color(0xFFE4E4E7) : const Color(0xFFE8D7C1));
  static Color textFor(bool dark, {bool white = false}) =>
      dark ? const Color(0xFFF4F4F5) : (white ? const Color(0xFF18181B) : const Color(0xFF2B1714));
  static Color mutedFor(bool dark, {bool white = false}) =>
      dark ? const Color(0xFFA1A1AA) : (white ? const Color(0xFF71717A) : const Color(0xFF7A6A5E));

  /// Kiemelt felületek (fejléc, dátum, kész pipa): egyszínű, enyhe mélységgel; rajta fehér a szöveg.
  static LinearGradient get headerGradient => LinearGradient(
    colors: dark
        ? const [Color(0xFF3F3F46), Color(0xFF2A2A2F)]
        : (white ? const [Color(0xFF27272A), Color(0xFF18181B)] : const [Color(0xFF590907), Color(0xFF470705)]),
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

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

/// Az app témája: sötét, vagy világos bézs ([white] = false) / fehér ([white] = true) alappal.
ThemeData buildTheme({bool dark = false, bool white = false}) {
  final background = AppColors.backgroundFor(dark, white: white);
  final card = AppColors.cardFor(dark, white: white);
  final border = AppColors.borderFor(dark, white: white);
  final primary = AppColors.primaryFor(dark, white: white);
  final onPrimary = AppColors.onPrimaryFor(dark, white: white);
  final textColor = AppColors.textFor(dark, white: white);
  final muted = AppColors.mutedFor(dark, white: white);
  final font = GoogleFonts.inter().fontFamily;

  final scheme = ColorScheme.fromSeed(
    seedColor: primary,
    brightness: dark ? Brightness.dark : Brightness.light,
    primary: primary,
    onPrimary: onPrimary,
    secondary: dark || white ? muted : const Color(0xFFA5A79B),
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
      contentTextStyle: TextStyle(fontFamily: font, color: dark ? const Color(0xFF18181B) : card),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}
