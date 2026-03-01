import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const background = Color(0xFF0C0C0C);
  static const surface = Color(0xFF1A1A1A);
  static const elevated = Color(0xFF242424);
  static const border = Color(0xFF2A2A2A);

  static const primaryText = Color(0xFFFFFFFF);
  static const secondaryText = Color(0xFF8A8A8A);
  static const mutedText = Color(0xFF525252);

  static const accent = Color(0xFFFF3B30);
  static const accentMuted = Color(0xFF3A0A08);
}

class AppTheme {
  static ThemeData get dark {
    final base = ThemeData.dark();
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.dark(
        surface: AppColors.surface,
        primary: AppColors.accent,
        onPrimary: AppColors.primaryText,
        onSurface: AppColors.primaryText,
        outline: AppColors.border,
      ),
      textTheme: GoogleFonts.soraTextTheme(base.textTheme).apply(
        bodyColor: AppColors.primaryText,
        displayColor: AppColors.primaryText,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.primaryText,
        elevation: 0,
        titleTextStyle: GoogleFonts.sora(
          color: AppColors.primaryText,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.accent,
        unselectedItemColor: AppColors.secondaryText,
      ),
      cardTheme: const CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          side: BorderSide(color: AppColors.border),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.primaryText,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.sora(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.accent),
        ),
        hintStyle: GoogleFonts.sora(color: AppColors.mutedText),
      ),
    );
  }
}
