import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

extension ColorAlphaFractionX on Color {
  Color withAlphaFraction(double opacity) {
    final clampedOpacity = opacity.clamp(0.0, 1.0).toDouble();
    return withAlpha((clampedOpacity * 255).round().clamp(0, 255));
  }
}

class AppColors {
  // Primary
  static const primary = Color(0xFF7C3AED);
  static const primaryDark = Color(0xFF5B21B6);

  // Secondary
  static const lavender = Color(0xFFDDD6FE);
  static const violet = Color(0xFFEDE9FE);

  // Accent
  static const accent = Color(0xFF3B82F6);
  static const accentGreen = Color(0xFF10B981);
  static const accentPink = Color(0xFFEC4899);

  static const darkPalette = AppColorPalette(
    primaryLight: Color(0xFFA78BFA),
    bgDark: Color(0xFF0F0A1A),
    bgCard: Color(0xFF1A1128),
    bgCardLight: Color(0xFF231839),
    bgSurface: Color(0xFF16102A),
    textPrimary: Color(0xFFF5F3FF),
    textSecondary: Color(0xFFA89EC8),
    textMuted: Color(0xFF6B5F8A),
    glassBg: Color(0x1AFFFFFF),
    glassBorder: Color(0x33FFFFFF),
    glassHighlight: Color(0x0DFFFFFF),
  );

  static const lightPalette = AppColorPalette(
    primaryLight: Color(0xFF6D28D9),
    bgDark: Color(0xFFF8F6FF),
    bgCard: Color(0xFFFFFFFF),
    bgCardLight: Color(0xFFF0ECFE),
    bgSurface: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF211433),
    textSecondary: Color(0xFF665C7D),
    textMuted: Color(0xFF8B819F),
    glassBg: Color(0xEFFFFFFF),
    glassBorder: Color(0x2635284B),
    glassHighlight: Color(0x99FFFFFF),
  );

  static bool _isLightMode = false;

  static void useLightMode(bool value) {
    _isLightMode = value;
  }

  static bool get isLightMode => _isLightMode;

  static AppColorPalette get palette =>
      _isLightMode ? lightPalette : darkPalette;

  // Background
  static Color get bgDark => palette.bgDark;
  static Color get bgCard => palette.bgCard;
  static Color get bgCardLight => palette.bgCardLight;
  static Color get bgSurface => palette.bgSurface;

  // Text
  static Color get textPrimary => palette.textPrimary;
  static Color get textSecondary => palette.textSecondary;
  static Color get textMuted => palette.textMuted;

  static Color get primaryLight => palette.primaryLight;

  // Status
  static const online = Color(0xFF10B981);
  static const offline = Color(0xFF6B7280);
  static const error = Color(0xFFEF4444);
  static const warning = Color(0xFFF59E0B);

  // Glassmorphism
  static Color get glassBg => palette.glassBg;
  static Color get glassBorder => palette.glassBorder;
  static Color get glassHighlight => palette.glassHighlight;
}

class AppColorPalette {
  const AppColorPalette({
    required this.primaryLight,
    required this.bgDark,
    required this.bgCard,
    required this.bgCardLight,
    required this.bgSurface,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.glassBg,
    required this.glassBorder,
    required this.glassHighlight,
  });

  final Color primaryLight;
  final Color bgDark;
  final Color bgCard;
  final Color bgCardLight;
  final Color bgSurface;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color glassBg;
  final Color glassBorder;
  final Color glassHighlight;
}

class AppGradients {
  static LinearGradient get primary => LinearGradient(
        colors: [AppColors.primary, AppColors.primaryLight],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static LinearGradient get primaryVertical => const LinearGradient(
        colors: [AppColors.primary, Color(0xFF9333EA)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      );

  static LinearGradient get hero => LinearGradient(
        colors: AppColors.isLightMode
            ? const [
                Color(0xFFF8F6FF),
                Color(0xFFEDE9FE),
                Color(0xFFE0F2FE),
                Color(0xFFF8F6FF),
              ]
            : const [
                Color(0xFF0F0A1A),
                Color(0xFF1E1145),
                Color(0xFF2D1B69),
                Color(0xFF0F0A1A),
              ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      );

  static LinearGradient get sentBubble => const LinearGradient(
        colors: [AppColors.primary, Color(0xFF9333EA)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static LinearGradient get error => const LinearGradient(
        colors: [AppColors.error, Color(0xFFB91C1C)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static LinearGradient get card => LinearGradient(
        colors: AppColors.isLightMode
            ? const [Color(0x147C3AED), Color(0x08FFFFFF)]
            : const [Color(0x1A7C3AED), Color(0x0D7C3AED)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static RadialGradient get purpleGlow => const RadialGradient(
        colors: [Color(0x337C3AED), Color(0x007C3AED)],
        radius: 0.8,
      );
}

class AppTheme {
  static ThemeData get lightTheme {
    return _buildTheme(
      brightness: Brightness.light,
      palette: AppColors.lightPalette,
    );
  }

  static ThemeData get darkTheme {
    return _buildTheme(
      brightness: Brightness.dark,
      palette: AppColors.darkPalette,
    );
  }

  static SystemUiOverlayStyle systemOverlayStyleFor(ThemeMode themeMode) {
    final isLight = themeMode == ThemeMode.light;
    final palette = isLight ? AppColors.lightPalette : AppColors.darkPalette;
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isLight ? Brightness.dark : Brightness.light,
      statusBarBrightness: isLight ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: palette.bgSurface,
      systemNavigationBarIconBrightness:
          isLight ? Brightness.dark : Brightness.light,
    );
  }

  static ThemeData _buildTheme({
    required Brightness brightness,
    required AppColorPalette palette,
  }) {
    final isDark = brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: palette.bgDark,
      fontFamily: 'Inter',
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: AppColors.primary,
        secondary: palette.primaryLight,
        surface: palette.bgCard,
        error: AppColors.error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: palette.textPrimary,
        onError: Colors.white,
      ),
      dialogTheme: DialogTheme(
        backgroundColor: palette.bgSurface,
        titleTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: palette.textPrimary,
        ),
        contentTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          color: palette.textSecondary,
        ),
      ),
      dividerTheme: DividerThemeData(color: palette.glassBorder),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? palette.bgSurface : const Color(0xFF211433),
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontFamily: 'Inter',
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle:
            isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        titleTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: palette.textPrimary,
        ),
        iconTheme: IconThemeData(color: palette.textPrimary),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: palette.bgSurface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: palette.textMuted,
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
        selectedLabelStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 11,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.glassBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: palette.glassBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: palette.glassBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        hintStyle: TextStyle(color: palette.textMuted, fontFamily: 'Inter'),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: palette.primaryLight,
          textStyle:
              const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}
