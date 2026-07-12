import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:adwam/data/prefs_store.dart';
import 'package:adwam/models/dhikr.dart';
import 'package:adwam/state/progress_controller.dart';

Dhikr _dhikr(String id, {int reps = 3}) => Dhikr(
      id: id,
      arabic: 'ذكر $id',
      repetitions: reps,
      form: DhikrForm.short,
      tier: BenefitTier.none,
      contexts: const {SessionType.morning},
    );

void main() {
  late PrefsStore store;
  late ProgressController controller;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = await PrefsStore.open();
    controller = ProgressController(store);
  });

  test('increment counts up and reports completion on the last tap', () {
    final dhikr = _dhikr('a', reps: 3);
    expect(controller.increment(SessionType.morning, dhikr), isFalse);
    expect(controller.increment(SessionType.morning, dhikr), isFalse);
    expect(controller.countFor(SessionType.morning, 'a'), 2);
    expect(controller.isDone(SessionType.morning, 'a'), isFalse);

    expect(controller.increment(SessionType.morning, dhikr), isTrue);
    expect(controller.isDone(SessionType.morning, 'a'), isTrue);
  });

  test('increment on a done dhikr is a no-op', () {
    final dhikr = _dhikr('a', reps: 1);
    expect(controller.increment(SessionType.morning, dhikr), isTrue);
    expect(controller.increment(SessionType.morning, dhikr), isFalse);
    expect(controller.countFor(SessionType.morning, 'a'), 1);
  });

  test('progress is per session for the same dhikr id', () {
    final dhikr = _dhikr('a', reps: 1);
    controller.increment(SessionType.morning, dhikr);
    expect(controller.isDone(SessionType.morning, 'a'), isTrue);
    expect(controller.isDone(SessionType.evening, 'a'), isFalse);
  });

  test('markDone jumps the count to the target and is idempotent', () {
    final dhikr = _dhikr('a', reps: 100);
    controller.increment(SessionType.morning, dhikr);
    controller.markDone(SessionType.morning, dhikr);
    expect(controller.countFor(SessionType.morning, 'a'), 100);
    expect(controller.isDone(SessionType.morning, 'a'), isTrue);

    var notified = false;
    controller.addListener(() => notified = true);
    controller.markDone(SessionType.morning, dhikr);
    expect(notified, isFalse);
  });

  test('doneCount only counts the given ids', () {
    controller.markDone(SessionType.morning, _dhikr('a'));
    controller.markDone(SessionType.morning, _dhikr('b'));
    expect(controller.doneCount(SessionType.morning, ['a', 'c']), 1);
  });

  test('progress survives a restart via the store', () async {
    controller.markDone(SessionType.morning, _dhikr('a'));

    final revived = ProgressController(await PrefsStore.open());
    expect(revived.isDone(SessionType.morning, 'a'), isTrue);
  });

  test('resetSession clears only that session', () {
    controller.markDone(SessionType.morning, _dhikr('a'));
    controller.increment(SessionType.evening, _dhikr('b'));

    controller.resetSession(SessionType.morning);
    expect(controller.isDone(SessionType.morning, 'a'), isFalse);
    expect(controller.countFor(SessionType.morning, 'a'), 0);
    expect(controller.countFor(SessionType.evening, 'b'), 1);
  });

  test('resetToday clears everything', () {
    controller.markDone(SessionType.morning, _dhikr('a'));
    controller.resetToday();
    expect(controller.isDone(SessionType.morning, 'a'), isFalse);
    expect(controller.countFor(SessionType.morning, 'a'), 0);
  });
}
