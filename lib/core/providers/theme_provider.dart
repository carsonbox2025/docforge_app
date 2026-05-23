import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../storage/local_cache.dart';

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.system) {
    _loadSaved();
  }

  static const _cacheKey = 'app_theme_mode';

  Future<void> _loadSaved() async {
    try {
      final saved = await LocalCache.instance.get(_cacheKey);
      if (saved != null && mounted) {
        state = _fromString(saved);
      }
    } catch (_) {}
  }

  Future<void> setMode(ThemeMode mode) async {
    if (!mounted) return;
    state = mode;
    try {
      await LocalCache.instance.set(_cacheKey, mode.name);
    } catch (_) {}
  }

  void toggle() {
    if (state == ThemeMode.dark) {
      setMode(ThemeMode.light);
    } else {
      setMode(ThemeMode.dark);
    }
  }

  ThemeMode _fromString(String value) {
    switch (value) {
      case 'dark':
        return ThemeMode.dark;
      case 'light':
        return ThemeMode.light;
      default:
        return ThemeMode.system;
    }
  }
}
