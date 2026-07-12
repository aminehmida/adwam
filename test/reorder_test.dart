import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:adwam/data/content_repository.dart';
import 'package:adwam/data/prefs_store.dart';
import 'package:adwam/models/dhikr.dart';
import 'package:adwam/state/list_config_controller.dart';

Dhikr d(String id, BenefitTier tier) => Dhikr(
      id: id,
      arabic: id,
      repetitions: 1,
      form: DhikrForm.short,
      tier: tier,
      contexts: const {SessionType.morning},
    );

void main() {
  late ListConfigController controller;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final repo = ContentRepository([
      d('p1', BenefitTier.protection),
      d('p2', BenefitTier.protection),
      d('r1', BenefitTier.reward),
      d('n1', BenefitTier.none),
      d('n2', BenefitTier.none),
    ]);
    controller = ListConfigController(await PrefsStore.open(), repo);
  });

  List<String> ids() =>
      controller.listFor(SessionType.morning).map((x) => x.id).toList();

  test('reorder within a tier section works', () {
    controller.reorder(SessionType.morning, 0, 1); // p1 after p2
    expect(ids(), ['p2', 'p1', 'r1', 'n1', 'n2']);
  });

  test('drop below the section snaps back to its end', () {
    controller.reorder(SessionType.morning, 0, 4); // p1 dragged to the bottom
    expect(ids(), ['p2', 'p1', 'r1', 'n1', 'n2']);
  });

  test('drop above the section snaps back to its start', () {
    controller.reorder(SessionType.morning, 4, 0); // n2 dragged to the top
    expect(ids(), ['p1', 'p2', 'r1', 'n2', 'n1']);
  });

  test('single-item section cannot move at all', () {
    controller.reorder(SessionType.morning, 2, 0);
    expect(ids(), ['p1', 'p2', 'r1', 'n1', 'n2']);
  });
}
