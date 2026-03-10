import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kThemeKey = 'astro_theme_mode';

/// Provider que expone la instancia de SharedPreferences
/// inicializada en main() vía override.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (_) => throw UnimplementedError(
    'sharedPreferencesProvider debe ser sobreescrito en ProviderScope',
  ),
);

/// Notifier para el modo de tema actual.
/// Dark mode por defecto (según especificación ASTRO).
/// Persiste la elección en SharedPreferences.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final prefs = ref.read(sharedPreferencesProvider);
    final value = prefs.getString(_kThemeKey);
    return value == 'light' ? ThemeMode.light : ThemeMode.dark;
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(
      _kThemeKey,
      mode == ThemeMode.light ? 'light' : 'dark',
    );
  }

  Future<void> toggle() async {
    final newMode = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    await setThemeMode(newMode);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);
