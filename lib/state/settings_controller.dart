import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../data/prefs_store.dart';

/// App-level settings. Currently just the locale override
/// (null = follow system).
class SettingsController extends ChangeNotifier {
  final PrefsStore _store;
  Locale? _locale;

  SettingsController(this._store) : _locale = _store.loadLocaleOverride();

  Locale? get locale => _locale;

  void setLocale(Locale? locale) {
    _locale = locale;
    _store.saveLocaleOverride(locale);
    notifyListeners();
  }
}
