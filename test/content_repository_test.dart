import 'package:flutter_test/flutter_test.dart';

import 'package:adwam/data/content_repository.dart';
import 'package:adwam/models/dhikr.dart';

Dhikr d(String id, {BenefitTier tier = BenefitTier.none}) => Dhikr(
      id: id,
      arabic: id,
      repetitions: 1,
      form: DhikrForm.short,
      tier: tier,
      contexts: const {SessionType.morning},
    );

void main() {
  final repo = ContentRepository([
    d('a', tier: BenefitTier.protection),
    d('b', tier: BenefitTier.reward),
    d('c'),
  ]);

  List<String> ordered(List<String> userOrder) => repo
      .orderedList(SessionType.morning, userOrder)
      .map((x) => x.id)
      .toList();

  test('empty user order falls back to default sort', () {
    expect(ordered([]), ['a', 'b', 'c']);
  });

  test('user order wins over default sort', () {
    expect(ordered(['c', 'a', 'b']), ['c', 'a', 'b']);
  });

  test('ids removed by a content update are dropped from the user order', () {
    expect(ordered(['gone', 'c', 'a', 'b']), ['c', 'a', 'b']);
  });

  test('dhikrs missing from the user order merge into their sorted slot', () {
    // 'a' and 'c' were added by a content update after the user reordered.
    // 'a' (protection) slots ahead of the reordered 'b'; 'c' (none) after.
    expect(ordered(['b']), ['a', 'b', 'c']);
  });

  test('defaultList filters by session', () {
    expect(repo.defaultList(SessionType.sleep), isEmpty);
  });
}
