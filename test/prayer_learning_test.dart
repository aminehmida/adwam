import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:adwam/data/prayer_time_source.dart';
import 'package:adwam/data/prefs_store.dart';
import 'package:adwam/models/dhikr.dart';
import 'package:adwam/models/prayer.dart';
import 'package:adwam/state/prayer_controller.dart';
import 'package:adwam/state/progress_controller.dart';

import 'support/prayer_support.dart';

/// End-to-end learning through PrayerController: corrections reach the offset
/// store, survive a restart, and actually move the guess.
void main() {
  late PrefsStore store;
  var now = DateTime(2026, 3, 15, 12, 0);

  PrayerController build() => PrayerController(
        ProgressController(store),
        const PrayerTimeSource(testZones),
        store,
        clock: () => now,
        resolveZone: () async => 'Africa/Tunis',
      );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = await PrefsStore.open();
    now = DateTime(2026, 3, 15, 12, 0);
  });

  test('a correction is recorded against the zone and persists', () async {
    final controller = build();
    await controller.init();

    controller.select(DailyPrayer.dhuhr);

    expect(controller.offsets.zoneId, 'Africa/Tunis');
    expect(controller.offsets.byPrayer[DailyPrayer.dhuhr], isNotNull);

    // A fresh controller reading the same store keeps what was learned.
    final restarted = build();
    await restarted.init();
    expect(
      restarted.offsets.byPrayer[DailyPrayer.dhuhr],
      controller.offsets.byPrayer[DailyPrayer.dhuhr],
    );
  });

  test('a qada correction leaves the model untouched', () async {
    final controller = build();
    await controller.init();

    // Dhuhr in Tunis on this day is around midday; selecting it late at night
    // is a make-up prayer, not a statement about when Dhuhr happens.
    now = DateTime(2026, 3, 15, 23, 30);
    controller.select(DailyPrayer.dhuhr);

    expect(controller.offsets.byPrayer, isEmpty);
  });

  test('repeated corrections shift when the app thinks the prayer starts',
      () async {
    final controller = build();
    await controller.init();

    const source = PrayerTimeSource(testZones);
    final table = source.timetableFor(
      zoneId: 'Africa/Tunis',
      localDay: DateTime(2026, 3, 15),
    )!;
    final asr = table[DailyPrayer.asr];

    // The user consistently prays Asr about 40 minutes after it comes in.
    for (var i = 0; i < 12; i++) {
      now = asr.add(const Duration(minutes: 40));
      controller.select(DailyPrayer.asr);
      // Clear the session pick so the next round is a fresh guess.
      ProgressController(store).resetSession(SessionType.postPrayer);
    }

    final learned = controller.offsets.byPrayer[DailyPrayer.asr]!;
    expect(learned.inMinutes, closeTo(40, 3));

    // Check the effect on the *next* day. Today is no good: Asr is already
    // this day's last confirmed prayer, and the non-decreasing constraint
    // would pin the guess there whatever the astronomy says.
    //
    // ProgressController reads the wall clock directly, so moving the injected
    // clock forward doesn't roll it over; resetToday() is the same clearing
    // that midnight performs. Offsets live in prefs and survive it.
    ProgressController(store).resetToday();

    final tomorrow = source.timetableFor(
      zoneId: 'Africa/Tunis',
      localDay: DateTime(2026, 3, 16),
    )!;
    final fresh = build();
    await fresh.init();

    // Twenty minutes after the computed Asr, the app should no longer think
    // Asr has started for this user.
    now = tomorrow[DailyPrayer.asr].add(const Duration(minutes: 20));
    expect(fresh.active, DailyPrayer.dhuhr);

    now = tomorrow[DailyPrayer.asr].add(const Duration(minutes: 45));
    expect(fresh.active, DailyPrayer.asr);
  });

  test('learning does nothing while the location is unknown', () async {
    final controller = PrayerController(
      ProgressController(store),
      const PrayerTimeSource(testZones),
      store,
      clock: () => now,
      resolveZone: () async => null,
    );
    await controller.init();

    controller.select(DailyPrayer.dhuhr);
    expect(controller.offsets.byPrayer, isEmpty);
  });
}
