import 'package:flutter_test/flutter_test.dart';

import 'package:dhikr/data/content_repository.dart';
import 'package:dhikr/models/dhikr.dart';

Dhikr d(
  String id, {
  DhikrForm form = DhikrForm.short,
  int reps = 1,
  BenefitTier tier = BenefitTier.none,
  int hint = noSortHint,
}) =>
    Dhikr(
      id: id,
      arabic: id,
      repetitions: reps,
      form: form,
      tier: tier,
      contexts: const {SessionType.morning},
      sortHint: hint,
    );

List<String> sortedIds(List<Dhikr> input) =>
    (input..sort(compareDhikrs)).map((x) => x.id).toList();

void main() {
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
        d('protection-short-100x', reps: 100, tier: BenefitTier.protection),
        d('none-long', form: DhikrForm.long),
      ]),
      ['protection-short-100x', 'reward-long-1x', 'none-short-1x', 'none-long'],
    );
  });

  test('within a tier: short before long, then repetitions ascending', () {
    expect(
      sortedIds([
        d('long-1x', form: DhikrForm.long, reps: 1, tier: BenefitTier.reward),
        d('short-x100', reps: 100, tier: BenefitTier.reward),
        d('short-x1', reps: 1, tier: BenefitTier.reward),
        d('short-x7', reps: 7, tier: BenefitTier.reward),
      ]),
      ['short-x1', 'short-x7', 'short-x100', 'long-1x'],
    );
  });

  test('sort_hint clusters equal dhikrs, hinted before unhinted', () {
    expect(
      sortedIds([
        d('plain-a'),
        d('asbahna-3', hint: 3),
        d('plain-b'),
        d('asbahna-1', hint: 1),
        d('asbahna-2', hint: 2),
      ]),
      ['asbahna-1', 'asbahna-2', 'asbahna-3', 'plain-a', 'plain-b'],
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
