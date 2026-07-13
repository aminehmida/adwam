import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:adwam/data/content_repository.dart';
import 'package:adwam/data/prefs_store.dart';
import 'package:adwam/models/dhikr.dart';
import 'package:adwam/state/list_config_controller.dart';

Dhikr d(
  String id,
  BenefitTier tier, {
  int repetitions = 1,
  DhikrForm form = DhikrForm.short,
}) =>
    Dhikr(
      id: id,
      arabic: id,
      repetitions: repetitions,
      form: form,
      tier: tier,
      contexts: const {SessionType.morning},
    );

void main() {
  late PrefsStore store;
  late ContentRepository repo;
  late ListConfigController controller;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = await PrefsStore.open();
    repo = ContentRepository([
      d('p1', BenefitTier.protection),
      d('p2', BenefitTier.protection),
      d('n1', BenefitTier.none, repetitions: 1),
      d('n2', BenefitTier.none, repetitions: 3),
      d('su1', BenefitTier.none, form: DhikrForm.surah),
    ]);
    controller = ListConfigController(store, repo);
  });

  List<String> ids() =>
      controller.listFor(SessionType.morning).map((x) => x.id).toList();

  String customId() =>
      controller.listFor(SessionType.morning).singleWhere((x) => x.isCustom).id;

  test('custom dua pins to the very bottom under the default order', () {
    controller.addCustom(
      arabic: 'اللهم اغفر لي ولوالدي',
      contexts: {SessionType.morning},
    );
    expect(ids(), ['p1', 'p2', 'n1', 'n2', 'su1', customId()]);
  });

  test('custom dua joins its bottom section when a user order exists', () {
    controller.reorder(SessionType.morning, 0, 1); // create a user order
    controller.addCustom(
      arabic: 'دعاء',
      contexts: {SessionType.morning},
    );
    expect(ids(), ['p2', 'p1', 'n1', 'n2', 'su1', customId()]);
  });

  test('custom duas reorder among themselves but stay at the bottom', () {
    controller.addCustom(arabic: 'دعاء أول', contexts: {SessionType.morning});
    controller.addCustom(arabic: 'دعاء ثان', contexts: {SessionType.morning});
    final customs = ids().sublist(5);
    controller.reorder(SessionType.morning, 5, 6); // swap the two duas
    expect(ids().sublist(5), customs.reversed);
    controller.reorder(SessionType.morning, 5, 0); // drag above snaps back
    expect(ids().sublist(0, 5), ['p1', 'p2', 'n1', 'n2', 'su1']);
  });

  test('custom dua only appears in its own sessions', () {
    controller.addCustom(
      arabic: 'دعاء',
      contexts: {SessionType.morning, SessionType.sleep},
    );
    expect(controller.listFor(SessionType.sleep).map((x) => x.id), [
      customId(),
    ]);
    expect(controller.listFor(SessionType.evening), isEmpty);
  });

  test('custom duas survive a controller reload', () {
    controller.addCustom(
      arabic: 'اللهم اغفر لي',
      contexts: {SessionType.morning},
    );
    final reloaded = ListConfigController(store, repo);
    final custom = reloaded
        .listFor(SessionType.morning)
        .singleWhere((x) => x.isCustom);
    expect(custom.arabic, 'اللهم اغفر لي');
    expect(custom.repetitions, 1);
    expect(custom.contexts, {SessionType.morning});
  });

  test('updateCustom edits the text and places the dua in new sessions', () {
    controller.addCustom(
      arabic: 'دعاء',
      contexts: {SessionType.morning},
    );
    final id = customId();
    controller.updateCustom(
      id,
      arabic: 'دعاء آخر',
      contexts: {SessionType.morning, SessionType.evening},
    );
    expect(
      controller
          .listFor(SessionType.morning)
          .singleWhere((x) => x.isCustom)
          .arabic,
      'دعاء آخر',
    );
    expect(controller.listFor(SessionType.evening).map((x) => x.id), [id]);
  });

  test('removeCustom scrubs the id from order and hidden', () {
    controller.reorder(SessionType.morning, 0, 1); // create a user order
    controller.addCustom(
      arabic: 'دعاء',
      contexts: {SessionType.morning},
    );
    final id = customId();
    controller.setHidden(SessionType.morning, id, true);
    controller.removeCustom(id);
    expect(ids(), ['p2', 'p1', 'n1', 'n2', 'su1']);
    final config = controller.configFor(SessionType.morning);
    expect(config.order, isNot(contains(id)));
    expect(config.hidden, isNot(contains(id)));
  });
}
