import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  static const _storageKey = 'app_theme_mode';
  static const _storage = FlutterSecureStorage();

  bool _selectionMade = false;

  @override
  ThemeMode build() {
    unawaited(_restoreSavedThemeMode());
    return ThemeMode.system;
  }

  Future<void> _restoreSavedThemeMode() async {
    try {
      final savedMode = await _storage.read(key: _storageKey);
      if (_selectionMade || savedMode == null) return;

      for (final mode in ThemeMode.values) {
        if (mode.name == savedMode) {
          state = mode;
          return;
        }
      }
    } catch (error) {
      debugPrint('Could not restore theme mode: $error');
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _selectionMade = true;
    state = mode;

    try {
      await _storage.write(key: _storageKey, value: mode.name);
    } catch (error) {
      debugPrint('Could not save theme mode: $error');
    }
  }
}
