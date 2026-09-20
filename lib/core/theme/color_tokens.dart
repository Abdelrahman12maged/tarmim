// Core color tokens from Tarmeem Design System (DESIGN.md)
// All colors are defined as constants to ensure consistency across the app.
import 'package:flutter/material.dart';

/// Primary brand colors — Deep Forest Teal palette with dark mode support.
abstract class TarmeemColors {
  // ── Primary ──────────────────────────────────────────────────────────────
  static const Color primary = Color(0xFF003633);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryContainer = Color(0xFF134E4A);
  static const Color onPrimaryContainer = Color(0xFF87BEB8);
  static const Color inversePrimary = Color(0xFF9AD1CB);

  // ── Secondary ─────────────────────────────────────────────────────────────
  static const Color secondary = Color(0xFF006A63);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color secondaryContainer = Color(0xFF99EFE5);
  static const Color onSecondaryContainer = Color(0xFF006F67);

  // ── Tertiary (Amber) ──────────────────────────────────────────────────────
  static const Color tertiary = Color(0xFF4C2600);
  static const Color onTertiary = Color(0xFFFFFFFF);
  static const Color tertiaryContainer = Color(0xFF6D3800);
  static const Color onTertiaryContainer = Color(0xFFFF9C42);

  // ── Error ─────────────────────────────────────────────────────────────────
  static const Color error = Color(0xFFBA1A1A);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onErrorContainer = Color(0xFF93000A);

  // ── Surface / Background (Light) ──────────────────────────────────────────
  static const Color surface = Color(0xFFFAF9F6);
  static const Color surfaceDim = Color(0xFFDBDAD7);
  static const Color surfaceBright = Color(0xFFFAF9F6);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFF4F3F1);
  static const Color surfaceContainer = Color(0xFFEFEEEB);
  static const Color surfaceContainerHigh = Color(0xFFE9E8E5);
  static const Color surfaceContainerHighest = Color(0xFFE3E2E0);
  static const Color onSurface = Color(0xFF1A1C1A);
  static const Color onSurfaceVariant = Color(0xFF404847);
  static const Color inverseSurface = Color(0xFF2F312F);
  static const Color inverseOnSurface = Color(0xFFF2F1EE);
  static const Color outline = Color(0xFF707977);
  static const Color outlineVariant = Color(0xFFBFC8C6);
  static const Color surfaceTint = Color(0xFF316763);
  static const Color background = Color(0xFFFAF9F6);
  static const Color onBackground = Color(0xFF1A1C1A);
  static const Color surfaceVariant = Color(0xFFE3E2E0);

  // ── Fixed palettes ────────────────────────────────────────────────────────
  static const Color primaryFixed = Color(0xFFB5EDE7);
  static const Color primaryFixedDim = Color(0xFF9AD1CB);
  static const Color onPrimaryFixed = Color(0xFF00201E);
  static const Color onPrimaryFixedVariant = Color(0xFF144F4B);

  // ── Status badge tokens ───────────────────────────────────────────────────
  // In Diagnosis (قيد الفحص)
  static const Color diagnosisText = Color(0xFF92400E);
  static const Color diagnosisDot = Color(0xFFD97706);
  static const Color diagnosisBackground = Color(0xFFFEF3C7);
  static const Color diagnosisBorder = Color(0xFFFDE68A);

  // Waiting for Part (بانتظار قطعة)
  static const Color waitingText = Color(0xFF3730A3);
  static const Color waitingDot = Color(0xFF4F46E5);
  static const Color waitingBackground = Color(0xFFEEF2FF);
  static const Color waitingBorder = Color(0xFFC7D2FE);

  // Ready for Pickup (جاهز للاستلام)
  static const Color readyText = Color(0xFF065F46);
  static const Color readyDot = Color(0xFF059669);
  static const Color readyBackground = Color(0xFFD1FAE5);
  static const Color readyBadgeBg = Color(0xFFD1FAE5);
  static const Color readyBorder = Color(0xFFA7F3D0);

  // Delivered / Completed (تم التسليم)
  static const Color deliveredText = Color(0xFF374151);
  static const Color deliveredDot = Color(0xFF4B5563);
  static const Color deliveredBackground = Color(0xFFF3F4F6);
  static const Color deliveredBorder = Color(0xFFE5E7EB);

  // ── Elevation level colors ────────────────────────────────────────────────
  static const Color elevationLevel0 = Color(0xFFFAF9F6); // Floor/Canvas
  static const Color elevationLevel1 = Color(0xFFFFFFFF); // Work Card
  static const Color elevationLevel2 = Color(0xFFFFFFFF); // Active / Floating
  static const Color elevationLevel3 = Color(0xFFFFFFFF); // Modal Sheet

  /// Card border color from design spec
  static const Color cardBorder = Color(0x12134E4A); // rgba(19,78,74,0.07)

  // ── Dark theme equivalents ────────────────────────────────────────────────
  static const Color darkSurface = Color(0xFF111412);
  static const Color darkSurfaceContainerLowest = Color(0xFF181B19);
  static const Color darkSurfaceContainer = Color(0xFF1E2120);
  static const Color darkSurfaceContainerLow = Color(0xFF222624);
  static const Color darkSurfaceContainerHigh = Color(0xFF282B29);
  static const Color darkSurfaceContainerHighest = Color(0xFF333836);
  static const Color darkOnSurface = Color(0xFFF1F5F9);
  static const Color darkOnSurfaceVariant = Color(0xFF94A3B8);
  static const Color darkPrimary = Color(0xFF2DD4BF); // Vibrant modern teal
  static const Color darkOnPrimary = Color(0xFF003734);
  static const Color darkPrimaryContainer = Color(0xFF0D9488);
  static const Color darkOnPrimaryContainer = Color(0xFFCCFBF1);
  static const Color darkSecondary = Color(0xFF80D5CB);
  static const Color darkOnSecondary = Color(0xFF003733);
  static const Color darkSecondaryContainer = Color(0xFF004F4A);
  static const Color darkOnSecondaryContainer = Color(0xFF9CF2E8);
  static const Color darkBackground = Color(0xFF0F1210);
  static const Color darkOutline = Color(0xFF64748B);
  static const Color darkOutlineVariant = Color(0xFF334155);
  static const Color darkCardBorder = Color(0x22FFFFFF);
  static const Color darkPrimaryFixed = Color(0xFF134E4A);
  static const Color darkOnPrimaryFixed = Color(0xFFB5EDE7);

  // ── Dark Status Badges ────────────────────────────────────────────────────
  static const Color darkDiagnosisBackground = Color(0xFF451A03);
  static const Color darkDiagnosisText = Color(0xFFFCD34D);
  static const Color darkDiagnosisBorder = Color(0xFF78350F);
  static const Color darkDiagnosisDot = Color(0xFFF59E0B);

  static const Color darkWaitingBackground = Color(0xFF1E1B4B);
  static const Color darkWaitingText = Color(0xFFA5B4FC);
  static const Color darkWaitingBorder = Color(0xFF312E81);
  static const Color darkWaitingDot = Color(0xFF6366F1);

  static const Color darkReadyBackground = Color(0xFF064E3B);
  static const Color darkReadyText = Color(0xFF6EE7B7);
  static const Color darkReadyBorder = Color(0xFF047857);
  static const Color darkReadyDot = Color(0xFF10B981);

  static const Color darkDeliveredBackground = Color(0xFF1F2937);
  static const Color darkDeliveredText = Color(0xFF9CA3AF);
  static const Color darkDeliveredBorder = Color(0xFF374151);
  static const Color darkDeliveredDot = Color(0xFF94A3B8);

  // ── Context-aware Dynamic Helpers ─────────────────────────────────────────
  static Color cardBg(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkSurfaceContainer
          : surfaceContainerLowest;

  static Color cardBgLow(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkSurfaceContainerLow
          : surfaceContainerLow;

  static Color cardBgHigh(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkSurfaceContainerHigh
          : surfaceContainerHigh;

  static Color text(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkOnSurface
          : onSurface;

  static Color textMuted(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkOnSurfaceVariant
          : onSurfaceVariant;

  static Color border(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkCardBorder
          : cardBorder;

  static Color brand(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkPrimary
          : primaryContainer;

  static Color brandFixed(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkPrimaryFixed
          : primaryFixed;

  static Color brandOnFixed(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkOnPrimaryFixed
          : onPrimaryFixed;
}

/// Helpful extensions on BuildContext for quick, clean theme-aware styling.
extension TarmeemThemeExtension on BuildContext {
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
  ColorScheme get colorScheme => Theme.of(this).colorScheme;
  Color get scaffoldBackground => Theme.of(this).scaffoldBackgroundColor;
  Color get cardColor => isDarkMode
      ? TarmeemColors.darkSurfaceContainer
      : TarmeemColors.surfaceContainerLowest;
  Color get cardColorLow => isDarkMode
      ? TarmeemColors.darkSurfaceContainerLow
      : TarmeemColors.surfaceContainerLow;
  Color get cardColorHigh => isDarkMode
      ? TarmeemColors.darkSurfaceContainerHigh
      : TarmeemColors.surfaceContainerHigh;
  Color get textColor =>
      isDarkMode ? TarmeemColors.darkOnSurface : TarmeemColors.onSurface;
  Color get textMuted => isDarkMode
      ? TarmeemColors.darkOnSurfaceVariant
      : TarmeemColors.onSurfaceVariant;
  Color get borderColor =>
      isDarkMode ? TarmeemColors.darkCardBorder : TarmeemColors.cardBorder;
  Color get brandColor => isDarkMode
      ? TarmeemColors.darkPrimary
      : TarmeemColors.primaryContainer;
}
