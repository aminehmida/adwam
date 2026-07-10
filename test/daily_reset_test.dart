import 'package:flutter_test/flutter_test.dart';

import 'package:dhikr/models/daily_progress.dart';
import 'package:dhikr/models/dhikr.dart';

void main() {
  final noon = DateTime(2026, 7, 10, 12);
  final sameDayProgress = DailyProgress(
    dateStamp: '2026-07-10',
    counts: const {'morning.me-02': 1},
    done: const {'morning.me-02'},
  );

  test('same day: progress kept', () {
    expect(rolloverIfNeeded(sameDayProgress, noon), same(sameDayProgress));
  });

  test('next day: progress reset', () {
    final rolled = rolloverIfNeeded(sameDayProgress, DateTime(2026, 7, 11, 0, 1));
    expect(rolled.dateStamp, '2026-07-11');
    expect(rolled.counts, isEmpty);
    expect(rolled.done, isEmpty);
  });

  test('clock set backwards: also resets (inequality, not ordering)', () {
    final rolled = rolloverIfNeeded(sameDayProgress, DateTime(2026, 7, 9, 23));
    expect(rolled.dateStamp, '2026-07-09');
    expect(rolled.counts, isEmpty);
  });

  test('no stored progress: fresh for today', () {
    final fresh = rolloverIfNeeded(null, noon);
    expect(fresh.dateStamp, '2026-07-10');
    expect(fresh.counts, isEmpty);
  });

  test('json round-trip preserves counts, done set, and date', () {
    final decoded =
        DailyProgress.fromJsonString(sameDayProgress.toJsonString());
    expect(decoded.dateStamp, sameDayProgress.dateStamp);
    expect(decoded.counts, sameDayProgress.counts);
    expect(decoded.done, sameDayProgress.done);
    expect(decoded.isDone(SessionType.morning, 'me-02'), isTrue);
  });
}
