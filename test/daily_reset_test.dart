import 'package:flutter_test/flutter_test.dart';

import 'package:adwam/models/daily_progress.dart';
import 'package:adwam/models/dhikr.dart';
import 'package:adwam/state/progress_controller.dart';

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

  group('post-prayer inactivity reset', () {
    final window = ProgressController.inactivityWindow;
    final prayerTime = DateTime(2026, 7, 10, 12);
    // A post-prayer session recited at noon, alongside untouched morning work.
    final afterPrayer = DailyProgress(
      dateStamp: '2026-07-10',
      counts: const {'postPrayer.me-30': 33, 'morning.me-02': 1},
      done: const {'postPrayer.me-30'},
    ).withSessionTouched(SessionType.postPrayer, prayerTime);

    DailyProgress clearIdle(DailyProgress p, DateTime now) => clearIdleSessions(
          p,
          now,
          sessions: const {SessionType.postPrayer},
          window: window,
        );

    test('within the window: kept untouched', () {
      final result = clearIdle(afterPrayer, prayerTime.add(window - const Duration(minutes: 1)));
      expect(result, same(afterPrayer));
    });

    test('past the window: post-prayer cleared, other sessions kept', () {
      final result = clearIdle(afterPrayer, prayerTime.add(window + const Duration(minutes: 1)));
      expect(result.countFor(SessionType.postPrayer, 'me-30'), 0);
      expect(result.isDone(SessionType.postPrayer, 'me-30'), isFalse);
      expect(result.lastTouched.containsKey(SessionType.postPrayer.name), isFalse);
      // The morning session is untouched by a post-prayer expiry.
      expect(result.countFor(SessionType.morning, 'me-02'), 1);
    });

    test('clock set backwards: also resets', () {
      final result = clearIdle(afterPrayer, prayerTime.subtract(const Duration(minutes: 5)));
      expect(result.countFor(SessionType.postPrayer, 'me-30'), 0);
    });

    test('never touched: no-op', () {
      final untouched = DailyProgress(
        dateStamp: '2026-07-10',
        counts: const {'postPrayer.me-30': 33},
      );
      expect(clearIdle(untouched, prayerTime.add(const Duration(hours: 2))),
          same(untouched));
    });

    test('json round-trip preserves last-interaction stamps', () {
      final decoded = DailyProgress.fromJsonString(afterPrayer.toJsonString());
      expect(decoded.lastTouched, afterPrayer.lastTouched);
    });

    test('legacy blob without touched field decodes to empty stamps', () {
      final decoded = DailyProgress.fromJsonString(
          '{"date":"2026-07-10","counts":{},"done":[]}');
      expect(decoded.lastTouched, isEmpty);
    });
  });
}
