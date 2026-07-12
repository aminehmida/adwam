import 'dart:ui';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/daily_progress.dart';
import '../models/dhikr.dart';
import '../models/user_list_config.dart';

/// Thin JSON-string wrapper over shared_preferences.
class PrefsStore {
  final SharedPreferences _prefs;

  PrefsStore(this._prefs);

  static Future<PrefsStore> open() async =>
      PrefsStore(await SharedPreferences.getInstance());

  static String _configKey(SessionType session) => 'config.${session.name}';

  UserListConfig loadConfig(SessionType session) {
    final raw = _prefs.getString(_configKey(session));
    return raw == null
        ? const UserListConfig()
        : UserListConfig.fromJsonString(raw);
  }

  Future<void> saveConfig(SessionType session, UserListConfig config) =>
      _prefs.setString(_configKey(session), config.toJsonString());

  DailyProgress? loadProgress() {
    final raw = _prefs.getString('progress');
    return raw == null ? null : DailyProgress.fromJsonString(raw);
  }

  Future<void> saveProgress(DailyProgress progress) =>
      _prefs.setString('progress', progress.toJsonString());

  Locale? loadLocaleOverride() {
    final code = _prefs.getString('locale');
    return code == null ? null : Locale(code);
  }

  Future<void> saveLocaleOverride(Locale? locale) => locale == null
      ? _prefs.remove('locale')
      : _prefs.setString('locale', locale.languageCode);

  bool loadSkipSessionResetConfirm() =>
      _prefs.getBool('skipSessionResetConfirm') ?? false;

  Future<void> saveSkipSessionResetConfirm(bool value) =>
      _prefs.setBool('skipSessionResetConfirm', value);

  Future<void> clearAllConfigs() async {
    for (final s in SessionType.values) {
      await _prefs.remove(_configKey(s));
    }
  }
}
