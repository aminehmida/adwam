import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeMode;

import '../data/prefs_store.dart';

/// App-level settings: the locale override (null = follow system), the
/// theme mode, whether the long-press session-reset confirmation has been
/// muted, whether the volume-down key counts the current dhikr (Android),
/// the focus-overlay background variant, and whether the translation /
/// transliteration texts show on cards (non-Arabic UIs only).
class SettingsController extends ChangeNotifier {
  final PrefsStore _store;
  Locale? _locale;
  ThemeMode _themeMode;
  bool _skipSessionResetConfirm;
  bool _volumeKeyCounting;
  int _focusBgVariant;
  bool _showTranslation;
  bool _showTransliteration;
  double _quranFontSize;

  SettingsController(this._store)
      : _locale = _store.loadLocaleOverride(),
        _themeMode = _store.loadThemeMode(),
        _skipSessionResetConfirm = _store.loadSkipSessionResetConfirm(),
        _volumeKeyCounting = _store.loadVolumeKeyCounting(),
        _focusBgVariant = _store.loadFocusBgVariant(),
        _showTranslation = _store.loadShowTranslation(),
        _showTransliteration = _store.loadShowTransliteration(),
        _quranFontSize = _store.loadQuranFontSize();

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

  bool get volumeKeyCounting => _volumeKeyCounting;

  void setVolumeKeyCounting(bool value) {
    _volumeKeyCounting = value;
    _store.saveVolumeKeyCounting(value);
    notifyListeners();
  }

  bool get showTranslation => _showTranslation;

  void setShowTranslation(bool value) {
    _showTranslation = value;
    _store.saveShowTranslation(value);
    notifyListeners();
  }

  bool get showTransliteration => _showTransliteration;

  void setShowTransliteration(bool value) {
    _showTransliteration = value;
    _store.saveShowTransliteration(value);
    notifyListeners();
  }

  /// 0 = blur only, 1 = blur + vignette, 2 = blur + geometric pattern.
  int get focusBgVariant => _focusBgVariant;

  void setFocusBgVariant(int variant) {
    _focusBgVariant = variant;
    _store.saveFocusBgVariant(variant);
    notifyListeners();
  }

  /// Body text size of the surah reader's Quran text.
  double get quranFontSize => _quranFontSize;

  void setQuranFontSize(double size) {
    _quranFontSize = size;
    _store.saveQuranFontSize(size);
    notifyListeners();
  }
}
