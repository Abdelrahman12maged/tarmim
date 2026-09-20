/// Theme Cubit — manages light/dark/system theme selection.
///
/// Persists the selected mode via shared_preferences.
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_constants.dart';

// ── State ─────────────────────────────────────────────────────────────────

class ThemeState extends Equatable {
  const ThemeState({this.themeMode = ThemeMode.system});
  final ThemeMode themeMode;

  @override
  List<Object?> get props => [themeMode];
}

// ── Cubit ─────────────────────────────────────────────────────────────────

/// Manages the app's theme mode with SharedPreferences persistence.
class ThemeCubit extends Cubit<ThemeState> {
  ThemeCubit() : super(const ThemeState());

  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(AppConstants.prefThemeMode);
    final mode = switch (saved) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    emit(ThemeState(themeMode: mode));
  }

  Future<void> setTheme(ThemeMode mode) async {
    emit(ThemeState(themeMode: mode));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      AppConstants.prefThemeMode,
      switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        _ => 'system',
      },
    );
  }
}
