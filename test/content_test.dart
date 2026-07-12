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

  test('full surahs really are at the end of every session list', () {
    for (final session in SessionType.values) {
      final list = repo.defaultList(session);
      final firstSurah = list.indexWhere((d) => d.form == DhikrForm.surah);
      if (firstSurah == -1) continue;
      expect(
        list.skip(firstSurah).every((d) => d.form == DhikrForm.surah),
        isTrue,
        reason: session.name,
      );
    }
  });

}
