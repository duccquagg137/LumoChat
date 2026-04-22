import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

extension ColorAlphaFractionX on Color {
  Color withAlphaFraction(double opacity) {
    final clampedOpacity = opacity.clamp(0.0, 1.0).toDouble();
    final argb = value;
    return Color.fromARGB(
      (clampedOpacity * 255).round(),
      (argb >> 16) & 0xFF,
      (argb >> 8) & 0xFF,
      argb & 0xFF,
    );
  }
}

class AppColors {
  // Primary
  static const primary = Color(0xFF7C3AED);
  static const primaryLight = Color(0xFFA78BFA);
  static const primaryDark = Color(0xFF5B21B6);
  
  // Secondary
  static const lavender = Color(0xFFDDD6FE);
  static const violet = Color(0xFFEDE9FE);
  
  // Accent
  static const accent = Color(0xFF3B82F6);
  static const accentGreen = Color(0xFF10B981);
  static const accentPink = Color(0xFFEC4899);
  
  // Background
  static const bgDark = Color(0xFF0F0A1A);
  static const bgCard = Color(0xFF1A1128);
  static const bgCardLight = Color(0xFF231839);
  static const bgSurface = Color(0xFF16102A);
  
  // Text
  static const textPrimary = Color(0xFFF5F3FF);
  static const textSecondary = Color(0xFFA89EC8);
  static const textMuted = Color(0xFF6B5F8A);
  
  // Status
  static const online = Color(0xFF10B981);
  static const offline = Color(0xFF6B7280);
  static const error = Color(0xFFEF4444);
  static const warning = Color(0xFFF59E0B);
  
  // Glassmorphism
  static const glassBg = Color(0x1AFFFFFF);
  static const glassBorder = Color(0x33FFFFFF);
  static const glassHighlight = Color(0x0DFFFFFF);
}

class AppGradients {
  static const primary = LinearGradient(
    colors: [Color(0xFF7C3AED), Color(0xFFA78BFA)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const primaryVertical = LinearGradient(
    colors: [Color(0xFF7C3AED), Color(0xFF9333EA)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  
  static const hero = LinearGradient(
    colors: [Color(0xFF0F0A1A), Color(0xFF1E1145), Color(0xFF2D1B69), Color(0xFF0F0A1A)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  
  static const sentBubble = LinearGradient(
    colors: [Color(0xFF7C3AED), Color(0xFF9333EA)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const error = LinearGradient(
    colors: [Color(0xFFEF4444), Color(0xFFB91C1C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const card = LinearGradient(
    colors: [Color(0x1A7C3AED), Color(0x0D7C3AED)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const purpleGlow = RadialGradient(
    colors: [Color(0x337C3AED), Color(0x007C3AED)],
    radius: 0.8,
  );
}

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.bgDark,
      fontFamily: 'Inter',
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.primaryLight,
        surface: AppColors.bgCard,
        error: AppColors.error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.textPrimary,
        onError: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.bgSurface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textMuted,
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
        selectedLabelStyle: TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(fontFamily: 'Inter', fontSize: 11),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.glassBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.glassBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.glassBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        hintStyle: const TextStyle(color: AppColors.textMuted, fontFamily: 'Inter'),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryLight,
          textStyle: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}
