import 'prayer.dart';

/// One prayer time on the timeline.
class ScheduleEntry {
  final DailyPrayer prayer;
  final DateTime at;

  const ScheduleEntry(this.prayer, this.at);

  @override
  String toString() => '${prayer.name}@${at.toIso8601String()}';
}

/// Prayer times for one local day, plus the *previous* day's Isha.
///
/// Isha runs until Fajr, so at 00:30 the prayer that just happened is last
/// night's Isha — a timetable that only covered today would have every entry
/// in the future and nothing to classify against. Carrying [ishaBefore] means
/// one timetable spans the whole window a session can fall into.
///
/// All times are local, never UTC: adhan_dart returns UTC instants and the
/// caller converts before constructing this.
class PrayerTimetable {
  final Map<DailyPrayer, DateTime> times;
  final DateTime ishaBefore;

  const PrayerTimetable({required this.times, required this.ishaBefore});

  DateTime operator [](DailyPrayer prayer) => times[prayer]!;

  /// The natural timeline: last night's Isha, then today's five prayers.
  List<ScheduleEntry> get schedule => [
        ScheduleEntry(DailyPrayer.isha, ishaBefore),
        for (final p in DailyPrayer.values) ScheduleEntry(p, times[p]!),
      ];

  /// [schedule] with learned per-prayer offsets applied.
  ///
  /// Offsets are learned independently per prayer, so nothing stops Maghrib's
  /// offset pushing it past Isha's and inverting the two. Rather than reject
  /// such offsets, each entry is clamped to stay strictly after the previous
  /// one — the order of the prayers is not negotiable, the exact minute is.
  List<ScheduleEntry> adjustedSchedule(Map<DailyPrayer, Duration> offsets) {
    final result = <ScheduleEntry>[];
    DateTime? previous;
    for (final entry in schedule) {
      var at = entry.at.add(offsets[entry.prayer] ?? Duration.zero);
      if (previous != null && !at.isAfter(previous)) {
        at = previous.add(const Duration(seconds: 1));
      }
      result.add(ScheduleEntry(entry.prayer, at));
      previous = at;
    }
    return result;
  }

  /// Builds a timetable, or null when the computed times are unusable.
  ///
  /// Above the polar circle the sun may never rise or set, and adhan_dart can
  /// hand back non-finite or out-of-order instants. A null here degrades to
  /// "we don't know which prayer this is", which is the honest answer, rather
  /// than hiding adhkar based on nonsense.
  static PrayerTimetable? tryBuild({
    required Map<DailyPrayer, DateTime?> times,
    required DateTime? ishaBefore,
  }) {
    if (ishaBefore == null) return null;
    final resolved = <DailyPrayer, DateTime>{};
    for (final p in DailyPrayer.values) {
      final at = times[p];
      if (at == null) return null;
      resolved[p] = at;
    }
    final table = PrayerTimetable(times: resolved, ishaBefore: ishaBefore);
    // Times must already be in prayer order before any offset is applied;
    // if they are not, the astronomy did not resolve for this location.
    DateTime? previous;
    for (final entry in table.schedule) {
      if (previous != null && !entry.at.isAfter(previous)) return null;
      previous = entry.at;
    }
    return table;
  }
}
