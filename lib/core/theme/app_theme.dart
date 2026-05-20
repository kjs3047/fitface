import 'package:flutter/material.dart';

class AppTheme {
  static const paper = Color(0xFFF4F0E8);
  static const surface = Color(0xFFFFFCF7);
  static const ink = Color(0xFF171412);
  static const mutedInk = Color(0xFF756D66);
  static const line = Color(0xFFE2D9CE);
  static const accent = Color(0xFF9E5F53);
  static const accentSoft = Color(0xFFF0DDD7);
  static const bronze = Color(0xFFB47A4B);
  static const bronzeSoft = Color(0xFFF2E0CE);
  static const cameraBlack = Color(0xFF0F0E0C);
  static const imagePlaceholder = Color(0xFFECE6DD);

  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        primary: ink,
        onPrimary: Colors.white,
        secondary: accent,
        onSecondary: Colors.white,
        tertiary: accentSoft,
        onTertiary: ink,
        surface: surface,
        onSurface: ink,
        error: Color(0xFFB3261E),
      ),
      scaffoldBackgroundColor: paper,
      fontFamily: 'Roboto',
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 48,
          height: 0.98,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
          color: ink,
        ),
        displayMedium: TextStyle(
          fontSize: 38,
          height: 1.02,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
          color: ink,
        ),
        displaySmall: TextStyle(
          fontSize: 32,
          height: 1.04,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
          color: ink,
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          height: 1.16,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
          color: ink,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          height: 1.2,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
          color: ink,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          height: 1.32,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
          color: ink,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          height: 1.45,
          fontWeight: FontWeight.w400,
          letterSpacing: 0,
          color: ink,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          height: 1.42,
          fontWeight: FontWeight.w400,
          letterSpacing: 0,
          color: mutedInk,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          height: 1.2,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
          color: ink,
        ),
        labelMedium: TextStyle(
          fontSize: 12,
          height: 1.2,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
          color: mutedInk,
        ),
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: paper,
        foregroundColor: ink,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: ink,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surface,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: line),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ink,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFC7BDB4),
          disabledForegroundColor: Colors.white70,
          minimumSize: const Size.fromHeight(54),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          foregroundColor: ink,
          side: const BorderSide(color: line),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: ink,
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        labelStyle: const TextStyle(color: mutedInk),
        hintStyle: const TextStyle(color: mutedInk),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: ink, width: 1.4),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      dividerTheme: const DividerThemeData(color: line, thickness: 1),
      sliderTheme: SliderThemeData(
        activeTrackColor: ink,
        inactiveTrackColor: line,
        thumbColor: ink,
        overlayColor: ink.withValues(alpha: 0.10),
        trackHeight: 3,
      ),
    );
  }
}
