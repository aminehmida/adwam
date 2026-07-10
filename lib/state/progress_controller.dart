import 'package:flutter/foundation.dart';

import '../data/prefs_store.dart';
import '../models/daily_progress.dart';
import '../models/dhikr.dart';

/// Today's counters and done-marks. Every read/mutation first rolls the
/// blob over to today's date, so an app left open across midnight resets
/// on the next interaction (plus on lifecycle resume, wired in main.dart).
class ProgressController extends ChangeNotifier {
  final PrefsStore _store;
  DailyProgress _progress;

  ProgressController(this._store)
      : _progress = rolloverIfNeeded(_store.loadProgress(), DateTime.now());

  int countFor(SessionType session, String dhikrId) =>
      _progress.countFor(session, dhikrId);

  bool isDone(SessionType session, String dhikrId) =>
      _progress.isDone(session, dhikrId);

  int doneCount(SessionType session, Iterable<String> dhikrIds) =>
      dhikrIds.where((id) => isDone(session, id)).length;

  /// One tap: increment and mark done when the target is reached.
  /// Returns true if this tap completed the dhikr.
  bool increment(SessionType session, Dhikr dhikr) {
    checkDateRollover();
    final key = DailyProgress.keyFor(session, dhikr.id);
    if (_progress.done.contains(key)) return false;
    final next = (_progress.counts[key] ?? 0) + 1;
    final completed = next >= dhikr.repetitions;
    _progress = _progress.copyWith(
      counts: {..._progress.counts, key: next},
      done: completed ? {..._progress.done, key} : null,
    );
    _persistAndNotify();
    return completed;
  }

  void markDone(SessionType session, Dhikr dhikr) {
    checkDateRollover();
    final key = DailyProgress.keyFor(session, dhikr.id);
    if (_progress.done.contains(key)) return;
    _progress = _progress.copyWith(
      counts: {..._progress.counts, key: dhikr.repetitions},
      done: {..._progress.done, key},
    );
    _persistAndNotify();
  }

  void resetToday() {
    _progress = DailyProgress(dateStamp: dateStampOf(DateTime.now()));
    _persistAndNotify();
  }

  /// Called on lifecycle resume and before every mutation.
  void checkDateRollover() {
    final rolled = rolloverIfNeeded(_progress, DateTime.now());
    if (!identical(rolled, _progress)) {
      _progress = rolled;
      _persistAndNotify();
    }
  }

  void _persistAndNotify() {
    _store.saveProgress(_progress);
    notifyListeners();
  }
}
