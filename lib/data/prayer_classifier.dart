import '../models/prayer.dart';
import '../models/prayer_timetable.dart';

/// How long after a prayer we still believe the user is doing its adhkar.
/// Past this the guess is still shown, but flagged as a guess so the UI can
/// present it as provisional rather than settled.
const defaultConfidenceWindow = Duration(minutes: 45);

/// A classified prayer plus how much we trust it.
class PrayerGuess {
  final DailyPrayer prayer;

  /// True when [prayer] started recently enough to be a confident call.
  /// False in the long gaps — mid-morning between sunrise and Dhuhr, or late
  /// at night — where a prayer is still the best answer but not a sure one.
  final bool confident;

  const PrayerGuess(this.prayer, {required this.confident});

  @override
  bool operator ==(Object other) =>
      other is PrayerGuess &&
      other.prayer == prayer &&
      other.confident == confident;

  @override
  int get hashCode => Object.hash(prayer, confident);

  @override
  String toString() => '${prayer.name}(${confident ? 'sure' : 'guess'})';
}

/// Works out which prayer's adhkar the user is most likely reciting.
///
/// The rule is simply "the most recent prayer whose time has passed", with two
/// corrections:
///
///  * [offsets] shift the computed times toward when this user actually prays
///    (see PrayerOffsets) — the astronomy says when the prayer came in, not
///    when someone got to the mosque.
///  * [lastConfirmedToday] stops the guess going backwards. Prayer order is
///    non-decreasing within a day, so once Maghrib is confirmed at 19:10 a
///    session at 20:30 cannot be Asr however far off the astronomy is. This is
///    what rescues users whose zone representative city is far away.
///
/// Returns null only when [now] precedes every entry in the timetable, which
/// cannot happen for a well-formed table (it starts at last night's Isha).
PrayerGuess? classifyPrayer({
  required PrayerTimetable timetable,
  required DateTime now,
  Map<DailyPrayer, Duration> offsets = const {},
  DailyPrayer? lastConfirmedToday,
  Duration confidenceWindow = defaultConfidenceWindow,
}) {
  final schedule = timetable.adjustedSchedule(offsets);

  ScheduleEntry? current;
  for (final entry in schedule) {
    if (entry.at.isAfter(now)) break;
    current = entry;
  }
  if (current == null) return null;

  final elapsed = now.difference(current.at);
  var prayer = current.prayer;
  var confident = elapsed <= confidenceWindow;

  // Never go backwards past a prayer already confirmed today. Staying on the
  // same prayer is fine — reciting one prayer's adhkar twice is ordinary.
  if (lastConfirmedToday != null && lastConfirmedToday.index > prayer.index) {
    prayer = lastConfirmedToday;
    confident = false;
  }

  return PrayerGuess(prayer, confident: confident);
}
