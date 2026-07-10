import 'package:flutter/foundation.dart';

import '../data/content_repository.dart';
import '../data/prefs_store.dart';
import '../models/dhikr.dart';
import '../models/user_list_config.dart';

/// Per-context order and hidden set, persisted on every change.
class ListConfigController extends ChangeNotifier {
  final PrefsStore _store;
  final ContentRepository _repo;
  final Map<SessionType, UserListConfig> _configs;

  ListConfigController(this._store, this._repo)
      : _configs = {
          for (final s in SessionType.values) s: _store.loadConfig(s),
        };

  UserListConfig configFor(SessionType session) => _configs[session]!;

  /// Effective list for a session: user order if set, else default sort.
  /// Hidden dhikrs are included — the UI renders them collapsed in place.
  List<Dhikr> listFor(SessionType session) =>
      _repo.orderedList(session, configFor(session).order);

  /// Visible (non-hidden) ids, for progress badges.
  List<String> visibleIds(SessionType session) {
    final hidden = configFor(session).hidden;
    return [
      for (final d in listFor(session))
        if (!hidden.contains(d.id)) d.id,
    ];
  }

  bool isHidden(SessionType session, String dhikrId) =>
      configFor(session).hidden.contains(dhikrId);

  void setHidden(SessionType session, String dhikrId, bool hidden) {
    final config = configFor(session);
    final newHidden = {...config.hidden};
    if (hidden) {
      newHidden.add(dhikrId);
    } else {
      newHidden.remove(dhikrId);
    }
    _update(session, config.copyWith(hidden: newHidden));
  }

  /// [newIndex] is the position after removal (ReorderableListView's
  /// onReorderItem convention — already adjusted).
  ///
  /// Movement is confined to the dhikr's own benefit-tier section: a drop
  /// beyond the section edge snaps to it, so tiers stay contiguous and the
  /// session's category bands keep meaning something.
  void reorder(SessionType session, int oldIndex, int newIndex) {
    final list = listFor(session);
    final tier = list[oldIndex].tier;
    var start = oldIndex;
    while (start > 0 && list[start - 1].tier == tier) {
      start--;
    }
    var end = oldIndex;
    while (end < list.length - 1 && list[end + 1].tier == tier) {
      end++;
    }
    final ids = list.map((d) => d.id).toList();
    final id = ids.removeAt(oldIndex);
    ids.insert(newIndex.clamp(start, end), id);
    _update(session, configFor(session).copyWith(order: ids));
  }

  void resetToDefault(SessionType session) {
    _update(session, const UserListConfig());
  }

  void resetAll() {
    for (final s in SessionType.values) {
      _configs[s] = const UserListConfig();
    }
    _store.clearAllConfigs();
    notifyListeners();
  }

  void _update(SessionType session, UserListConfig config) {
    _configs[session] = config;
    _store.saveConfig(session, config);
    notifyListeners();
  }
}
