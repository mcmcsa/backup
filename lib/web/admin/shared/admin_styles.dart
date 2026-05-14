import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AdminStyles {
  // Core Professional Palette - Teal & Slate
  static const Color bg = Color(0xFFF0FDFA); // Teal 50 - Very soft background
  static const Color surface = Colors.white;
  static const Color border = Color(0xFFE2E8F0); // Slate 200 - Subtle borders
  
  static const Color primary = Color(0xFF0F766E); // Teal 700 - Primary brand
  static const Color primaryLight = Color(0xFF14B8A6); // Teal 500 - Secondary brand
  static const Color secondary = Color(0xFF0369A1); // Blue 700 - CTA/Action
  
  static const Color textPrimary = Color(0xFF134E4A); // Teal 900 - High emphasis
  static const Color textSecondary = Color(0xFF475569); // Slate 600 - Muted text
  static const Color textMuted = Color(0xFF94A3B8); // Slate 400 - Muted
  
  // Status Colors
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF0EA5E9);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Typography
  static TextStyle headingStyle({
    double fontSize = 24,
    FontWeight fontWeight = FontWeight.w800,
    Color color = textPrimary,
    double? letterSpacing,
  }) {
    return GoogleFonts.firaSans(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing ?? -0.5,
    );
  }

  static TextStyle bodyStyle({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w500,
    Color color = textSecondary,
    double? height,
    double? letterSpacing,
  }) {
    return GoogleFonts.firaSans(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle pageTitleStyle({
    double fontSize = 24,
    FontWeight fontWeight = FontWeight.w800,
    Color color = textPrimary,
    double? letterSpacing,
  }) {
    return GoogleFonts.firaSans(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing ?? -0.5,
    );
  }

  static TextStyle pageSubtitleStyle({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w500,
    Color color = textSecondary,
    double? letterSpacing,
  }) {
    return GoogleFonts.firaSans(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle dataStyle({
    double fontSize = 13,
    FontWeight fontWeight = FontWeight.w600,
    Color color = textPrimary,
  }) {
    return GoogleFonts.firaCode(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
    );
  }

  // Common Decorations
  static BoxDecoration cardDecoration({
    Color color = surface,
    double borderRadius = 16,
    bool hasShadow = true,
    Color? borderColor,
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: borderColor ?? border),
      boxShadow: hasShadow
          ? [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ]
          : null,
    );
  }

  static BoxDecoration glassDecoration({
    Color color = Colors.white,
    double opacity = 0.7,
    double borderRadius = 20,
    bool hasBorder = true,
  }) {
    return BoxDecoration(
      color: color.withValues(alpha: opacity),
      borderRadius: BorderRadius.circular(borderRadius),
      border: hasBorder
          ? Border.all(color: Colors.white.withValues(alpha: 0.25))
          : null,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  static BoxDecoration pillDecoration({
    required Color color,
    bool isSecondary = false,
  }) {
    return BoxDecoration(
      color: color.withValues(alpha: isSecondary ? 0.1 : 1.0),
      borderRadius: BorderRadius.circular(999),
      border: isSecondary ? Border.all(color: color.withValues(alpha: 0.3)) : null,
    );
  }

  static BoxDecoration sidebarItemDecoration({bool isActive = false}) {
    return BoxDecoration(
      color: isActive ? primary.withValues(alpha: 0.1) : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      border: isActive ? Border.all(color: primary.withValues(alpha: 0.2)) : null,
    );
  }

  static InputDecoration searchInputDecoration({
    required String hintText,
    required IconData prefixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: bodyStyle(color: textMuted, fontSize: 13, fontWeight: FontWeight.w500),
      prefixIcon: Icon(prefixIcon, color: textMuted, size: 20),
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 12),
    );
  }
}
