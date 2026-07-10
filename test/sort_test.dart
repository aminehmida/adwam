import 'package:flutter_test/flutter_test.dart';

import 'package:dhikr/data/content_repository.dart';
import 'package:dhikr/models/dhikr.dart';

Dhikr d(
  String id, {
  DhikrForm form = DhikrForm.short,
  int reps = 1,
  BenefitTier tier = BenefitTier.none,
}) =>
    Dhikr(
      id: id,
      arabic: id,
      repetitions: reps,
      form: form,
      tier: tier,
      contexts: const {SessionType.morning},
    );

List<String> sortedIds(List<Dhikr> input) =>
    (input..sort(compareDhikrs)).map((x) => x.id).toList();

void main() {
  test('form bands: quran before short before long, regardless of reps', () {
    expect(
      sortedIds([
        d('long-1x', form: DhikrForm.long, reps: 1),
        d('short-100x', reps: 100),
        d('quran-3x', form: DhikrForm.quran, reps: 3),
      ]),
      ['quran-3x', 'short-100x', 'long-1x'],
    );
  });

  test('within a band, benefit tier first: protection leads even at 100x', () {
    expect(
      sortedIds([
        d('none-1x', reps: 1, tier: BenefitTier.none),
        d('reward-3x', reps: 3, tier: BenefitTier.reward),
        d('protection-100x', reps: 100, tier: BenefitTier.protection),
        d('other-1x', reps: 1, tier: BenefitTier.otherBenefit),
      ]),
      ['protection-100x', 'reward-3x', 'other-1x', 'none-1x'],
    );
  });

  test('same band and tier: repetition count ascending', () {
    expect(
      sortedIds([
        d('x100', reps: 100),
        d('x1', reps: 1),
        d('x7', reps: 7),
        d('x3', reps: 3),
      ]),
      ['x1', 'x3', 'x7', 'x100'],
    );
  });

  test('long dua with 3 reps stays in the long band', () {
    expect(
      sortedIds([
        d('long-3x', form: DhikrForm.long, reps: 3, tier: BenefitTier.protection),
        d('short-100x', reps: 100),
      ]),
      ['short-100x', 'long-3x'],
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
