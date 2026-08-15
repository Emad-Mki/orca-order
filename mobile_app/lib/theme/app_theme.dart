import 'package:flutter/material.dart';

/// نظام الثيمات المركزي لتطبيق Orca Order
/// يدعم الوضع النهاري والليلي مع تصميم Glassmorphism
class AppTheme {
  // اللون الأساسي المستمد من شعار التطبيق (لون الأوركا - الأزرق المخضر)
  static const Color _orcaTeal = Color(0xFF00658F);
  static const Color _orcaTealLight = Color(0xFF0087BF);
  static const Color _orcaTealDark = Color(0xFF004D6B);
  
  // ألوان إضافية
  static const Color _accentOrange = Color(0xFFFFA726);
  static const Color _successGreen = Color(0xFF4CAF50);
  static const Color _errorRed = Color(0xFFE53935);
  static const Color _warningAmber = Color(0xFFFFC107);
  
  // ألوان الخلفية للوضع النهاري
  static const Color _lightBackground = Color(0xFFF5F7FA);
  static const Color _lightSurface = Color(0xFFFFFFFF);
  static const Color _lightSurfaceVariant = Color(0xFFF0F4F8);
  
  // ألوان الخلفية للوضع الليلي
  static const Color _darkBackground = Color(0xFF1A1A2E);
  static const Color _darkSurface = Color(0xFF16213E);
  static const Color _darkSurfaceVariant = Color(0xFF0F3460);
  
  // إعدادات Glassmorphism
  static const double _glassBorderRadius = 16.0;
  static const double _glassBlurSigma = 10.0;
  
  /// ثيم الوضع النهاري
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: 'Tajawal',
      
      // ColorScheme مخصص
      colorScheme: const ColorScheme.light(
        primary: _orcaTeal,
        onPrimary: Colors.white,
        primaryContainer: _orcaTealLight,
        onPrimaryContainer: Colors.white,
        secondary: _accentOrange,
        onSecondary: Colors.white,
        secondaryContainer: Color(0xFFFFE0B2),
        onSecondaryContainer: Color(0xFF5D4037),
        tertiary: _successGreen,
        onTertiary: Colors.white,
        error: _errorRed,
        onError: Colors.white,
        surface: _lightSurface,
        onSurface: Color(0xFF1C1C1E),
        surfaceContainerHighest: _lightSurfaceVariant,
        outline: Color(0xFFE0E0E0),
        shadow: Color(0x1A000000),
      ),
      
      // AppBar Theme
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: _orcaTeal,
        foregroundColor: Colors.white,
        titleTextStyle: TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      
      // Card Theme - Glassmorphism Style
      cardTheme: CardTheme(
        elevation: 4,
        shadowColor: const Color(0x1A000000),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_glassBorderRadius),
        ),
        margin: const EdgeInsets.all(8),
      ),
      
      // ElevatedButton Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: _orcaTeal,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      
      // OutlinedButton Theme
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          side: const BorderSide(color: _orcaTeal, width: 1.5),
          foregroundColor: _orcaTeal,
          textStyle: const TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      
      // TextButton Theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _orcaTeal,
          textStyle: const TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      
      // InputDecoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _lightSurfaceVariant,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _orcaTeal, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _errorRed, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _errorRed, width: 2),
        ),
        labelStyle: const TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 14,
          color: Color(0xFF757575),
        ),
        hintStyle: const TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 14,
          color: Color(0xFF9E9E9E),
        ),
      ),
      
      // BottomNavigationBar Theme
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        selectedItemColor: _orcaTeal,
        unselectedItemColor: Color(0xFF9E9E9E),
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        backgroundColor: _lightSurface,
      ),
      
      // FloatingActionButton Theme
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: _orcaTeal,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      
      // Chip Theme
      chipTheme: ChipThemeData(
        backgroundColor: _lightSurfaceVariant,
        deleteIconColor: _orcaTeal,
        labelStyle: const TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 14,
          color: Color(0xFF1C1C1E),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      
      // Dialog Theme
      dialogTheme: DialogTheme(
        elevation: 8,
        backgroundColor: _lightSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        titleTextStyle: const TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1C1C1E),
        ),
        contentTextStyle: const TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 16,
          color: Color(0xFF757575),
        ),
      ),
      
      // Snackbar Theme
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF323232),
        contentTextStyle: const TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 14,
          color: Colors.white,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      
      // Divider Theme
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE0E0E0),
        thickness: 1,
        space: 1,
      ),
      
      // Icon Theme
      iconTheme: const IconThemeData(
        color: _orcaTeal,
        size: 24,
      ),
      
      // Text Theme
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1C1C1E),
        ),
        displayMedium: TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1C1C1E),
        ),
        displaySmall: TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1C1C1E),
        ),
        headlineMedium: TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1C1C1E),
        ),
        titleLarge: TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1C1C1E),
        ),
        titleMedium: TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Color(0xFF1C1C1E),
        ),
        bodyLarge: TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 16,
          color: Color(0xFF1C1C1E),
        ),
        bodyMedium: TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 14,
          color: Color(0xFF757575),
        ),
        labelLarge: TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: _orcaTeal,
        ),
      ),
    );
  }
  
  /// ثيم الوضع الليلي
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: 'Tajawal',
      
      // ColorScheme مخصص للوضع الليلي
      colorScheme: const ColorScheme.dark(
        primary: _orcaTealLight,
        onPrimary: Colors.white,
        primaryContainer: _orcaTealDark,
        onPrimaryContainer: Color(0xFFB3E5FC),
        secondary: _accentOrange,
        onSecondary: Colors.white,
        secondaryContainer: Color(0xFF6D4C41),
        onSecondaryContainer: Color(0xFFFFE0B2),
        tertiary: _successGreen,
        onTertiary: Colors.white,
        error: _errorRed,
        onError: Colors.white,
        surface: _darkSurface,
        onSurface: Color(0xFFE8E8E8),
        surfaceContainerHighest: _darkSurfaceVariant,
        outline: Color(0xFF424242),
        shadow: Color(0x33000000),
      ),
      
      // AppBar Theme
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: _darkSurface,
        foregroundColor: Colors.white,
        titleTextStyle: TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      
      // Card Theme - Glassmorphism Style for Dark Mode
      cardTheme: CardTheme(
        elevation: 4,
        shadowColor: const Color(0x33000000),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_glassBorderRadius),
        ),
        margin: const EdgeInsets.all(8),
      ),
      
      // ElevatedButton Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: _orcaTealLight,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      
      // OutlinedButton Theme
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          side: const BorderSide(color: _orcaTealLight, width: 1.5),
          foregroundColor: _orcaTealLight,
          textStyle: const TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      
      // TextButton Theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _orcaTealLight,
          textStyle: const TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      
      // InputDecoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _darkSurfaceVariant,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF424242)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF424242), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _orcaTealLight, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _errorRed, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _errorRed, width: 2),
        ),
        labelStyle: const TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 14,
          color: Color(0xFFBDBDBD),
        ),
        hintStyle: const TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 14,
          color: Color(0xFF757575),
        ),
      ),
      
      // BottomNavigationBar Theme
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        selectedItemColor: _orcaTealLight,
        unselectedItemColor: Color(0xFF757575),
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        backgroundColor: _darkSurface,
      ),
      
      // FloatingActionButton Theme
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: _orcaTealLight,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      
      // Chip Theme
      chipTheme: ChipThemeData(
        backgroundColor: _darkSurfaceVariant,
        deleteIconColor: _orcaTealLight,
        labelStyle: const TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 14,
          color: Color(0xFFE8E8E8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      
      // Dialog Theme
      dialogTheme: DialogTheme(
        elevation: 8,
        backgroundColor: _darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        titleTextStyle: const TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Color(0xFFE8E8E8),
        ),
        contentTextStyle: const TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 16,
          color: Color(0xFFBDBDBD),
        ),
      ),
      
      // Snackbar Theme
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF424242),
        contentTextStyle: const TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 14,
          color: Colors.white,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      
      // Divider Theme
      dividerTheme: const DividerThemeData(
        color: Color(0xFF424242),
        thickness: 1,
        space: 1,
      ),
      
      // Icon Theme
      iconTheme: const IconThemeData(
        color: _orcaTealLight,
        size: 24,
      ),
      
      // Text Theme
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: Color(0xFFE8E8E8),
        ),
        displayMedium: TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: Color(0xFFE8E8E8),
        ),
        displaySmall: TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Color(0xFFE8E8E8),
        ),
        headlineMedium: TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Color(0xFFE8E8E8),
        ),
        titleLarge: TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Color(0xFFE8E8E8),
        ),
        titleMedium: TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Color(0xFFE8E8E8),
        ),
        bodyLarge: TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 16,
          color: Color(0xFFE8E8E8),
        ),
        bodyMedium: TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 14,
          color: Color(0xFFBDBDBD),
        ),
        labelLarge: TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: _orcaTealLight,
        ),
      ),
    );
  }
  
  /// الحصول على لون الشعار الأساسي
  static Color get brandColor => _orcaTeal;
  
  /// الحصول على لون الشعار الفاتح
  static Color get brandColorLight => _orcaTealLight;
  
  /// الحصول على لون الشعار الداكن
  static Color get brandColorDark => _orcaTealDark;
  
  /// الحصول على نصف قطر الزوايا للبطاقات الزجاجية
  static double get glassBorderRadius => _glassBorderRadius;
  
  /// الحصول على قيمة الضبابية للـ Glassmorphism
  static double get glassBlurSigma => _glassBlurSigma;
}
