import 'package:flutter_test/flutter_test.dart';

import 'package:adwam/data/prayer_time_source.dart';
import 'package:adwam/models/prayer.dart';

import 'support/prayer_support.dart';

/// Computed prayer times for real places and dates, locked as **UTC**.
///
/// UTC on purpose: `PrayerTimeSource` converts to local with `toLocal()`, which
/// uses the *test runner's* timezone. Local-time goldens would pass on a laptop
/// in Tunis and fail in CI. UTC instants depend only on coordinates and the
/// calendar date, so they are the same everywhere.
///
/// These are regression locks, not independent verification of the astronomy —
/// adhan_dart is already tested upstream against Meeus. What they catch is a
/// bad row in assets/zones.json, a changed calculation method mapping, or an
/// adhan_dart upgrade shifting results.
///
/// Values are 'fajr dhuhr asr maghrib isha'.
const _golden = <String, String>{
  // Tunisia (MWL-family 18/18) — the author's own timezone.
  'Africa/Tunis|3-20': '03:57 11:27 14:54 17:31 18:58',
  'Africa/Tunis|6-21': '02:08 11:21 15:13 18:42 20:34',
  'Africa/Tunis|9-22': '03:40 11:12 14:38 17:16 18:43',
  'Africa/Tunis|12-21': '04:55 11:17 13:49 16:07 17:40',
  'Africa/Tunis|10-25': '04:09 11:03 14:05 16:30 17:57',

  // Saudi Arabia — Umm al-Qura, where Isha is Maghrib plus a fixed 90 minutes
  // rather than an angle. The asserted values encode that.
  'Asia/Riyadh|3-20': '01:39 09:01 12:27 15:04 16:34',
  'Asia/Riyadh|6-21': '00:33 08:55 12:16 15:45 17:15',
  'Asia/Riyadh|9-22': '01:24 08:46 12:12 14:50 16:20',
  'Asia/Riyadh|12-21': '02:09 08:51 11:50 14:09 15:39',

  // Xinjiang. A user here carries Asia/Shanghai unless they override the zone,
  // which is the single worst representative-city error in the table.
  'Asia/Urumqi|3-20': '22:37 06:18 09:41 12:22 13:53',
  'Asia/Urumqi|6-21': '20:04 06:12 10:18 13:55 16:08',
  'Asia/Urumqi|12-21': '23:56 06:09 08:17 10:35 12:14',

  // Norway — above 48 degrees, so the seventh-of-the-night high-latitude rule
  // applies and summer has no true Fajr or Isha.
  'Europe/Oslo|3-20': '03:38 11:25 14:32 17:31 19:12',
  'Europe/Oslo|6-21': '01:09 11:20 16:01 20:44 21:28',
  'Europe/Oslo|9-22': '03:20 11:11 14:16 17:17 18:58',
  'Europe/Oslo|12-21': '05:43 11:16 12:07 14:12 16:47',
  'Europe/Oslo|10-25': '04:15 11:02 13:03 15:40 17:46',

  // Equatorial and southern hemisphere.
  'Asia/Jakarta|3-20': '21:40 05:01 08:10 11:04 12:13',
  'Asia/Jakarta|6-21': '21:38 04:56 08:17 10:48 12:03',
  'Asia/Jakarta|12-21': '21:11 04:52 08:18 11:05 12:22',

  // North America (ISNA 15/15), including both US DST transition dates — the
  // computed instants must not depend on any DST arithmetic.
  'America/New_York|3-20': '09:44 17:04 20:30 23:08 00:24',
  'America/New_York|6-21': '07:45 16:59 20:58 00:31 02:11',
  'America/New_York|12-21': '10:54 16:55 19:14 21:32 22:54',
  'America/New_York|3-8': '10:04 17:08 20:23 22:55 00:10',
  'America/New_York|11-1': '10:10 16:41 19:28 21:52 23:09',
};

void main() {
  const source = PrayerTimeSource(testZones);

  String? computed(String key) {
    final parts = key.split('|');
    final date = parts[1].split('-').map(int.parse).toList();
    final table = source.timetableFor(
      zoneId: parts[0],
      localDay: DateTime(2026, date[0], date[1]),
    );
    if (table == null) return null;
    return DailyPrayer.values
        .map((p) => table[p].toUtc().toIso8601String().substring(11, 16))
        .join(' ');
  }

  group('golden prayer times', () {
    for (final entry in _golden.entries) {
      test(entry.key, () {
        expect(computed(entry.key), entry.value);
      });
    }
  });

  test('every golden location resolves on every day of the year', () {
    // The feature switches itself off when a timetable won't resolve, so a
    // silent regression here would look like "the selector just stopped
    // appearing" rather than a crash.
    for (final zone in testZones.ids) {
      for (var dayOfYear = 0; dayOfYear < 365; dayOfYear++) {
        final day = DateTime(2026, 1, 1).add(Duration(days: dayOfYear));
        expect(
          source.timetableFor(zoneId: zone, localDay: day),
          isNotNull,
          reason: '$zone on ${day.toIso8601String().substring(0, 10)}',
        );
      }
    }
  });

  test('Umm al-Qura keeps Isha exactly 90 minutes after Maghrib', () {
    final table = source.timetableFor(
      zoneId: 'Asia/Riyadh',
      localDay: DateTime(2026, 6, 21),
    )!;
    expect(
      table[DailyPrayer.isha].difference(table[DailyPrayer.maghrib]),
      const Duration(minutes: 90),
    );
  });

  test('an unknown zone yields no timetable rather than a default location',
      () {
    expect(source.timetableFor(zoneId: 'Mars/Olympus', localDay: DateTime(2026, 6, 21)), isNull);
    expect(source.timetableFor(zoneId: null, localDay: DateTime(2026, 6, 21)), isNull);
  });
}
