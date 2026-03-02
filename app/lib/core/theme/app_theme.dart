import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─────────────────────────────────────────────────────────
// Turmeric & Nightfall — Remembite Design System
// Fonts: Fraunces (display) + DM Sans (body/labels)
// ─────────────────────────────────────────────────────────

class AppColorsDark {
  static const background   = Color(0xFF0F0D0B); // Abyss
  static const surface      = Color(0xFF1A1612); // Embers
  static const elevated     = Color(0xFF241E18); // Char
  static const border       = Color(0xFF2E2520); // Dusk

  static const primaryText   = Color(0xFFF5EEE4); // Cream
  static const secondaryText = Color(0xFFB89F87); // Parchment
  static const mutedText     = Color(0xFF8E7868); // Ash — 4.7:1 on Abyss

  static const accent      = Color(0xFFE6A830); // Turmeric
  static const accentPress = Color(0xFFC98A1A); // Saffron
  static const accentMuted = Color(0xFF2A2115); // Gilded tint

  static const error = Color(0xFFD95F3B); // Chili

  static const proSurface = Color(0xFF2A2115); // Gilded
  static const proAccent  = Color(0xFFF0C060); // Gold Leaf
}

class AppColorsLight {
  static const background   = Color(0xFFFAF7F2); // Linen
  static const surface      = Color(0xFFF2EDE5); // Cotton
  static const elevated     = Color(0xFFEBE4D9); // Pearl
  static const border       = Color(0xFFD9CFC3); // Wheat

  static const primaryText   = Color(0xFF1C1410); // Espresso
  static const secondaryText = Color(0xFF5C4A38); // Bark
  static const mutedText     = Color(0xFF7A6350); // Sand — 5.3:1 on Linen

  static const accent      = Color(0xFFC47E10); // Turmeric (darkened for contrast)
  static const accentPress = Color(0xFFA36808); // Deep Amber
  static const accentMuted = Color(0xFFFFF3D6); // Honey tint

  static const error = Color(0xFFC04A28); // Chili Light

  static const proSurface = Color(0xFFFFF3D6); // Honey
  static const proAccent  = Color(0xFFB8720E); // Amber Pro
}

// Convenience alias — defaults to dark (primary theme)
typedef AppColors = AppColorsDark;

class AppTheme {
  static ThemeData get dark {
    final base = ThemeData.dark();
    return base.copyWith(
      scaffoldBackgroundColor: AppColorsDark.background,
      colorScheme: const ColorScheme.dark(
        surface: AppColorsDark.surface,
        primary: AppColorsDark.accent,
        onPrimary: AppColorsDark.primaryText,
        onSurface: AppColorsDark.primaryText,
        outline: AppColorsDark.border,
        error: AppColorsDark.error,
      ),
      textTheme: _buildTextTheme(base.textTheme).apply(
        bodyColor: AppColorsDark.primaryText,
        displayColor: AppColorsDark.primaryText,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColorsDark.background,
        foregroundColor: AppColorsDark.primaryText,
        elevation: 0,
        titleTextStyle: GoogleFonts.dmSans(
          color: AppColorsDark.primaryText,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColorsDark.surface,
        selectedItemColor: AppColorsDark.accent,
        unselectedItemColor: AppColorsDark.secondaryText,
      ),
      cardTheme: const CardThemeData(
        color: AppColorsDark.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          side: BorderSide(color: AppColorsDark.border),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColorsDark.accent,
          foregroundColor: AppColorsDark.primaryText,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          textStyle: GoogleFonts.dmSans(fontWeight: FontWeight.w600, fontSize: 17),
          minimumSize: const Size(double.infinity, 56),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColorsDark.secondaryText,
          side: const BorderSide(color: AppColorsDark.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          textStyle: GoogleFonts.dmSans(fontWeight: FontWeight.w500, fontSize: 15),
          minimumSize: const Size(double.infinity, 52),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColorsDark.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColorsDark.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColorsDark.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColorsDark.accent),
        ),
        hintStyle: GoogleFonts.dmSans(color: AppColorsDark.mutedText),
      ),
    );
  }

  static ThemeData get light {
    final base = ThemeData.light();
    return base.copyWith(
      scaffoldBackgroundColor: AppColorsLight.background,
      colorScheme: const ColorScheme.light(
        surface: AppColorsLight.surface,
        primary: AppColorsLight.accent,
        onPrimary: Colors.white,
        onSurface: AppColorsLight.primaryText,
        outline: AppColorsLight.border,
        error: AppColorsLight.error,
      ),
      textTheme: _buildTextTheme(base.textTheme).apply(
        bodyColor: AppColorsLight.primaryText,
        displayColor: AppColorsLight.primaryText,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColorsLight.background,
        foregroundColor: AppColorsLight.primaryText,
        elevation: 0,
        titleTextStyle: GoogleFonts.dmSans(
          color: AppColorsLight.primaryText,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColorsLight.surface,
        selectedItemColor: AppColorsLight.accent,
        unselectedItemColor: AppColorsLight.secondaryText,
      ),
      cardTheme: const CardThemeData(
        color: AppColorsLight.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          side: BorderSide(color: AppColorsLight.border),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColorsLight.accent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          textStyle: GoogleFonts.dmSans(fontWeight: FontWeight.w600, fontSize: 17),
          minimumSize: const Size(double.infinity, 56),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColorsLight.secondaryText,
          side: const BorderSide(color: AppColorsLight.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          textStyle: GoogleFonts.dmSans(fontWeight: FontWeight.w500, fontSize: 15),
          minimumSize: const Size(double.infinity, 52),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColorsLight.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColorsLight.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColorsLight.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColorsLight.accent),
        ),
        hintStyle: GoogleFonts.dmSans(color: AppColorsLight.mutedText),
      ),
    );
  }

  // Fraunces for display/headlines, DM Sans for body/labels
  static TextTheme _buildTextTheme(TextTheme base) {
    return base.copyWith(
      displayLarge:  GoogleFonts.fraunces(fontSize: 57, fontWeight: FontWeight.w700),
      displayMedium: GoogleFonts.fraunces(fontSize: 45, fontWeight: FontWeight.w700),
      displaySmall:  GoogleFonts.fraunces(fontSize: 36, fontWeight: FontWeight.w700),
      headlineLarge:  GoogleFonts.fraunces(fontSize: 32, fontWeight: FontWeight.w700),
      headlineMedium: GoogleFonts.fraunces(fontSize: 28, fontWeight: FontWeight.w700),
      headlineSmall:  GoogleFonts.fraunces(fontSize: 24, fontWeight: FontWeight.w600),
      titleLarge:  GoogleFonts.dmSans(fontSize: 22, fontWeight: FontWeight.w600),
      titleMedium: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w600),
      titleSmall:  GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600),
      bodyLarge:   GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w400),
      bodyMedium:  GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w400),
      bodySmall:   GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w400),
      labelLarge:  GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600),
      labelMedium: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600),
      labelSmall:  GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.8),
    );
  }
}
