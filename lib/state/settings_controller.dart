import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../data/prefs_store.dart';

/// App-level settings: the locale override (null = follow system) and the
/// focus-overlay background variant.
class SettingsController extends ChangeNotifier {
  final PrefsStore _store;
  Locale? _locale;
  int _focusBgVariant;

  SettingsController(this._store)
      : _locale = _store.loadLocaleOverride(),
        _focusBgVariant = _store.loadFocusBgVariant();

  Locale? get locale => _locale;

  void setLocale(Locale? locale) {
    _locale = locale;
    _store.saveLocaleOverride(locale);
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
