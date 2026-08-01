import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:adwam/data/prayer_classifier.dart';
import 'package:adwam/data/prayer_time_source.dart';
import 'package:adwam/data/zone_coordinates.dart';
import 'package:adwam/models/prayer.dart';
import 'package:adwam/models/prayer_timetable.dart';

/// Invariant tests over generated inputs.
///
/// Seeds are fixed, never `Random()` — a test that fails one run in fifty is
/// worse than no test. Latitudes sweep the whole globe including the poles,
/// where the astronomy legitimately gives up; the contract there is "return
/// null", never "throw" and never "return nonsense".
const _seeds = [1, 7, 42, 1337];
const _casesPerSeed = 120;

ZoneDirectory _zoneAt(double lat, double lng) =>
    ZoneDirectory({'test/zone': ZoneLocation(lat, lng, 'XX')});

void main() {
  test('a timetable is either absent or strictly ordered', () {
    for (final seed in _seeds) {
      final random = Random(seed);
      for (var i = 0; i < _casesPerSeed; i++) {
        final lat = random.nextDouble() * 180 - 90;
        final lng = random.nextDouble() * 360 - 180;
        final day = DateTime(2026, 1, 1).add(
          Duration(days: random.nextInt(365)),
        );
        final table = PrayerTimeSource(_zoneAt(lat, lng))
            .timetableFor(zoneId: 'test/zone', localDay: day);
        if (table == null) continue;
        final schedule = table.schedule;
        for (var s = 1; s < schedule.length; s++) {
          expect(
            schedule[s].at.isAfter(schedule[s - 1].at),
            isTrue,
            reason: 'lat=$lat lng=$lng day=$day: '
                '${schedule[s]} must follow ${schedule[s - 1]}',
          );
        }
      }
    }
  });

  test('classification never throws and only declines before the first entry',
      () {
    for (final seed in _seeds) {
      final random = Random(seed);
      for (var i = 0; i < _casesPerSeed; i++) {
        final lat = random.nextDouble() * 180 - 90;
        final lng = random.nextDouble() * 360 - 180;
        final day = DateTime(2026, 1, 1).add(
          Duration(days: random.nextInt(365)),
        );
        final table = PrayerTimeSource(_zoneAt(lat, lng))
            .timetableFor(zoneId: 'test/zone', localDay: day);
        if (table == null) continue;
        for (var minute = 0; minute < 24 * 60; minute += 17) {
          final now = DateTime(day.year, day.month, day.day)
              .add(Duration(minutes: minute));
          final guess = classifyPrayer(timetable: table, now: now);
          if (guess == null) {
            expect(now.isBefore(table.schedule.first.at), isTrue,
                reason: 'lat=$lat lng=$lng $now returned null mid-day');
            continue;
          }
          expect(DailyPrayer.values.contains(guess.prayer), isTrue);
        }
      }
    }
  });

  test('the guessed prayer never moves backwards as the day advances', () {
    for (final seed in _seeds) {
      final random = Random(seed);
      for (var i = 0; i < _casesPerSeed; i++) {
        // Habitable latitudes: beyond these the "day" stops having a normal
        // prayer sequence and ordering by prayer index is not meaningful.
        final lat = random.nextDouble() * 120 - 60;
        final lng = random.nextDouble() * 360 - 180;
        final day = DateTime(2026, 1, 1).add(
          Duration(days: random.nextInt(365)),
        );
        final table = PrayerTimeSource(_zoneAt(lat, lng))
            .timetableFor(zoneId: 'test/zone', localDay: day);
        if (table == null) continue;

        // Walk from Fajr to the end of the day; before Fajr the answer is
        // yesterday's Isha, which is deliberately a higher index.
        var previous = -1;
        var cursor = table[DailyPrayer.fajr];
        final end = table[DailyPrayer.isha].add(const Duration(hours: 2));
        while (cursor.isBefore(end)) {
          final guess = classifyPrayer(timetable: table, now: cursor);
          expect(guess, isNotNull);
          expect(
            guess!.prayer.index >= previous,
            isTrue,
            reason: 'lat=$lat lng=$lng at $cursor went backwards to '
                '${guess.prayer} from index $previous',
          );
          previous = guess.prayer.index;
          cursor = cursor.add(const Duration(minutes: 13));
        }
      }
    }
  });

  test('any combination of offsets still yields a strictly ordered schedule',
      () {
    final table = PrayerTimetable(
      times: {
        DailyPrayer.fajr: DateTime(2026, 3, 15, 5),
        DailyPrayer.dhuhr: DateTime(2026, 3, 15, 12, 30),
        DailyPrayer.asr: DateTime(2026, 3, 15, 15, 45),
        DailyPrayer.maghrib: DateTime(2026, 3, 15, 18, 20),
        DailyPrayer.isha: DateTime(2026, 3, 15, 19, 50),
      },
      ishaBefore: DateTime(2026, 3, 14, 19, 50),
    );
    for (final seed in _seeds) {
      final random = Random(seed);
      for (var i = 0; i < _casesPerSeed * 4; i++) {
        final offsets = {
          for (final p in DailyPrayer.values)
            // Deliberately wider than the +/-90min the learner will ever
            // produce, so clamping is exercised well past its real range.
            p: Duration(minutes: random.nextInt(1200) - 600),
        };
        final schedule = table.adjustedSchedule(offsets);
        expect(schedule.length, 6);
        for (var s = 1; s < schedule.length; s++) {
          expect(
            schedule[s].at.isAfter(schedule[s - 1].at),
            isTrue,
            reason: 'offsets=$offsets produced ${schedule[s]} '
                'after ${schedule[s - 1]}',
          );
        }
        // Clamping may move times, but never reorders the prayers themselves.
        expect(schedule.map((e) => e.prayer).toList(), [
          DailyPrayer.isha,
          ...DailyPrayer.values,
        ]);
      }
    }
  });
}
