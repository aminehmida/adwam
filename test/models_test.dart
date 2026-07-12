import 'package:flutter_test/flutter_test.dart';

import 'package:adwam/models/daily_progress.dart';
import 'package:adwam/models/dhikr.dart';
import 'package:adwam/models/user_list_config.dart';

void main() {
  group('Dhikr.fromJson', () {
    test('full record maps every field', () {
      final dhikr = Dhikr.fromJson({
        'id': 'me-01',
        'arabic': 'آية الكرسي',
        'repetitions': 1,
        'form': 'quran',
        'benefit_tier': 'protection',
        'benefit_text': 'نص الفضل',
        'benefit_source': 'مسلم',
        'benefit_text_en': 'Virtue text',
        'benefit_source_en': 'Muslim',
        'contexts': ['morning', 'evening', 'post_prayer', 'sleep'],
        'sort_hint': 3,
      });
      expect(dhikr.id, 'me-01');
      expect(dhikr.form, DhikrForm.quran);
      expect(dhikr.tier, BenefitTier.protection);
      expect(dhikr.benefit, 'نص الفضل');
      expect(dhikr.benefitEn, 'Virtue text');
      expect(dhikr.benefitSourceEn, 'Muslim');
      expect(dhikr.contexts, SessionType.values.toSet());
      expect(dhikr.sortHint, 3);
    });

    test('minimal record: optional fields null, sort_hint defaults to last',
        () {
      final dhikr = Dhikr.fromJson({
        'id': 'x',
        'arabic': 'ذكر',
        'repetitions': 3,
        'form': 'short',
        'benefit_tier': 'none',
        'contexts': ['sleep'],
      });
      expect(dhikr.benefit, isNull);
      expect(dhikr.benefitEn, isNull);
      expect(dhikr.sortHint, noSortHint);
      expect(dhikr.contexts, {SessionType.sleep});
    });
  });

  test('wordCount ignores surrounding and repeated whitespace', () {
    final dhikr = Dhikr.fromJson({
      'id': 'x',
      'arabic': '  سبحان الله  وبحمده \n سبحان الله العظيم ',
      'repetitions': 1,
      'form': 'short',
      'benefit_tier': 'none',
      'contexts': ['morning'],
    });
    expect(dhikr.wordCount, 6);
  });

  group('DailyProgress JSON', () {
    test('round-trips counts and done set', () {
      final progress = DailyProgress(
        dateStamp: '2026-07-12',
        counts: const {'morning.a': 3, 'sleep.b': 1},
        done: const {'sleep.b'},
      );
      final restored = DailyProgress.fromJsonString(progress.toJsonString());
      expect(restored.dateStamp, '2026-07-12');
      expect(restored.counts, {'morning.a': 3, 'sleep.b': 1});
      expect(restored.done, {'sleep.b'});
      expect(restored.countFor(SessionType.morning, 'a'), 3);
      expect(restored.isDone(SessionType.sleep, 'b'), isTrue);
      expect(restored.isDone(SessionType.morning, 'a'), isFalse);
    });

    test('same dhikr counts independently per session', () {
      const progress = DailyProgress(
        dateStamp: '2026-07-12',
        counts: {'morning.a': 5},
      );
      expect(progress.countFor(SessionType.morning, 'a'), 5);
      expect(progress.countFor(SessionType.evening, 'a'), 0);
    });
  });

  test('dateStampOf pads to a stable sortable form', () {
    expect(dateStampOf(DateTime(2026, 7, 2)), '2026-07-02');
    expect(dateStampOf(DateTime(2026, 11, 30)), '2026-11-30');
  });

  test('UserListConfig round-trips order and hidden', () {
    const config = UserListConfig(order: ['b', 'a'], hidden: {'c'});
    final restored = UserListConfig.fromJsonString(config.toJsonString());
    expect(restored.order, ['b', 'a']);
    expect(restored.hidden, {'c'});
    expect(restored.isDefaultOrder, isFalse);
    expect(const UserListConfig().isDefaultOrder, isTrue);
  });
}
