import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeMode;

import '../data/prefs_store.dart';

/// App-level settings: the locale override (null = follow system), the
/// theme mode, whether the long-press session-reset confirmation has been
/// muted, and the focus-overlay background variant.
class SettingsController extends ChangeNotifier {
  final PrefsStore _store;
  Locale? _locale;
  ThemeMode _themeMode;
  bool _skipSessionResetConfirm;
  int _focusBgVariant;

  SettingsController(this._store)
      : _locale = _store.loadLocaleOverride(),
        _themeMode = _store.loadThemeMode(),
        _skipSessionResetConfirm = _store.loadSkipSessionResetConfirm(),
        _focusBgVariant = _store.loadFocusBgVariant();

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

  /// 0 = blur only, 1 = blur + vignette, 2 = blur + geometric pattern.
  int get focusBgVariant => _focusBgVariant;

  void setFocusBgVariant(int variant) {
    _focusBgVariant = variant;
    _store.saveFocusBgVariant(variant);
    notifyListeners();
  }
}
