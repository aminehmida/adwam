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

  const DailyProgress({
    required this.dateStamp,
    this.counts = const {},
    this.done = const {},
  });

  static String keyFor(SessionType session, String dhikrId) =>
      '${session.name}.$dhikrId';

  int countFor(SessionType session, String dhikrId) =>
      counts[keyFor(session, dhikrId)] ?? 0;

  bool isDone(SessionType session, String dhikrId) =>
      done.contains(keyFor(session, dhikrId));

  DailyProgress copyWith({Map<String, int>? counts, Set<String>? done}) =>
      DailyProgress(
        dateStamp: dateStamp,
        counts: counts ?? this.counts,
        done: done ?? this.done,
      );

  String toJsonString() =>
      jsonEncode({'date': dateStamp, 'counts': counts, 'done': done.toList()});

  factory DailyProgress.fromJsonString(String source) {
    final json = jsonDecode(source) as Map<String, dynamic>;
    return DailyProgress(
      dateStamp: json['date'] as String,
      counts: (json['counts'] as Map<String, dynamic>).cast<String, int>(),
      done: (json['done'] as List).cast<String>().toSet(),
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
