import 'package:adwam/data/prayer_time_source.dart';
import 'package:adwam/data/prefs_store.dart';
import 'package:adwam/data/zone_coordinates.dart';
import 'package:adwam/models/prayer.dart';
import 'package:adwam/models/prayer_timetable.dart';
import 'package:adwam/state/prayer_controller.dart';
import 'package:adwam/state/progress_controller.dart';

/// A PrayerController that never resolves a location, so `active` is null and
/// nothing is filtered. Use in tests that aren't about the prayer guess: it
/// reproduces the app's behaviour on a device whose timezone can't be read.
PrayerController unlocatedPrayerController(PrefsStore store) =>
    PrayerController(
      ProgressController(store),
      const PrayerTimeSource(ZoneDirectory({})),
      store,
      resolveZone: () async => null,
    );

/// Zones used by the prayer tests. Coordinates match `assets/zones.json`.
const testZones = ZoneDirectory({
  'Africa/Tunis': ZoneLocation(36.8, 10.1833, 'TN'),
  'Asia/Riyadh': ZoneLocation(24.6333, 46.7167, 'SA'),
  'Asia/Urumqi': ZoneLocation(43.8, 87.5833, 'CN'),
  'Asia/Shanghai': ZoneLocation(31.2333, 121.4667, 'CN'),
  'Europe/Oslo': ZoneLocation(59.9167, 10.75, 'NO'),
  'Asia/Jakarta': ZoneLocation(-6.1667, 106.8, 'ID'),
  'America/New_York': ZoneLocation(40.7142, -74.0064, 'US'),
});

/// Builds a timetable from wall-clock times on a fixed local day, so classifier
/// tests can state the times they mean instead of deriving them from astronomy.
PrayerTimetable timetableOf({
  required String fajr,
  required String dhuhr,
  required String asr,
  required String maghrib,
  required String isha,
  String ishaBefore = '20:00',
  DateTime? day,
}) {
  final base = day ?? DateTime(2026, 3, 15);
  DateTime at(String hhmm, {int dayOffset = 0}) {
    final parts = hhmm.split(':');
    return DateTime(base.year, base.month, base.day + dayOffset,
        int.parse(parts[0]), int.parse(parts[1]));
  }

  return PrayerTimetable(
    times: {
      DailyPrayer.fajr: at(fajr),
      DailyPrayer.dhuhr: at(dhuhr),
      DailyPrayer.asr: at(asr),
      DailyPrayer.maghrib: at(maghrib),
      DailyPrayer.isha: at(isha),
    },
    ishaBefore: at(ishaBefore, dayOffset: -1),
  );
}
