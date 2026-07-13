import 'package:flutter_test/flutter_test.dart';

import 'package:adwam/data/content_repository.dart';
import 'package:adwam/models/dhikr.dart';

Dhikr d(
  String id, {
  DhikrForm form = DhikrForm.short,
  int reps = 1,
  BenefitTier tier = BenefitTier.none,
  int hint = noSortHint,
  int fixed = noFixedOrder,
  String? arabic,
}) =>
    Dhikr(
      id: id,
      arabic: arabic ?? id,
      repetitions: reps,
      form: form,
      tier: tier,
      contexts: const {SessionType.morning},
      sortHint: hint,
      fixedOrder: fixed,
    );

List<String> sortedIds(List<Dhikr> input) =>
    (input..sort(compareDhikrs)).map((x) => x.id).toList();

void main() {
  test('fixed_order beats every heuristic rule: istighfar before '
      'Ayat al-Kursi in the post-prayer sunnah sequence', () {
    expect(
      sortedIds([
        d('ayat-al-kursi',
            form: DhikrForm.quran, tier: BenefitTier.reward, fixed: 6),
        d('tasbih-x100', reps: 100, tier: BenefitTier.reward, fixed: 5),
        d('istighfar', fixed: 1),
      ]),
      ['istighfar', 'tasbih-x100', 'ayat-al-kursi'],
    );
  });

  test('quran always first, even without a benefit hadith', () {
    expect(
      sortedIds([
        d('short-protection', tier: BenefitTier.protection),
        d('quran-none', form: DhikrForm.quran, tier: BenefitTier.none),
      ]),
      ['quran-none', 'short-protection'],
    );
  });

  test('benefit tier outranks the short/long split: '
      'long reward dua before every no-benefit dhikr', () {
    expect(
      sortedIds([
        d('none-short-1x', reps: 1),
        d('reward-long-1x', form: DhikrForm.long, tier: BenefitTier.reward),
        d('protection-short-1x', tier: BenefitTier.protection),
        d('none-long', form: DhikrForm.long),
      ]),
      ['protection-short-1x', 'reward-long-1x', 'none-short-1x', 'none-long'],
    );
  });

  test('high-repetition dhikrs sink below the tiered dhikrs but above full '
      'surahs, ordered protection then reward then none inside', () {
    expect(
      sortedIds([
        d('surah', form: DhikrForm.surah, tier: BenefitTier.protection),
        d('none-x100', reps: 100),
        d('protection-x100', reps: 100, tier: BenefitTier.protection),
        d('reward-1x', tier: BenefitTier.reward),
      ]),
      ['reward-1x', 'protection-x100', 'none-x100', 'surah'],
    );
  });

  test('within a tier: repetitions ascending, short breaks same-count ties',
      () {
    expect(
      sortedIds([
        d('long-1x', form: DhikrForm.long, reps: 1, tier: BenefitTier.reward),
        d('short-x100', reps: 100, tier: BenefitTier.reward),
        d('short-x1', reps: 1, tier: BenefitTier.reward),
        d('short-x7', reps: 7, tier: BenefitTier.reward),
      ]),
      ['short-x1', 'long-1x', 'short-x7', 'short-x100'],
    );
  });

  test('shared sort_hint keeps a cluster together ahead of its group, '
      'ordered inside by word count', () {
    expect(
      sortedIds([
        d('plain', arabic: 'ذكر'),
        d('asbahna-long', hint: 1, arabic: 'أصبحنا وأصبح الملك لله والحمد لله'),
        d('asbahna-short', hint: 1, arabic: 'اللهم بك أصبحنا'),
      ]),
      ['asbahna-short', 'asbahna-long', 'plain'],
    );
  });

  test('full surahs always last, even with a protection benefit', () {
    expect(
      sortedIds([
        d('surah-mulk', form: DhikrForm.surah, tier: BenefitTier.protection),
        d('plain-none'),
        d('long-none', form: DhikrForm.long),
      ]),
      ['plain-none', 'long-none', 'surah-mulk'],
    );
  });

  test('least rule: fewer words first among otherwise equal dhikrs', () {
    expect(
      sortedIds([
        d('three-words', arabic: 'سبحان الله وبحمده'),
        d('two-words', arabic: 'سبحان الله'),
      ]),
      ['two-words', 'three-words'],
    );
  });

  group('orderedList', () {
    final repo = ContentRepository([
      d('a', reps: 3),
      d('b', reps: 1),
      d('c', reps: 100),
    ]);

    test('empty user order falls back to default sort', () {
      expect(
        repo.orderedList(SessionType.morning, []).map((x) => x.id),
        ['b', 'a', 'c'],
      );
    });

    test('user order wins; unknown ids dropped; missing ids appended', () {
      expect(
        repo.orderedList(SessionType.morning, ['c', 'deleted-id', 'b'])
            .map((x) => x.id),
        ['c', 'b', 'a'],
      );
    });
  });
}
