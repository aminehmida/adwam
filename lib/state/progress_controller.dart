import 'package:flutter/foundation.dart';

import '../data/prefs_store.dart';
import '../models/daily_progress.dart';
import '../models/dhikr.dart';

/// Today's counters and done-marks. Every read/mutation first refreshes the
/// blob (see [refresh]), so an app left open across midnight resets on the
/// next interaction (plus on lifecycle resume, wired in main.dart).
class ProgressController extends ChangeNotifier {
  /// Post-prayer adhkar are recited after each of the five daily prayers, so
  /// they must not carry one prayer's progress into the next. If the session
  /// sees no interaction for this long, it is cleared and ready for the next
  /// prayer.
  static const inactivityWindow = Duration(minutes: 15);
  static const _inactivitySessions = {SessionType.postPrayer};

  final PrefsStore _store;
  DailyProgress _progress;

  ProgressController(this._store)
      : _progress = clearIdleSessions(
          rolloverIfNeeded(_store.loadProgress(), DateTime.now()),
          DateTime.now(),
          sessions: _inactivitySessions,
          window: inactivityWindow,
        );

  int countFor(SessionType session, String dhikrId) =>
      _progress.countFor(session, dhikrId);

  bool isDone(SessionType session, String dhikrId) =>
      _progress.isDone(session, dhikrId);

  int doneCount(SessionType session, Iterable<String> dhikrIds) =>
      dhikrIds.where((id) => isDone(session, id)).length;

  /// One tap: increment and mark done when the target is reached.
  /// Returns true if this tap completed the dhikr.
  bool increment(SessionType session, Dhikr dhikr) {
    refresh();
    final key = DailyProgress.keyFor(session, dhikr.id);
    if (_progress.done.contains(key)) return false;
    final next = (_progress.counts[key] ?? 0) + 1;
    final completed = next >= dhikr.repetitions;
    _progress = _touch(session, _progress.copyWith(
      counts: {..._progress.counts, key: next},
      done: completed ? {..._progress.done, key} : null,
    ));
    _persistAndNotify();
    return completed;
  }

  void markDone(SessionType session, Dhikr dhikr) {
    refresh();
    final key = DailyProgress.keyFor(session, dhikr.id);
    if (_progress.done.contains(key)) return;
    _progress = _touch(session, _progress.copyWith(
      counts: {..._progress.counts, key: dhikr.repetitions},
      done: {..._progress.done, key},
    ));
    _persistAndNotify();
  }

  /// Clears today's count and done-mark for a single dhikr, so it can be
  /// recited again (long-press on a finished card).
  void resetDhikr(SessionType session, String dhikrId) {
    refresh();
    final key = DailyProgress.keyFor(session, dhikrId);
    if (!_progress.counts.containsKey(key) && !_progress.done.contains(key)) {
      return;
    }
    _progress = _touch(session, _progress.copyWith(
      counts: {..._progress.counts}..remove(key),
      done: _progress.done.where((k) => k != key).toSet(),
    ));
    _persistAndNotify();
  }

  /// Clears today's counters and done-marks for one session only.
  void resetSession(SessionType session) {
    refresh();
    _progress = _progress.withSessionCleared(session);
    _persistAndNotify();
  }

  void resetToday() {
    _progress = DailyProgress(dateStamp: dateStampOf(DateTime.now()));
    _persistAndNotify();
  }

  /// Stamps [session] as just interacted with, but only for sessions that
  /// expire on inactivity — others never carry a timestamp.
  DailyProgress _touch(SessionType session, DailyProgress progress) =>
      _inactivitySessions.contains(session)
          ? progress.withSessionTouched(session, DateTime.now())
          : progress;

  /// Rolls the blob over to today and clears any session idle past
  /// [inactivityWindow]. Called on lifecycle resume and before every mutation.
  void refresh() {
    final now = DateTime.now();
    var updated = rolloverIfNeeded(_progress, now);
    updated = clearIdleSessions(
      updated,
      now,
      sessions: _inactivitySessions,
      window: inactivityWindow,
    );
    if (!identical(updated, _progress)) {
      _progress = updated;
      _persistAndNotify();
    }
  }

  void _persistAndNotify() {
    _store.saveProgress(_progress);
    notifyListeners();
  }
}
