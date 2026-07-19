import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:adwam/data/content_repository.dart';
import 'package:adwam/data/prefs_store.dart';
import 'package:adwam/models/dhikr.dart';
import 'package:adwam/state/list_config_controller.dart';
import 'package:adwam/state/settings_controller.dart';

/// The three Quls ship as both a per-surah set and a combined card; the
/// bundleThreeQuls setting picks which shape each session shows.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ContentRepository repo;
  setUpAll(() async => repo = await ContentRepository.load());

  Future<(ListConfigController, SettingsController)> build() async {
    SharedPreferences.setMockInitialValues({});
    final store = await PrefsStore.open();
    final settings = SettingsController(store);
    return (ListConfigController(store, repo, settings), settings);
  }

  List<String> ids(ListConfigController c, SessionType s) =>
      c.listFor(s).map((d) => d.id).toList();

  const separate = ['me-04', 'me-05', 'me-06'];
  const ppSeparate = ['pp-70a', 'pp-70b', 'pp-70c'];

  test('default is separate: one card per Qul, no combined card', () async {
    final (config, settings) = await build();
    expect(settings.bundleThreeQuls, isFalse);
    for (final s in [SessionType.morning, SessionType.evening]) {
      final list = ids(config, s);
      // Contiguous and in mushaf order.
      final i = list.indexOf('me-04');
      expect(list.sublist(i, i + 3), separate, reason: s.name);
      expect(list, isNot(contains('me-quls')), reason: s.name);
    }
    final pp = ids(config, SessionType.postPrayer);
    final j = pp.indexOf('pp-70a');
    expect(pp.sublist(j, j + 3), ppSeparate);
    expect(pp, isNot(contains('pp-70')));
  });

  test('bundle: the combined card replaces the separate ones', () async {
    final (config, settings) = await build();
    settings.setBundleThreeQuls(true);
    for (final s in [SessionType.morning, SessionType.evening]) {
      final list = ids(config, s);
      expect(list, contains('me-quls'), reason: s.name);
      expect(list.any(separate.contains), isFalse, reason: s.name);
    }
    final pp = ids(config, SessionType.postPrayer);
    expect(pp, contains('pp-70'));
    expect(pp.any(ppSeparate.contains), isFalse);
  });

  test('toggling the setting notifies the list controller', () async {
    final (config, settings) = await build();
    var notified = 0;
    config.addListener(() => notified++);
    settings.setBundleThreeQuls(true);
    expect(notified, greaterThan(0));
  });

  test('with a saved custom order, switching to bundle drops the combined '
      'card into the trio slot, not at the end', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await PrefsStore.open();
    final settings = SettingsController(store);
    final config = ListConfigController(store, repo, settings);
    // Persist a custom order for morning (as a reorder would): the exact
    // current separate-mode order.
    final saved = config.listFor(SessionType.morning).map((d) => d.id).toList();
    config.reorder(SessionType.morning, 0, 0); // no-op move that saves order
    expect(config.configFor(SessionType.morning).order, isNotEmpty);

    settings.setBundleThreeQuls(true);
    final list = config.listFor(SessionType.morning).map((d) => d.id).toList();
    expect(list, contains('me-quls'));
    expect(list.last, isNot('me-quls')); // not dumped at the end
    // It sits exactly where me-04 stood.
    expect(list.indexOf('me-quls'), saved.indexOf('me-04'));
  });

  test('sleep is untouched by the setting: same list either way, and it '
      'holds the ruqyah card, never the Qul variants', () async {
    final (config, settings) = await build();
    final whenSeparate = ids(config, SessionType.sleep);
    settings.setBundleThreeQuls(true);
    final whenBundle = ids(config, SessionType.sleep);
    expect(whenBundle, whenSeparate);
    expect(whenSeparate, contains('sl-99'));
    expect(whenSeparate.any((id) => [...separate, ...ppSeparate, 'me-quls', 'pp-70']
        .contains(id)), isFalse);
  });
}
