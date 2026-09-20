// Custom TextTheme for Tarmeem Design System
// Uses Bricolage Grotesque for headings and Work Sans for body/labels
// Line heights are generously set for Arabic glyph script legibility
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Builds the custom Tarmeem [TextTheme] using Google Fonts.
///
/// Falls back to the system Arabic font if Bricolage Grotesque is unavailable.
TextTheme buildTarmeemTextTheme({Color? color}) {
  final baseColor = color ?? const Color(0xFF1A1C1A);

  // Heading style — Bricolage Grotesque (falls back to serif if unavailable)
  TextStyle heading(double size, FontWeight weight, double height) {
    try {
      return GoogleFonts.bricolageGrotesque(
        fontSize: size,
        fontWeight: weight,
        height: height / size,
        color: baseColor,
      );
    } catch (_) {
      return TextStyle(
        fontSize: size,
        fontWeight: weight,
        height: height / size,
        color: baseColor,
        fontFamily: 'serif',
      );
    }
  }

  // Body/label style — Work Sans
  TextStyle body(double size, FontWeight weight, double height) {
    try {
      return GoogleFonts.workSans(
        fontSize: size,
        fontWeight: weight,
        height: height / size,
        color: baseColor,
      );
    } catch (_) {
      return TextStyle(
        fontSize: size,
        fontWeight: weight,
        height: height / size,
        color: baseColor,
      );
    }
  }

  return TextTheme(
    // Display styles — largest headlines
    displayLarge: heading(34, FontWeight.w700, 44),  // display-lg
    displayMedium: heading(28, FontWeight.w700, 38), // display-lg-mobile
    displaySmall: heading(24, FontWeight.w700, 34),  // headline-lg

    // Headline styles
    headlineLarge: heading(24, FontWeight.w700, 34),  // headline-lg
    headlineMedium: heading(20, FontWeight.w600, 30), // headline-md
    headlineSmall: heading(18, FontWeight.w600, 26),  // headline-sm

    // Title styles — reuse heading font
    titleLarge: heading(18, FontWeight.w600, 26),
    titleMedium: heading(16, FontWeight.w500, 24),
    titleSmall: heading(14, FontWeight.w500, 20),

    // Body styles — Work Sans
    bodyLarge: body(16, FontWeight.w500, 26),   // body-lg
    bodyMedium: body(14, FontWeight.w400, 22),  // body-md
    bodySmall: body(12, FontWeight.w400, 18),   // body-sm

    // Label styles — Work Sans bold
    labelLarge: body(14, FontWeight.w600, 20),  // label-lg
    labelMedium: body(12, FontWeight.w600, 16), // label-md
    labelSmall: body(10, FontWeight.w600, 14),  // label-sm
  );
}
