import 'dart:convert';

import 'dhikr.dart';

String dateStampOf(DateTime now) =>
    '${now.year.toString().padLeft(4, '0')}-'
    '${now.month.toString().padLeft(2, '0')}-'
    '${now.day.toString().padLeft(2, '0')}';

/// Today's counters and done-marks. Keys are `<session>.<dhikrId>` so the same
/// dhikr counts separately in each context it appears in.
class DailyProgress {
  final String dateStamp;
  final Map<String, int> counts;
  final Set<String> done;

  /// Epoch-millis of the last interaction with a session, keyed by
  /// [SessionType.name]. Only sessions that expire on inactivity record this
  /// (post-prayer), so it is empty for everything else.
  final Map<String, int> lastTouched;

  const DailyProgress({
    required this.dateStamp,
    this.counts = const {},
    this.done = const {},
    this.lastTouched = const {},
  });

  static String keyFor(SessionType session, String dhikrId) =>
      '${session.name}.$dhikrId';

  int countFor(SessionType session, String dhikrId) =>
      counts[keyFor(session, dhikrId)] ?? 0;

  bool isDone(SessionType session, String dhikrId) =>
      done.contains(keyFor(session, dhikrId));

  DailyProgress copyWith({
    Map<String, int>? counts,
    Set<String>? done,
    Map<String, int>? lastTouched,
  }) =>
      DailyProgress(
        dateStamp: dateStamp,
        counts: counts ?? this.counts,
        done: done ?? this.done,
        lastTouched: lastTouched ?? this.lastTouched,
      );

  /// Records [now] as the last interaction with [session].
  DailyProgress withSessionTouched(SessionType session, DateTime now) =>
      copyWith(lastTouched: {
        ...lastTouched,
        session.name: now.millisecondsSinceEpoch,
      });

  /// Clears all counts, done-marks and the last-interaction stamp for one
  /// session, leaving the other sessions untouched.
  DailyProgress withSessionCleared(SessionType session) {
    final prefix = '${session.name}.';
    return copyWith(
      counts: {
        for (final entry in counts.entries)
          if (!entry.key.startsWith(prefix)) entry.key: entry.value,
      },
      done: done.where((key) => !key.startsWith(prefix)).toSet(),
      lastTouched: {...lastTouched}..remove(session.name),
    );
  }

  String toJsonString() => jsonEncode({
        'date': dateStamp,
        'counts': counts,
        'done': done.toList(),
        'touched': lastTouched,
      });

  factory DailyProgress.fromJsonString(String source) {
    final json = jsonDecode(source) as Map<String, dynamic>;
    return DailyProgress(
      dateStamp: json['date'] as String,
      counts: (json['counts'] as Map<String, dynamic>).cast<String, int>(),
      done: (json['done'] as List).cast<String>().toSet(),
      lastTouched:
          (json['touched'] as Map<String, dynamic>?)?.cast<String, int>() ??
              const {},
    );
  }
}

/// Returns [progress] unchanged if it is for today, otherwise a fresh
/// empty progress for today. Inequality (not ordering) so a clock set
/// backwards also resets instead of keeping a future-dated blob forever.
DailyProgress rolloverIfNeeded(DailyProgress? progress, DateTime now) {
  final today = dateStampOf(now);
  if (progress == null || progress.dateStamp != today) {
    return DailyProgress(dateStamp: today);
  }
  return progress;
}

/// Clears any session in [sessions] that has not been touched within [window],
/// so it starts fresh next time. Post-prayer adhkar use this to be ready for
/// the next prayer once the current one's window has lapsed. A backwards clock
/// (negative idle) also resets, matching [rolloverIfNeeded]. Returns the same
/// instance when nothing expired.
DailyProgress clearIdleSessions(
  DailyProgress progress,
  DateTime now, {
  required Set<SessionType> sessions,
  required Duration window,
}) {
  var result = progress;
  for (final session in sessions) {
    final touchedMs = result.lastTouched[session.name];
    if (touchedMs == null) continue;
    final idleMs = now.millisecondsSinceEpoch - touchedMs;
    if (idleMs >= 0 && idleMs < window.inMilliseconds) continue;
    result = result.withSessionCleared(session);
  }
  return result;
}
