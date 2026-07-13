import 'package:flutter_test/flutter_test.dart';

import 'package:adwam/data/content_repository.dart';
import 'package:adwam/models/dhikr.dart';

/// Validates the real assets/adhkar.json produced by tool/build_content.py,
/// so a bad pipeline run fails CI instead of crashing the app at startup.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ContentRepository repo;

  setUpAll(() async {
    repo = await ContentRepository.load();
  });

  test('bundled content parses and is non-trivial', () {
    expect(repo.all.length, greaterThan(30));
  });

  test('ids are unique', () {
    final ids = repo.all.map((d) => d.id).toList();
    expect(ids.toSet().length, ids.length);
  });

  test('every dhikr has Arabic text, valid repetitions and a context', () {
    for (final d in repo.all) {
      expect(d.arabic.trim(), isNotEmpty, reason: d.id);
      expect(d.repetitions, greaterThanOrEqualTo(1), reason: d.id);
      expect(d.contexts, isNotEmpty, reason: d.id);
    }
  });

  test('a benefit tier implies benefit text with a source', () {
    for (final d in repo.all.where((d) => d.tier != BenefitTier.none)) {
      expect(d.benefit, isNotNull, reason: d.id);
      expect(d.benefitSource, isNotNull, reason: d.id);
    }
  });

  test('every session has content in each display band it relies on', () {
    for (final session in SessionType.values) {
      expect(repo.defaultList(session), isNotEmpty, reason: session.name);
    }
  });

  test('full surahs form a contiguous block, trailed only by the '
      'high-repetition section', () {
    for (final session in SessionType.values) {
      final list = repo.defaultList(session);
      final firstSurah = list.indexWhere((d) => d.form == DhikrForm.surah);
      if (firstSurah == -1) continue;
      final lastSurah = list.lastIndexWhere((d) => d.form == DhikrForm.surah);
      // No non-surah wedged inside the surah run.
      expect(
        list
            .getRange(firstSurah, lastSurah + 1)
            .every((d) => d.form == DhikrForm.surah),
        isTrue,
        reason: session.name,
      );
      // Only high-repetition dhikrs may follow the surahs.
      expect(
        list.skip(lastSurah + 1).every((d) => d.isHighRep),
        isTrue,
        reason: session.name,
      );
    }
  });

  test('the high-repetition run sinks to the end and orders its tiers '
      'protection → reward → none, except where a fixed sunnah sequence '
      'pins every entry', () {
    for (final session in SessionType.values) {
      final list = repo.defaultList(session);
      final highReps = list.where((d) => d.isHighRep).toList();
      if (highReps.isEmpty) continue;
      // A fixed_order session (the post-prayer sunnah sequence) keeps its
      // dhikrs in place, so the high-rep run need not be contiguous or last.
      if (list.first.fixedOrder == noFixedOrder) {
        final firstHigh = list.indexWhere((d) => d.isHighRep);
        expect(
          list.skip(firstHigh).every((d) => d.isHighRep),
          isTrue,
          reason: session.name,
        );
        // Non-decreasing tier index: protection (0), reward (1), none (2).
        for (var i = 1; i < highReps.length; i++) {
          expect(
            highReps[i].tier.index,
            greaterThanOrEqualTo(highReps[i - 1].tier.index),
            reason: session.name,
          );
        }
      }
    }
  });

}
