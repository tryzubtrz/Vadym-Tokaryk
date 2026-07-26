import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final display = GoogleFonts.nunito(
      fontWeight: FontWeight.w800,
      color: AppColors.brandInk,
    );
    final body = GoogleFonts.nunito(
      fontWeight: FontWeight.w500,
      color: AppColors.brandInk,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.brandPaper,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.brandCoral,
        primary: AppColors.brandCoral,
        secondary: AppColors.brandSky,
        tertiary: AppColors.brandMint,
        surface: AppColors.brandPaper,
      ),
      textTheme: TextTheme(
        displayLarge: display.copyWith(fontSize: 40),
        displayMedium: display.copyWith(fontSize: 32),
        displaySmall: display.copyWith(fontSize: 26),
        headlineMedium: display.copyWith(fontSize: 22),
        headlineSmall: display.copyWith(fontSize: 18),
        titleLarge: body.copyWith(fontSize: 18, fontWeight: FontWeight.w700),
        titleMedium: body.copyWith(fontSize: 16, fontWeight: FontWeight.w700),
        bodyLarge: body.copyWith(fontSize: 16),
        bodyMedium: body.copyWith(fontSize: 14),
        bodySmall: body.copyWith(fontSize: 12),
        labelLarge: body.copyWith(fontSize: 14, fontWeight: FontWeight.w800),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        foregroundColor: AppColors.brandInk,
        titleTextStyle: display.copyWith(fontSize: 20),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brandCoral,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: body.copyWith(fontWeight: FontWeight.w800, fontSize: 16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
