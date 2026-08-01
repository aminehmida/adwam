/// The five daily prayers, in the order they are prayed.
///
/// The enum names are the same strings used in `Dhikr.prayers` (and in
/// `content/curation.json`), so `prayer.name` matches directly with no
/// translation table — see [DailyPrayerX.matches].
///
/// Named `DailyPrayer` rather than `Prayer` because adhan_dart exports its own
/// `Prayer` enum (which also carries sunrise and none) and both are imported
/// together in the prayer-time code.
enum DailyPrayer { fajr, dhuhr, asr, maghrib, isha }

extension DailyPrayerX on DailyPrayer {
  /// Whether a dhikr tagged for [prayerKeys] belongs to this prayer.
  /// An empty tag list means "after every prayer".
  bool matches(List<String> prayerKeys) =>
      prayerKeys.isEmpty || prayerKeys.contains(name);
}

/// Parses a stored/serialised prayer key, returning null for anything unknown
/// so a corrupt preference degrades to "no prayer selected" rather than
/// throwing at startup.
DailyPrayer? prayerFromName(String? name) {
  for (final p in DailyPrayer.values) {
    if (p.name == name) return p;
  }
  return null;
}
