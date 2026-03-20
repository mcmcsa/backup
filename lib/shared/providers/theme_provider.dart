import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = 'theme_mode';
  bool _isDarkMode = false;

  ThemeProvider();

  bool get isDarkMode => _isDarkMode;

  // Light theme colors
  Color get primaryColor => const Color(0xFF00BFA5);
  Color get backgroundColor => _isDarkMode ? const Color(0xFF121212) : const Color(0xFFF8F9FA);
  Color get cardColor => _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
  Color get textColor => _isDarkMode ? Colors.white : const Color(0xFF111827);
  Color get subtitleColor => _isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600;
  Color get borderColor => _isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200;
  Color get dividerColor => _isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200;
  Color get iconColor => _isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700;
  
  // App bar colors
  Color get appBarColor => _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
  Color get appBarTextColor => _isDarkMode ? Colors.white : Colors.black87;
  Color get appBarIconColor => _isDarkMode ? Colors.white : Colors.black87;
  
  // Navigation colors
  Color get navBarColor => _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
  Color get navBarTextColor => _isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600;
  
  // Input field colors
  Color get inputFillColor => _isDarkMode ? const Color(0xFF2D2D2D) : Colors.grey.shade50;
  Color get inputBorderColor => _isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300;
  Color get inputTextColor => _isDarkMode ? Colors.white : Colors.black87;
  
  // Drawer colors
  Color get drawerBackgroundColor => primaryColor;
  Color get drawerTextColor => Colors.white;
  
  // Shadow color
  Color get shadowColor => _isDarkMode ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.08);

  ThemeData get themeData {
    return ThemeData(
      useMaterial3: true,
      brightness: _isDarkMode ? Brightness.dark : Brightness.light,
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
        fillColor: inputFillColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: inputBorderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: inputBorderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
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
        brightness: _isDarkMode ? Brightness.dark : Brightness.light,
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
    _isDarkMode = !_isDarkMode;
    notifyListeners();
    await _saveThemeToPrefs();
  }

  Future<void> setDarkMode(bool value) async {
    _isDarkMode = value;
    notifyListeners();
    await _saveThemeToPrefs();
  }

  Future<void> _saveThemeToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_themeKey, _isDarkMode);
    } catch (e) {
      debugPrint('Error saving theme preference: $e');
    }
  }
}
