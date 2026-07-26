import 'package:flutter_test/flutter_test.dart';

import 'package:adwam/data/prayer_offsets.dart';
import 'package:adwam/models/prayer.dart';

final _computed = DateTime(2026, 3, 15, 18, 20); // Maghrib

PrayerOffsets _observe(
  PrayerOffsets offsets, {
  required int deltaMinutes,
  bool manual = true,
  String zone = 'Africa/Tunis',
  DailyPrayer prayer = DailyPrayer.maghrib,
}) =>
    offsets.observe(
      zoneId: zone,
      prayer: prayer,
      observed: _computed.add(Duration(minutes: deltaMinutes)),
      computed: _computed,
      manual: manual,
    );

int _minutes(PrayerOffsets offsets,
        [DailyPrayer prayer = DailyPrayer.maghrib]) =>
    (offsets.byPrayer[prayer] ?? Duration.zero).inMinutes;

void main() {
  group('learning from corrections', () {
    test('a correction moves the offset toward the observed delay', () {
      final learned = _observe(PrayerOffsets.empty, deltaMinutes: 20);
      // One observation at weight 0.4 of the way from zero.
      expect(_minutes(learned), 8);
    });

    test('repeated consistent corrections converge on the real delay', () {
      var offsets = PrayerOffsets.empty;
      for (var i = 0; i < 12; i++) {
        offsets = _observe(offsets, deltaMinutes: 20);
      }
      expect(_minutes(offsets), closeTo(20, 1));
    });

    test('a negative delay is learned just as well', () {
      var offsets = PrayerOffsets.empty;
      for (var i = 0; i < 12; i++) {
        offsets = _observe(offsets, deltaMinutes: -25);
      }
      expect(_minutes(offsets), closeTo(-25, 1));
    });

    test('offsets are learned per prayer, not globally', () {
      var offsets = _observe(PrayerOffsets.empty, deltaMinutes: 30);
      offsets = _observe(offsets, deltaMinutes: -30, prayer: DailyPrayer.fajr);
      expect(_minutes(offsets, DailyPrayer.maghrib), greaterThan(0));
      expect(_minutes(offsets, DailyPrayer.fajr), lessThan(0));
    });
  });

  group('rejecting bad observations', () {
    test('a qada prayer is discarded rather than learned', () {
      // Praying Asr at 21:00 says nothing about when Asr normally is.
      final learned = _observe(PrayerOffsets.empty, deltaMinutes: 160);
      expect(learned.byPrayer, isEmpty);
    });

    test('the qada threshold is exactly 90 minutes', () {
      expect(_observe(PrayerOffsets.empty, deltaMinutes: 90).byPrayer, isNotEmpty);
      expect(_observe(PrayerOffsets.empty, deltaMinutes: 91).byPrayer, isEmpty);
    });

    test('a far-off completion is not evidence the guess was right', () {
      // The user tapped through a guess 70 minutes stale without correcting.
      // Tolerating a wrong guess must not teach it.
      final learned =
          _observe(PrayerOffsets.empty, deltaMinutes: 70, manual: false);
      expect(learned.byPrayer, isEmpty);
    });

    test('the completion threshold is tighter than the correction one', () {
      expect(
        _observe(PrayerOffsets.empty, deltaMinutes: 60, manual: false).byPrayer,
        isEmpty,
      );
      expect(
        _observe(PrayerOffsets.empty, deltaMinutes: 60).byPrayer,
        isNotEmpty,
      );
    });
  });

  group('resistance to a rotting feedback loop', () {
    test('tolerated completions cannot drag the offset past its clamp', () {
      // Worst case: the user never corrects, always finishing at the very edge
      // of what a completion is allowed to assert.
      var offsets = PrayerOffsets.empty;
      for (var i = 0; i < 500; i++) {
        offsets = _observe(offsets, deltaMinutes: 44, manual: false);
      }
      expect(_minutes(offsets), lessThanOrEqualTo(45));
    });

    test('an offset can never exceed the maximum, however many corrections',
        () {
      var offsets = PrayerOffsets.empty;
      for (var i = 0; i < 500; i++) {
        offsets = _observe(offsets, deltaMinutes: 89);
      }
      expect(offsets.byPrayer[DailyPrayer.maghrib]!.abs(),
          lessThanOrEqualTo(PrayerOffsets.maxOffset));
    });

    test('corrections outweigh completions when they disagree', () {
      var viaCompletions = PrayerOffsets.empty;
      var viaCorrections = PrayerOffsets.empty;
      for (var i = 0; i < 3; i++) {
        viaCompletions =
            _observe(viaCompletions, deltaMinutes: 30, manual: false);
        viaCorrections = _observe(viaCorrections, deltaMinutes: 30);
      }
      expect(_minutes(viaCorrections), greaterThan(_minutes(viaCompletions)));
    });
  });

  group('travel', () {
    test('changing timezone discards what was learned elsewhere', () {
      var offsets = PrayerOffsets.empty;
      for (var i = 0; i < 12; i++) {
        offsets = _observe(offsets, deltaMinutes: 40);
      }
      expect(_minutes(offsets), greaterThan(30));

      // Landed in Kuala Lumpur: the astronomy self-corrects instantly, and a
      // Tunis delay is now noise.
      final abroad =
          _observe(offsets, deltaMinutes: 5, zone: 'Asia/Kuala_Lumpur');
      expect(abroad.zoneId, 'Asia/Kuala_Lumpur');
      expect(_minutes(abroad), 2);
    });

    test('returning does not resurrect the old zone offsets', () {
      var offsets = _observe(PrayerOffsets.empty, deltaMinutes: 40);
      offsets = _observe(offsets, deltaMinutes: 5, zone: 'Asia/Kuala_Lumpur');
      final home = _observe(offsets, deltaMinutes: 0);
      expect(home.zoneId, 'Africa/Tunis');
      expect(_minutes(home), 0);
    });
  });

  group('persistence', () {
    test('round-trips through JSON', () {
      var offsets = PrayerOffsets.empty;
      offsets = _observe(offsets, deltaMinutes: 30);
      offsets = _observe(offsets, deltaMinutes: -20, prayer: DailyPrayer.fajr);

      final restored = PrayerOffsets.fromJsonString(offsets.toJsonString());
      expect(restored.zoneId, offsets.zoneId);
      expect(restored.byPrayer, offsets.byPrayer);
    });

    test('a corrupt blob resets instead of throwing', () {
      expect(PrayerOffsets.fromJsonString('not json').byPrayer, isEmpty);
      expect(PrayerOffsets.fromJsonString('{"zone":1}').byPrayer, isEmpty);
    });

    test('unknown prayer names in stored data are dropped', () {
      final restored = PrayerOffsets.fromJsonString(
        '{"zone":"Africa/Tunis","offsets":{"maghrib":600,"duha":900}}',
      );
      expect(restored.byPrayer.keys, [DailyPrayer.maghrib]);
      expect(_minutes(restored), 10);
    });

    test('a stored offset beyond the clamp is brought back into range', () {
      final restored = PrayerOffsets.fromJsonString(
        '{"zone":"Africa/Tunis","offsets":{"maghrib":99999}}',
      );
      expect(restored.byPrayer[DailyPrayer.maghrib], PrayerOffsets.maxOffset);
    });
  });
}
