import 'package:flutter/material.dart';

import 'models/dhikr.dart';

/// Manuscript-inspired palette: deep prayer-night green surfaces,
/// muted gold (gilding) as the primary accent, sage for protection.
ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;

  final scheme = dark
      ? const ColorScheme.dark(
          surface: Color(0xFF0F1713),
          onSurface: Color(0xFFEDEAE2),
          onSurfaceVariant: Color(0xFFB4BDB3),
          surfaceContainerHighest: Color(0xFF202D25),
          primary: Color(0xFFD3B577),
          onPrimary: Color(0xFF241C0B),
          primaryContainer: Color(0xFF1E3329),
          onPrimaryContainer: Color(0xFFD3B577),
          secondary: Color(0xFF8FBFA6),
          onSecondary: Color(0xFF0F1713),
          tertiary: Color(0xFFC9A961),
          outline: Color(0xFF5F6A60),
          outlineVariant: Color(0xFF2A362F),
        )
      : const ColorScheme.light(
          surface: Color(0xFFF6F2E8),
          onSurface: Color(0xFF232D24),
          onSurfaceVariant: Color(0xFF5A635A),
          surfaceContainerHighest: Color(0xFFE7E1D2),
          primary: Color(0xFF2F5D48),
          onPrimary: Color(0xFFF6F2E8),
          primaryContainer: Color(0xFFDCE8DF),
          onPrimaryContainer: Color(0xFF2F5D48),
          secondary: Color(0xFF9A7B2E),
          onSecondary: Color(0xFFF6F2E8),
          tertiary: Color(0xFF9A7B2E),
          outline: Color(0xFF8A8E82),
          outlineVariant: Color(0xFFD8D2C2),
        );

  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontFamily: 'Amiri',
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: scheme.onSurface,
      ),
    ),
    cardTheme: CardThemeData(
      color: dark ? const Color(0xFF18231D) : const Color(0xFFFCFAF3),
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant),
    listTileTheme: ListTileThemeData(iconColor: scheme.onSurfaceVariant),
  );
}

/// Accent color for each benefit tier — used by the section bands and
/// the per-card tier dot.
Color tierColor(BuildContext context, BenefitTier tier) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return switch (tier) {
    BenefitTier.protection =>
      dark ? const Color(0xFF8FBFA6) : const Color(0xFF2F5D48),
    BenefitTier.reward =>
      dark ? const Color(0xFFD3B577) : const Color(0xFF9A7B2E),
    BenefitTier.none =>
      dark ? const Color(0xFF9AA69B) : const Color(0xFF6E7568),
  };
}

/// Accent for the high-repetitions section band — a calm teal that reads as
/// distinct from the green/gold tier colours.
Color highRepColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF86B8C0)
        : const Color(0xFF3D6B77);
