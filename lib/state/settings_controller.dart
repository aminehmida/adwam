import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeMode;

import '../data/prefs_store.dart';

/// App-level settings: the locale override (null = follow system), the
/// theme mode, and whether the long-press session-reset confirmation has
/// been muted.
class SettingsController extends ChangeNotifier {
  final PrefsStore _store;
  Locale? _locale;
  ThemeMode _themeMode;
  bool _skipSessionResetConfirm;

  SettingsController(this._store)
      : _locale = _store.loadLocaleOverride(),
        _themeMode = _store.loadThemeMode(),
        _skipSessionResetConfirm = _store.loadSkipSessionResetConfirm();

  Locale? get locale => _locale;

  void setLocale(Locale? locale) {
    _locale = locale;
    _store.saveLocaleOverride(locale);
    notifyListeners();
  }

  ThemeMode get themeMode => _themeMode;

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    _store.saveThemeMode(mode);
    notifyListeners();
  }

  bool get skipSessionResetConfirm => _skipSessionResetConfirm;

  void setSkipSessionResetConfirm(bool value) {
    _skipSessionResetConfirm = value;
    _store.saveSkipSessionResetConfirm(value);
    notifyListeners();
  }
}
