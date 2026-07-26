import 'package:adhan_dart/adhan_dart.dart' as adhan;

import '../models/prayer.dart';
import '../models/prayer_timetable.dart';
import 'calculation_methods.dart';
import 'zone_coordinates.dart';

/// Computes prayer timetables from a timezone id, with no location permission.
///
/// Deliberately synchronous and free of plugin calls so tests can drive it
/// directly: the zone id is resolved once by the caller (see PrayerController)
/// and passed in.
class PrayerTimeSource {
  final ZoneDirectory zones;

  const PrayerTimeSource(this.zones);

  /// Timetable for the local calendar day containing [localDay], or null when
  /// the zone is unknown or the astronomy doesn't resolve (polar latitudes).
  ///
  /// adhan_dart returns UTC instants, so every time is converted to local
  /// before it reaches [PrayerTimetable], which documents that it holds local
  /// times only.
  PrayerTimetable? timetableFor({
    required String? zoneId,
    required DateTime localDay,
  }) {
    final location = zones[zoneId];
    if (location == null) return null;

    // Anchor the calendar date in UTC. adhan_dart only reads year/month/day,
    // but it derives neighbouring days with `subtract(Duration(days: 1))` —
    // wall-clock arithmetic that misbehaves when the *host's* local day isn't
    // 24 hours long. Feeding it a local date makes prayer times collapse
    // (fajr == isha) on the host timezone's own DST transition days, which has
    // nothing to do with where the user is.
    final day = DateTime.utc(localDay.year, localDay.month, localDay.day);
    final today = _compute(location, day);
    final yesterday = _compute(location, day.subtract(const Duration(days: 1)));
    if (today == null || yesterday == null) return null;

    return PrayerTimetable.tryBuild(
      times: {
        DailyPrayer.fajr: today.fajr.toLocal(),
        DailyPrayer.dhuhr: today.dhuhr.toLocal(),
        DailyPrayer.asr: today.asr.toLocal(),
        DailyPrayer.maghrib: today.maghrib.toLocal(),
        DailyPrayer.isha: today.isha.toLocal(),
      },
      // Yesterday's own Isha, computed rather than read from adhan_dart's
      // `ishaBefore` convenience field: above ~48° its high-latitude fallback
      // (`safeIshaBefore`) derives from *today's* sunset instead of
      // yesterday's, so from spring to autumn in places like Oslo it returns a
      // copy of today's Isha. That lands after Fajr and makes the whole
      // timetable non-monotonic, which would silently disable the feature for
      // every northern user for half the year.
      ishaBefore: yesterday.isha.toLocal(),
    );
  }

  adhan.PrayerTimes? _compute(ZoneLocation location, DateTime day) {
    final coordinates = adhan.Coordinates(location.latitude, location.longitude);
    try {
      return adhan.PrayerTimes(
        date: day,
        coordinates: coordinates,
        calculationParameters: parametersFor(
          coordinates: coordinates,
          country: location.country,
        ),
      );
    } catch (_) {
      // Degenerate geometry (polar day/night that even aqrabBalad can't
      // resolve) surfaces as an exception rather than a usable timetable.
      return null;
    }
  }
}
