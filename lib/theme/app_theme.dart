import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// نظام الثيمات المركزي لتطبيق Orca Order
/// يدعم الوضع النهاري والليلي مع تصميم Glassmorphism وتوافق RTL
class AppTheme {
  static const Color _orcaTeal = Color(0xFF00658F);
  static const Color _orcaTealLight = Color(0xFF0087BF);

  static const Color _lightBackground = Color(0xFFF8FAFC);
  static const Color _lightSurface = Color(0xFFFFFFFF);

  static const Color _darkBackground = Color(0xFF0F172A);
  static const Color _darkSurface = Color(0xFF111827);
  static const Color _darkSurfaceVariant = Color(0xFF1E293B);

  static ThemeData get lightTheme => _buildTheme(Brightness.light);
  static ThemeData get darkTheme => _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: isDark ? _orcaTealLight : _orcaTeal,
      onPrimary: Colors.white,
      secondary: const Color(0xFFFFA726),
      onSecondary: Colors.white,
      error: const Color(0xFFE53935),
      onError: Colors.white,
      surface: isDark ? _darkSurface : _lightSurface,
      onSurface: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
      surfaceContainerHighest:
          isDark ? _darkSurfaceVariant : const Color(0xFFF1F5F9),
      outline: isDark ? const Color(0xFF475569) : const Color(0xFFE2E8F0),
    );
    final baseTextTheme = ThemeData(
      brightness: brightness,
      useMaterial3: true,
    ).textTheme;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      fontFamily: 'Tajawal',
      visualDensity: VisualDensity.adaptivePlatformDensity,
      textTheme: baseTextTheme.apply(
        bodyColor: colorScheme.onSurface,
        displayColor: colorScheme.onSurface,
        fontFamily: 'Tajawal',
      ),
      primaryTextTheme: baseTextTheme.apply(
        bodyColor: colorScheme.onPrimary,
        displayColor: colorScheme.onPrimary,
        fontFamily: 'Tajawal',
      ),
      scaffoldBackgroundColor: isDark ? _darkBackground : _lightBackground,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: isDark ? _darkSurface : _orcaTeal,
        foregroundColor: colorScheme.onPrimary,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: isDark ? _darkSurface : _orcaTeal,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
          systemNavigationBarColor: isDark ? _darkSurface : _lightSurface,
          systemNavigationBarIconBrightness:
              isDark ? Brightness.light : Brightness.dark,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: isDark ? _darkSurface : _lightSurface,
        selectedItemColor: isDark ? _orcaTealLight : _orcaTeal,
        unselectedItemColor: isDark ? Colors.grey[600] : Colors.grey[500],
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: colorScheme.outline,
            width: 1,
          ),
        ),
        color: isDark ? _darkSurface : _lightSurface,
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outline,
        thickness: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withValues(
          alpha: isDark ? 0.55 : 0.65,
        ),
        hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
        labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
        helperStyle: TextStyle(color: colorScheme.onSurfaceVariant),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.error),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: colorScheme.onSurface,
          fontFamily: 'Tajawal',
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: TextStyle(
          color: colorScheme.onSurface,
          fontFamily: 'Tajawal',
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: colorScheme.surface,
        showDragHandle: true,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        textStyle: TextStyle(color: colorScheme.onSurface),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF263449),
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontFamily: 'Tajawal',
        ),
        actionTextColor: const Color(0xFF80DEEA),
        behavior: SnackBarBehavior.floating,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.primary,
        linearTrackColor: colorScheme.surfaceContainerHighest,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: colorScheme.primary,
        selectionColor: colorScheme.primary.withValues(alpha: 0.28),
        selectionHandleColor: colorScheme.primary,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.primary.withValues(alpha: 0.14),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(color: colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }
}
