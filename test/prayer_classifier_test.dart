import 'package:flutter_test/flutter_test.dart';

import 'package:adwam/data/prayer_classifier.dart';
import 'package:adwam/models/prayer.dart';
import 'package:adwam/models/prayer_timetable.dart';

import 'support/prayer_support.dart';

/// A plain mid-latitude spring day. Every time below is stated, not computed,
/// so these tests exercise the classifier and nothing else.
final _table = timetableOf(
  fajr: '05:00',
  dhuhr: '12:30',
  asr: '15:45',
  maghrib: '18:20',
  isha: '19:50',
  ishaBefore: '19:50',
);

final _day = DateTime(2026, 3, 15);

DateTime _at(String hhmm, {int dayOffset = 0}) {
  final parts = hhmm.split(':');
  return DateTime(_day.year, _day.month, _day.day + dayOffset,
      int.parse(parts[0]), int.parse(parts[1]));
}

PrayerGuess? _classify(
  String hhmm, {
  int dayOffset = 0,
  Map<DailyPrayer, Duration> offsets = const {},
  DailyPrayer? confirmed,
  PrayerTimetable? table,
}) =>
    classifyPrayer(
      timetable: table ?? _table,
      now: _at(hhmm, dayOffset: dayOffset),
      offsets: offsets,
      lastConfirmedToday: confirmed,
    );

void main() {
  group('window interiors', () {
    test('each prayer is picked shortly after it comes in', () {
      expect(_classify('05:10')!.prayer, DailyPrayer.fajr);
      expect(_classify('12:40')!.prayer, DailyPrayer.dhuhr);
      expect(_classify('15:50')!.prayer, DailyPrayer.asr);
      expect(_classify('18:30')!.prayer, DailyPrayer.maghrib);
      expect(_classify('20:00')!.prayer, DailyPrayer.isha);
    });

    test('mid-window still resolves to the prayer that began it', () {
      expect(_classify('11:00')!.prayer, DailyPrayer.fajr);
      expect(_classify('14:00')!.prayer, DailyPrayer.dhuhr);
      expect(_classify('17:00')!.prayer, DailyPrayer.asr);
    });
  });

  group('boundaries', () {
    test('a prayer is current from its exact minute', () {
      expect(_classify('12:30')!.prayer, DailyPrayer.dhuhr);
      expect(_classify('12:29')!.prayer, DailyPrayer.fajr);
    });

    test('one minute either side of Maghrib', () {
      expect(_classify('18:19')!.prayer, DailyPrayer.asr);
      expect(_classify('18:20')!.prayer, DailyPrayer.maghrib);
      expect(_classify('18:21')!.prayer, DailyPrayer.maghrib);
    });

    test('before Fajr belongs to last night Isha, not today', () {
      expect(_classify('04:59')!.prayer, DailyPrayer.isha);
      expect(_classify('05:00')!.prayer, DailyPrayer.fajr);
    });
  });

  group('confidence', () {
    test('confident inside the window, provisional past it', () {
      expect(_classify('05:44')!.confident, isTrue);
      expect(_classify('05:46')!.confident, isFalse);
    });

    test('the sunrise-to-Dhuhr gap answers Fajr but is not confident', () {
      final guess = _classify('10:00')!;
      expect(guess.prayer, DailyPrayer.fajr);
      expect(guess.confident, isFalse);
    });

    test('late night is Isha but not confident', () {
      expect(_classify('23:59'), const PrayerGuess(DailyPrayer.isha, confident: false));
    });
  });

  group('after midnight', () {
    // The night of the 15th, read on the morning of the 16th: the timetable is
    // the 16th's, whose ishaBefore is the 15th's Isha.
    final nextDay = timetableOf(
      fajr: '04:58',
      dhuhr: '12:30',
      asr: '15:46',
      maghrib: '18:21',
      isha: '19:51',
      ishaBefore: '19:50',
      day: DateTime(2026, 3, 16),
    );

    test('just past midnight is still last night Isha', () {
      final guess = classifyPrayer(
        timetable: nextDay,
        now: DateTime(2026, 3, 16, 0, 30),
      );
      expect(guess!.prayer, DailyPrayer.isha);
      expect(guess.confident, isFalse);
    });

    test('the small hours are still Isha, never tomorrow Fajr', () {
      final guess = classifyPrayer(
        timetable: nextDay,
        now: DateTime(2026, 3, 16, 3, 0),
      );
      expect(guess!.prayer, DailyPrayer.isha);
    });

    test('Isha immediately before Fajr does not leak into Fajr', () {
      final guess = classifyPrayer(
        timetable: nextDay,
        now: DateTime(2026, 3, 16, 4, 57),
      );
      expect(guess!.prayer, DailyPrayer.isha);
    });
  });

  group('non-decreasing constraint', () {
    test('a confirmed later prayer stops the guess going backwards', () {
      // Astronomy says Maghrib, but Isha was already confirmed today.
      final guess = _classify('18:30', confirmed: DailyPrayer.isha)!;
      expect(guess.prayer, DailyPrayer.isha);
      expect(guess.confident, isFalse);
    });

    test('an earlier confirmation does not hold the guess back', () {
      final guess = _classify('18:30', confirmed: DailyPrayer.dhuhr)!;
      expect(guess.prayer, DailyPrayer.maghrib);
    });

    test('the same prayer twice in a row is allowed', () {
      final guess = _classify('18:40', confirmed: DailyPrayer.maghrib)!;
      expect(guess.prayer, DailyPrayer.maghrib);
    });

    test('correcting downwards is honoured, not undone', () {
      // The user said Maghrib at 20:00 while astronomy said Isha. Once Isha's
      // own time passes the guess may move up again, but the correction is not
      // immediately overridden by a stale higher confirmation.
      final guess = _classify('19:00', confirmed: DailyPrayer.maghrib)!;
      expect(guess.prayer, DailyPrayer.maghrib);
    });
  });

  group('learned offsets', () {
    test('a positive offset delays when the prayer is considered current', () {
      const offsets = {DailyPrayer.fajr: Duration(minutes: 30)};
      expect(_classify('05:15', offsets: offsets)!.prayer, DailyPrayer.isha);
      expect(_classify('05:35', offsets: offsets)!.prayer, DailyPrayer.fajr);
    });

    test('a negative offset brings it forward', () {
      const offsets = {DailyPrayer.dhuhr: Duration(minutes: -20)};
      expect(_classify('12:15', offsets: offsets)!.prayer, DailyPrayer.dhuhr);
    });

    test('an offset large enough to overtake the next prayer cannot reorder it',
        () {
      // Maghrib +120min would land at 20:20, past Isha's 19:50.
      const offsets = {DailyPrayer.maghrib: Duration(minutes: 120)};
      final schedule = _table.adjustedSchedule(offsets);
      for (var i = 1; i < schedule.length; i++) {
        expect(schedule[i].at.isAfter(schedule[i - 1].at), isTrue,
            reason: '${schedule[i]} must follow ${schedule[i - 1]}');
      }
      expect(schedule.map((e) => e.prayer).toList(), [
        DailyPrayer.isha,
        DailyPrayer.fajr,
        DailyPrayer.dhuhr,
        DailyPrayer.asr,
        DailyPrayer.maghrib,
        DailyPrayer.isha,
      ]);
    });
  });

  group('tryBuild', () {
    test('rejects a timetable whose prayers are out of order', () {
      final table = PrayerTimetable.tryBuild(
        times: {
          DailyPrayer.fajr: _at('05:00'),
          DailyPrayer.dhuhr: _at('12:30'),
          DailyPrayer.asr: _at('12:00'), // before Dhuhr
          DailyPrayer.maghrib: _at('18:20'),
          DailyPrayer.isha: _at('19:50'),
        },
        ishaBefore: _at('19:50', dayOffset: -1),
      );
      expect(table, isNull);
    });

    test('rejects a timetable whose ishaBefore lands after Fajr', () {
      // This is the shape adhan_dart returns above ~48 degrees in summer.
      final table = PrayerTimetable.tryBuild(
        times: {
          DailyPrayer.fajr: _at('05:00'),
          DailyPrayer.dhuhr: _at('12:30'),
          DailyPrayer.asr: _at('15:45'),
          DailyPrayer.maghrib: _at('18:20'),
          DailyPrayer.isha: _at('19:50'),
        },
        ishaBefore: _at('19:50'),
      );
      expect(table, isNull);
    });

    test('accepts a well-ordered timetable', () {
      expect(
        PrayerTimetable.tryBuild(
          times: {
            DailyPrayer.fajr: _at('05:00'),
            DailyPrayer.dhuhr: _at('12:30'),
            DailyPrayer.asr: _at('15:45'),
            DailyPrayer.maghrib: _at('18:20'),
            DailyPrayer.isha: _at('19:50'),
          },
          ishaBefore: _at('19:50', dayOffset: -1),
        ),
        isNotNull,
      );
    });
  });

  test('prayer keys match the strings used to tag dhikrs', () {
    expect(DailyPrayer.fajr.matches(const []), isTrue);
    expect(DailyPrayer.fajr.matches(const ['fajr', 'maghrib']), isTrue);
    expect(DailyPrayer.asr.matches(const ['fajr', 'maghrib']), isFalse);
    expect(prayerFromName('maghrib'), DailyPrayer.maghrib);
    expect(prayerFromName('nonsense'), isNull);
    expect(prayerFromName(null), isNull);
  });
}
