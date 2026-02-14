import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Utho! design system — dark-first, warm accent, alarm-clock inspired
class UthoTheme {
  static const _seed = Color(0xFFFF6B35); // warm orange
  static const accent = Color(0xFFFF6B35);
  static const accentLight = Color(0xFFFFAB76);
  static const surface = Color(0xFF121212);
  static const surfaceCard = Color(0xFF1E1E2C);
  static const surfaceElevated = Color(0xFF252538);
  static const textPrimary = Color(0xFFF5F5F5);
  static const textSecondary = Color(0xFF9E9EB8);
  static const success = Color(0xFF4CAF50);
  static const danger = Color(0xFFEF5350);

  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: _seed,
        brightness: Brightness.dark,
        surface: surface,
      ),
      scaffoldBackgroundColor: surface,
      textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: textPrimary,
        elevation: 0,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceCard,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: Colors.white,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? accent : textSecondary),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? accent.withAlpha(80)
                : surfaceElevated),
      ),
    );
  }
}
