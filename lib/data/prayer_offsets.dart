import 'dart:convert';

import '../models/prayer.dart';

/// How far a user's actual practice sits from the computed prayer times.
///
/// Two things make the astronomy wrong for a given person. The zone's
/// representative city may be far from where they are — up to an hour in large
/// single-zone countries — and nobody prays at the instant the prayer comes in;
/// they reach the mosque, or wake late for Fajr. Both show up as a roughly
/// constant per-prayer delay, which is what this learns.
///
/// Keyed by timezone: flying Tunis to Kuala Lumpur makes the astronomy correct
/// itself instantly, but a learned "Isha runs 25 minutes late" from Tunis is
/// then pure noise, so a zone change starts over.
class PrayerOffsets {
  /// Weight given to a correction the user made by hand. High, because an
  /// explicit choice is the only signal that positively asserts a prayer.
  static const correctionWeight = 0.4;

  /// Weight given to simply finishing a session under the guessed prayer. Low:
  /// it says the user didn't object, not that the guess was right.
  static const completionWeight = 0.1;

  /// Beyond this a correction is qada' — someone praying Asr at 21:00 — and
  /// says nothing about when they normally pray Asr.
  static const correctionTolerance = Duration(minutes: 90);

  /// A completion this far from the computed time is a guess the user tolerated
  /// rather than one they confirmed, so it must not steer the model. Without
  /// this, passively tapping through a wrong guess would teach it that wrong
  /// guess, and the loop would slowly rot.
  static const completionTolerance = Duration(minutes: 45);

  /// Learned offsets are a correction, not a relocation. Anything past this and
  /// the zone override is the right fix, not more learning.
  static const maxOffset = Duration(minutes: 90);

  /// The zone these offsets were learned in; null when nothing is learned yet.
  final String? zoneId;
  final Map<DailyPrayer, Duration> byPrayer;

  const PrayerOffsets({this.zoneId, this.byPrayer = const {}});

  static const empty = PrayerOffsets();

  /// Folds one observation in, or returns this unchanged when the observation
  /// is rejected. [computed] is the astronomical time for [prayer] that day;
  /// [observed] is when the user actually did the adhkar.
  PrayerOffsets observe({
    required String zoneId,
    required DailyPrayer prayer,
    required DateTime observed,
    required DateTime computed,
    required bool manual,
  }) {
    // A different zone invalidates everything learned before it.
    final base = zoneId == this.zoneId ? this : const PrayerOffsets();

    final delta = observed.difference(computed);
    final tolerance = manual ? correctionTolerance : completionTolerance;
    if (delta.abs() > tolerance) return this;

    final weight = manual ? correctionWeight : completionWeight;
    final previous = base.byPrayer[prayer] ?? Duration.zero;
    final blended = previous +
        Duration(
          microseconds:
              ((delta - previous).inMicroseconds * weight).round(),
        );

    return PrayerOffsets(
      zoneId: zoneId,
      byPrayer: {...base.byPrayer, prayer: _clamp(blended)},
    );
  }

  static Duration _clamp(Duration value) => value > maxOffset
      ? maxOffset
      : value < -maxOffset
          ? -maxOffset
          : value;

  String toJsonString() => jsonEncode({
        'zone': zoneId,
        'offsets': {
          for (final entry in byPrayer.entries)
            entry.key.name: entry.value.inSeconds,
        },
      });

  /// Tolerant of anything malformed: a corrupt blob means "learn again", never
  /// a crash on startup.
  factory PrayerOffsets.fromJsonString(String source) {
    try {
      final json = jsonDecode(source) as Map<String, dynamic>;
      final raw = (json['offsets'] as Map<String, dynamic>?) ?? const {};
      return PrayerOffsets(
        zoneId: json['zone'] as String?,
        byPrayer: {
          for (final entry in raw.entries)
            ?prayerFromName(entry.key):
                _clamp(Duration(seconds: (entry.value as num).toInt())),
        },
      );
    } catch (_) {
      return empty;
    }
  }
}
