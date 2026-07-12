import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../data/prefs_store.dart';

/// App-level settings: the locale override (null = follow system) and
/// whether the long-press session-reset confirmation has been muted.
class SettingsController extends ChangeNotifier {
  final PrefsStore _store;
  Locale? _locale;
  bool _skipSessionResetConfirm;

  SettingsController(this._store)
      : _locale = _store.loadLocaleOverride(),
        _skipSessionResetConfirm = _store.loadSkipSessionResetConfirm();

  Locale? get locale => _locale;

  void setLocale(Locale? locale) {
    _locale = locale;
    _store.saveLocaleOverride(locale);
    notifyListeners();
  }

  bool get skipSessionResetConfirm => _skipSessionResetConfirm;

  void setSkipSessionResetConfirm(bool value) {
    _skipSessionResetConfirm = value;
    _store.saveSkipSessionResetConfirm(value);
    notifyListeners();
  }
}
