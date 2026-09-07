import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = 'theme_mode';
  bool _isDarkMode = false;

  ThemeProvider() {
    if (!kIsWeb) {
      _loadThemeFromPrefs();
    }
  }

  /// Dark mode is strictly for mobile only. On Web, always enforce light mode.
  bool get isDarkMode => kIsWeb ? false : _isDarkMode;

  // Light theme colors
  Color get primaryColor => const Color(0xFF00BFA5);
  Color get backgroundColor => isDarkMode ? const Color(0xFF121212) : const Color(0xFFF8F9FA);
  Color get cardColor => isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
  Color get textColor => isDarkMode ? Colors.white : const Color(0xFF111827);
  Color get subtitleColor => isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600;
  Color get borderColor => isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200;
  Color get dividerColor => isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200;
  Color get iconColor => isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700;
  
  // App bar colors
  Color get appBarColor => isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
  Color get appBarTextColor => isDarkMode ? Colors.white : Colors.black87;
  Color get appBarIconColor => isDarkMode ? Colors.white : Colors.black87;
  
  // Navigation colors
  Color get navBarColor => isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
  Color get navBarTextColor => isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600;
  
  // Input field colors
  Color get inputFillColor => isDarkMode ? const Color(0xFF2D2D2D) : Colors.grey.shade50;
  Color get inputBorderColor => isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300;
  Color get inputTextColor => isDarkMode ? Colors.white : Colors.black87;
  
  // Drawer colors
  Color get drawerBackgroundColor => primaryColor;
  Color get drawerTextColor => Colors.white;
  
  // Shadow color
  Color get shadowColor => isDarkMode ? Colors.black.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.08);

  ThemeData get themeData {
    return ThemeData(
      useMaterial3: true,
      fontFamily: GoogleFonts.firaSans().fontFamily,
      brightness: isDarkMode ? Brightness.dark : Brightness.light,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: backgroundColor,
      cardColor: cardColor,
      dividerColor: dividerColor,
      
      appBarTheme: AppBarTheme(
        backgroundColor: appBarColor,
        foregroundColor: appBarTextColor,
        elevation: 0,
        iconTheme: IconThemeData(color: appBarIconColor),
        titleTextStyle: TextStyle(
          color: appBarTextColor,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: primaryColor,
        selectionColor: primaryColor.withValues(alpha: 0.3),
        selectionHandleColor: primaryColor,
      ),
      
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: borderColor),
        ),
      ),
      
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDarkMode ? const Color(0xFF242424) : const Color(0xFFF8FAFC),
        hintStyle: TextStyle(
          color: isDarkMode ? Colors.grey.shade500 : const Color(0xFF94A3B8),
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide(color: inputBorderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide(color: inputBorderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
        prefixIconColor: isDarkMode ? Colors.grey.shade400 : const Color(0xFF64748B),
        suffixIconColor: isDarkMode ? Colors.grey.shade400 : const Color(0xFF64748B),
      ),
      
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: textColor),
        bodyMedium: TextStyle(color: textColor),
        bodySmall: TextStyle(color: subtitleColor),
        titleLarge: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        titleMedium: TextStyle(color: textColor, fontWeight: FontWeight.w600),
        titleSmall: TextStyle(color: textColor),
      ),
      
      iconTheme: IconThemeData(color: iconColor),
      
      colorScheme: ColorScheme(
        brightness: isDarkMode ? Brightness.dark : Brightness.light,
        primary: primaryColor,
        onPrimary: Colors.white,
        secondary: primaryColor,
        onSecondary: Colors.white,
        error: Colors.red,
        onError: Colors.white,
        surface: cardColor,
        onSurface: textColor,
      ),
    );
  }

  Future<void> toggleTheme() async {
    if (kIsWeb) return;
    _isDarkMode = !_isDarkMode;
    notifyListeners();
    await _saveThemeToPrefs();
  }

  Future<void> setDarkMode(bool value) async {
    if (kIsWeb) return;
    _isDarkMode = value;
    notifyListeners();
    await _saveThemeToPrefs();
  }

  Future<void> _saveThemeToPrefs() async {
    if (kIsWeb) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_themeKey, _isDarkMode);
    } catch (e) {
      debugPrint('Error saving theme preference: $e');
    }
  }

  Future<void> _loadThemeFromPrefs() async {
    if (kIsWeb) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getBool(_themeKey);
      if (saved == null) return;
      _isDarkMode = saved;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading theme preference: $e');
    }
  }
}
