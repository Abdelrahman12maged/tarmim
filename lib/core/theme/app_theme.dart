// Tarmeem App Theme — light and dark ThemeData implementations
// Sourced from color_tokens.dart for unified, modern aesthetics.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'color_tokens.dart';
import 'text_theme.dart';

/// Provides light and dark [ThemeData] for the Tarmeem app.
abstract class TarmeemTheme {
  // ── Light Theme ──────────────────────────────────────────────────────────
  static ThemeData get light {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: TarmeemColors.primaryContainer, // #134E4A — brand teal
      onPrimary: TarmeemColors.onPrimary,
      primaryContainer: TarmeemColors.primaryFixed,
      onPrimaryContainer: TarmeemColors.onPrimaryFixed,
      secondary: TarmeemColors.secondary,
      onSecondary: TarmeemColors.onSecondary,
      secondaryContainer: TarmeemColors.secondaryContainer,
      onSecondaryContainer: TarmeemColors.onSecondaryContainer,
      tertiary: TarmeemColors.tertiary,
      onTertiary: TarmeemColors.onTertiary,
      tertiaryContainer: TarmeemColors.tertiaryContainer,
      onTertiaryContainer: TarmeemColors.onTertiaryContainer,
      error: TarmeemColors.error,
      onError: TarmeemColors.onError,
      errorContainer: TarmeemColors.errorContainer,
      onErrorContainer: TarmeemColors.onErrorContainer,
      surface: TarmeemColors.surface,
      onSurface: TarmeemColors.onSurface,
      onSurfaceVariant: TarmeemColors.onSurfaceVariant,
      outline: TarmeemColors.outline,
      outlineVariant: TarmeemColors.outlineVariant,
      inverseSurface: TarmeemColors.inverseSurface,
      onInverseSurface: TarmeemColors.inverseOnSurface,
      inversePrimary: TarmeemColors.inversePrimary,
      surfaceTint: TarmeemColors.surfaceTint,
      scrim: Colors.black,
      shadow: Colors.black,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: TarmeemColors.surface,
      textTheme: buildTarmeemTextTheme(color: TarmeemColors.onSurface),
      appBarTheme: AppBarTheme(
        backgroundColor: TarmeemColors.surface,
        foregroundColor: TarmeemColors.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: buildTarmeemTextTheme(color: TarmeemColors.onSurface)
            .headlineSmall,
        shape: const Border(
          bottom: BorderSide(
            color: TarmeemColors.surfaceContainerHigh,
            width: 1,
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: TarmeemColors.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: TarmeemColors.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: TarmeemColors.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      cardTheme: CardThemeData(
        color: TarmeemColors.surfaceContainerLowest,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: TarmeemColors.cardBorder, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: TarmeemColors.surfaceContainerLowest,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Color(0xFFE5E7EB),
            width: 1.5,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Color(0xFFE5E7EB),
            width: 1.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: TarmeemColors.secondary,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: TarmeemColors.error,
            width: 1.5,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: TarmeemColors.primaryContainer,
          foregroundColor: TarmeemColors.onPrimary,
          minimumSize: const Size(64, 50),
          shape: const StadiumBorder(),
          elevation: 0,
          textStyle: buildTarmeemTextTheme().labelLarge?.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: TarmeemColors.primaryContainer,
          minimumSize: const Size(64, 50),
          shape: const StadiumBorder(),
          side: const BorderSide(
            color: TarmeemColors.primaryContainer,
            width: 1.5,
          ),
          textStyle: buildTarmeemTextTheme().labelLarge?.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: TarmeemColors.primaryContainer,
        foregroundColor: TarmeemColors.onPrimary,
        elevation: 4,
        shape: StadiumBorder(),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: TarmeemColors.surfaceContainerLowest,
        selectedItemColor: TarmeemColors.primaryContainer,
        unselectedItemColor: TarmeemColors.outline,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: TarmeemColors.surfaceContainerLowest,
        selectedColor: TarmeemColors.primaryContainer,
        labelStyle: buildTarmeemTextTheme().labelMedium,
        shape: const StadiumBorder(),
        side: const BorderSide(color: TarmeemColors.outlineVariant),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
      dividerTheme: const DividerThemeData(
        color: TarmeemColors.surfaceContainerHigh,
        thickness: 1,
        space: 0,
      ),
    );
  }

  // ── Dark Theme ───────────────────────────────────────────────────────────
  static ThemeData get dark {
    const colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: TarmeemColors.darkPrimary,
      onPrimary: TarmeemColors.darkOnPrimary,
      primaryContainer: TarmeemColors.darkPrimaryContainer,
      onPrimaryContainer: TarmeemColors.darkOnPrimaryContainer,
      secondary: TarmeemColors.darkSecondary,
      onSecondary: TarmeemColors.darkOnSecondary,
      secondaryContainer: TarmeemColors.darkSecondaryContainer,
      onSecondaryContainer: TarmeemColors.darkOnSecondaryContainer,
      tertiary: Color(0xFFFFB77D),
      onTertiary: Color(0xFF4A1C00),
      tertiaryContainer: Color(0xFF6A3500),
      onTertiaryContainer: Color(0xFFFFDCC3),
      error: Color(0xFFFFB4AB),
      onError: Color(0xFF690005),
      errorContainer: Color(0xFF93000A),
      onErrorContainer: Color(0xFFFFDAD6),
      surface: TarmeemColors.darkSurface,
      onSurface: TarmeemColors.darkOnSurface,
      onSurfaceVariant: TarmeemColors.darkOnSurfaceVariant,
      outline: TarmeemColors.darkOutline,
      outlineVariant: TarmeemColors.darkOutlineVariant,
      inverseSurface: Color(0xFFE2E3DF),
      onInverseSurface: Color(0xFF2F312F),
      inversePrimary: TarmeemColors.primaryContainer,
      surfaceTint: TarmeemColors.darkPrimary,
      scrim: Colors.black,
      shadow: Colors.black,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: TarmeemColors.darkBackground,
      textTheme: buildTarmeemTextTheme(color: TarmeemColors.darkOnSurface),
      appBarTheme: AppBarTheme(
        backgroundColor: TarmeemColors.darkSurface,
        foregroundColor: TarmeemColors.darkOnSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: buildTarmeemTextTheme(color: TarmeemColors.darkOnSurface)
            .headlineSmall,
        shape: const Border(
          bottom: BorderSide(
            color: TarmeemColors.darkOutlineVariant,
            width: 0.8,
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: TarmeemColors.darkSurfaceContainer,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: TarmeemColors.darkSurfaceContainer,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: TarmeemColors.darkSurfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      cardTheme: CardThemeData(
        color: TarmeemColors.darkSurfaceContainerLowest,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: TarmeemColors.darkCardBorder, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: TarmeemColors.darkSurfaceContainerLow,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: TarmeemColors.darkOutlineVariant, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: TarmeemColors.darkOutlineVariant, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: TarmeemColors.darkPrimary,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide:
              const BorderSide(color: Color(0xFFFFB4AB), width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: TarmeemColors.darkPrimaryContainer,
          foregroundColor: Colors.white,
          minimumSize: const Size(64, 50),
          shape: const StadiumBorder(),
          elevation: 0,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: TarmeemColors.darkPrimary,
        foregroundColor: TarmeemColors.darkOnPrimary,
        elevation: 4,
        shape: StadiumBorder(),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: TarmeemColors.darkSurfaceContainer,
        selectedItemColor: TarmeemColors.darkPrimary,
        unselectedItemColor: TarmeemColors.darkOutline,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      dividerTheme: const DividerThemeData(
        color: TarmeemColors.darkOutlineVariant,
        thickness: 0.8,
        space: 0,
      ),
    );
  }
}
