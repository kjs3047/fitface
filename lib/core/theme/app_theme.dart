import 'package:flutter/material.dart';

class AppTheme {
  // 에디토리얼 블랙: 무채색 베이스 + 잉크 블랙. 색은 사진(옷/얼굴)에서만 나온다.
  static const paper = Color(0xFFFAFAF8); // 화면 배경 (거의 흰색, 미세한 웜)
  static const surface = Color(0xFFFFFFFF); // 카드/입력 표면 (순백)
  static const ink = Color(0xFF101010); // 본문/표제/주 버튼 (잉크 블랙)
  static const mutedInk = Color(0xFF8A8A86); // 보조 텍스트
  static const line = Color(0xFFEAEAE6); // 아주 옅은 구분선
  static const accent = Color(0xFF101010); // 강조 = 블랙 (포인트는 형태/대비로)
  static const accentSoft = Color(0xFFF2F2EF); // 옅은 강조 배경 (뉴트럴)
  static const bronze = Color(0xFF9A7B53); // BEST/포인트 1개만 남기는 메탈릭
  static const bronzeSoft = Color(0xFFF1ECE3);
  static const cameraBlack = Color(0xFF0B0B0B);
  static const imagePlaceholder = Color(0xFFEDEDEA);

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
      // Pretendard: 한글/영문 모두 타이트한 자간의 산세리프로 에디토리얼 인상을 만든다.
      fontFamily: 'Pretendard',
      textTheme: const TextTheme(
        // 표제: 크게, 무게는 낮추고(w600) 자간을 좁혀 잡지 콘텐츠처럼.
        displayLarge: TextStyle(
          fontSize: 46,
          height: 1.0,
          fontWeight: FontWeight.w600,
          letterSpacing: -1.2,
          color: ink,
        ),
        displayMedium: TextStyle(
          fontSize: 36,
          height: 1.04,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.9,
          color: ink,
        ),
        displaySmall: TextStyle(
          fontSize: 28,
          height: 1.08,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.6,
          color: ink,
        ),
        headlineMedium: TextStyle(
          fontSize: 22,
          height: 1.2,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.4,
          color: ink,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          height: 1.24,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
          color: ink,
        ),
        titleMedium: TextStyle(
          fontSize: 15,
          height: 1.34,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.1,
          color: ink,
        ),
        bodyLarge: TextStyle(
          fontSize: 15,
          height: 1.5,
          fontWeight: FontWeight.w400,
          letterSpacing: -0.1,
          color: ink,
        ),
        bodyMedium: TextStyle(
          fontSize: 13.5,
          height: 1.48,
          fontWeight: FontWeight.w400,
          letterSpacing: -0.1,
          color: mutedInk,
        ),
        // 라벨/오버라인: 작게, 넓은 양수 자간 + 대문자 인상으로 에디토리얼 키커.
        labelLarge: TextStyle(
          fontSize: 13,
          height: 1.2,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
          color: ink,
        ),
        labelMedium: TextStyle(
          fontSize: 11,
          height: 1.3,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
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
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
          color: ink,
        ),
      ),
      // 카드는 1px 테두리 대신 순백 표면 + 아주 옅은 그림자로 깊이를 만든다.
      cardTheme: CardThemeData(
        elevation: 0.5,
        shadowColor: ink.withValues(alpha: 0.06),
        surfaceTintColor: Colors.transparent,
        color: surface,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ink,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFD8D8D4),
          disabledForegroundColor: Colors.white,
          minimumSize: const Size.fromHeight(56),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: const StadiumBorder(),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          foregroundColor: ink,
          side: const BorderSide(color: ink, width: 1.2),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          shape: const StadiumBorder(),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: ink,
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        labelStyle: const TextStyle(color: mutedInk),
        hintStyle: const TextStyle(color: mutedInk),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: ink, width: 1.4),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
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
