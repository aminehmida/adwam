import 'package:flutter/foundation.dart';

import '../data/content_repository.dart';
import '../data/prefs_store.dart';
import '../models/dhikr.dart';
import '../models/user_list_config.dart';

/// The edit-mode section a dhikr belongs to; mirrors the visual bands
/// (see startsSection): benefit tier, plus the full-surah, high-repetition
/// and custom-dua runs, the high-rep one spanning its tiers as one section.
(bool, BenefitTier, bool, bool) _sectionOf(Dhikr d) => d.isHighRep
    ? (true, BenefitTier.none, false, false)
    : (false, d.tier, d.form == DhikrForm.surah, d.isCustom);

/// Per-context order and hidden set, plus the user's own dhikrs,
/// persisted on every change.
class ListConfigController extends ChangeNotifier {
  final PrefsStore _store;
  final ContentRepository _repo;
  final Map<SessionType, UserListConfig> _configs;
  final List<Dhikr> _customs;

  ListConfigController(this._store, this._repo)
      : _configs = {
          for (final s in SessionType.values) s: _store.loadConfig(s),
        },
        _customs = _store.loadCustomDhikrs();

  UserListConfig configFor(SessionType session) => _configs[session]!;

  /// Built-in and custom dhikrs of [session] in default sort order.
  List<Dhikr> _defaultsFor(SessionType session) {
    final customs = _customs.where((d) => d.contexts.contains(session));
    if (customs.isEmpty) return _repo.defaultList(session);
    return [..._repo.defaultList(session), ...customs]..sort(compareDhikrs);
  }

  /// Effective list for a session: user order if set, else default sort.
  /// Hidden dhikrs are included — the UI renders them collapsed in place.
  List<Dhikr> listFor(SessionType session) =>
      applyUserOrder(_defaultsFor(session), configFor(session).order);

  /// Creates a user dua (read once, like any 1x dhikr) and shows it in
  /// every session of [contexts].
  void addCustom({
    required String arabic,
    required Set<SessionType> contexts,
  }) {
    final dhikr = Dhikr(
      id: _newCustomId(),
      arabic: arabic,
      repetitions: 1,
      form: DhikrForm.short,
      tier: BenefitTier.none,
      contexts: contexts,
    );
    _customs.add(dhikr);
    _store.saveCustomDhikrs(_customs);
    for (final s in contexts) {
      _placeInOrder(s, dhikr);
    }
    notifyListeners();
  }

  void updateCustom(
    String id, {
    required String arabic,
    required Set<SessionType> contexts,
  }) {
    final index = _customs.indexWhere((d) => d.id == id);
    if (index == -1) return;
    final old = _customs[index];
    final updated = Dhikr(
      id: id,
      arabic: arabic,
      repetitions: old.repetitions,
      form: old.form,
      tier: old.tier,
      contexts: contexts,
    );
    _customs[index] = updated;
    _store.saveCustomDhikrs(_customs);
    // Place the dua in sessions it is new to. Contexts that were removed
    // need nothing: stale ids in a stored order are simply skipped.
    for (final s in contexts.difference(old.contexts)) {
      _placeInOrder(s, updated);
    }
    notifyListeners();
  }

  void removeCustom(String id) {
    _customs.removeWhere((d) => d.id == id);
    _store.saveCustomDhikrs(_customs);
    for (final s in SessionType.values) {
      final config = configFor(s);
      if (config.order.contains(id) || config.hidden.contains(id)) {
        _update(
          s,
          UserListConfig(
            order: [for (final o in config.order) if (o != id) o],
            hidden: {...config.hidden}..remove(id),
          ),
        );
      }
    }
    notifyListeners();
  }

  String _newCustomId() {
    final base = DateTime.now().millisecondsSinceEpoch;
    var id = '$customIdPrefix$base';
    var n = 1;
    while (_customs.any((d) => d.id == id)) {
      id = '$customIdPrefix$base-${n++}';
    }
    return id;
  }

  /// Inserts [dhikr] into [session]'s stored order at the end of its own
  /// section band, so it stays reachable by the section-confined drag
  /// reorder. A session on the default sort already places it — no-op.
  void _placeInOrder(SessionType session, Dhikr dhikr) {
    final config = configFor(session);
    if (config.order.isEmpty) return;
    final defaults = _defaultsFor(session);
    final without = applyUserOrder(
      [for (final d in defaults) if (d.id != dhikr.id) d],
      [for (final id in config.order) if (id != dhikr.id) id],
    );
    // Sections appear in default order, so a section's rank is the default
    // index of its first member; insert before the first later-section item.
    int rank(Dhikr d) =>
        defaults.indexWhere((x) => _sectionOf(x) == _sectionOf(d));
    final myRank = rank(dhikr);
    var at = without.indexWhere((d) => rank(d) > myRank);
    if (at == -1) at = without.length;
    final ids = [for (final d in without) d.id]..insert(at, dhikr.id);
    _update(session, config.copyWith(order: ids));
  }

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
  /// Movement is confined to the dhikr's own section (see [_sectionOf]): a
  /// drop beyond the section edge snaps to it, so sections stay contiguous
  /// and the session's category bands keep meaning something.
  void reorder(SessionType session, int oldIndex, int newIndex) {
    final list = listFor(session);
    final section = _sectionOf(list[oldIndex]);
    var start = oldIndex;
    while (start > 0 && _sectionOf(list[start - 1]) == section) {
      start--;
    }
    var end = oldIndex;
    while (end < list.length - 1 && _sectionOf(list[end + 1]) == section) {
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
