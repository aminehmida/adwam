import 'package:flutter_test/flutter_test.dart';

import 'package:adwam/data/content_repository.dart';
import 'package:adwam/models/dhikr.dart';
import 'package:adwam/voice/arabic_normalizer.dart';
import 'package:adwam/voice/phrase_matcher.dart';

/// Matching is exercised against the real corpus, because the cases that
/// actually decide the design — two dhikrs with identical text, one that is a
/// prefix of another — exist only there.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ContentRepository repo;
  late Map<String, Dhikr> byId;

  setUpAll(() async {
    repo = await ContentRepository.load();
    byId = {for (final d in repo.all) d.id: d};
  });

  group('normalisation', () {
    test('drops what is written but never sounded', () {
      expect(normalizeArabic('سُبْحَانَ اللَّهِ وَبِحَمْدِهِ'),
          'سبحان الله وبحمده');
      expect(normalizeArabic('قُلْ هُوَ ٱللَّهُ أَحَدٌ ۝١'), 'قل هو الله احد');
    });

    test('folds the written forms of a single sound together', () {
      expect(normalizeArabic('أحمد'), normalizeArabic('احمد'));
      expect(normalizeArabic('إله'), normalizeArabic('اله'));
      expect(normalizeArabic('رحمة'), normalizeArabic('رحمه'));
      expect(normalizeArabic('على'), normalizeArabic('علي'));
    });

    test('collapses punctuation and spacing', () {
      expect(normalizeArabic('  لا إله،   إلا الله.  '), 'لا اله الا الله');
    });
  });

  group('similarity', () {
    test('is 1 for the same text and 0 for nothing in common', () {
      expect(similarity('سبحان الله', 'سبحان الله'), 1);
      expect(similarity('سبحان الله', 'كتب'), lessThan(0.3));
    });

    test('costs a misheard letter far less than a missing word', () {
      const truth = 'الحمد لله رب العالمين';
      final letter = similarity(normalizeArabic('الحمد لله رب العالمون'), truth);
      final word = similarity(normalizeArabic('الحمد لله رب'), truth);
      expect(letter, greaterThan(0.9));
      expect(word, lessThan(letter));
    });
  });

  group('matching a session', () {
    /// Everything still to recite in a session, in the session's own order.
    PhraseMatcher matcherFor(SessionType session, {Set<String> done = const {}}) =>
        PhraseMatcher.forDhikrs(
            repo.defaultList(session).where((d) => !done.contains(d.id)));

    test('a clean recitation matches its own dhikr', () {
      final matcher = matcherFor(SessionType.morning);
      final match = matcher.match(byId['me-33']!.spokenText);
      expect(match?.dhikrId, 'me-33');
      expect(match!.score, 1);
    });

    test('a stumbled recitation still matches', () {
      // sl-104 is اللهم قني عذابك يوم تبعث عبادك. Here: no tashkeel (no
      // recogniser emits it reliably), يوم dropped, and تبعث misheard as
      // تبعت — roughly what a degraded transcript looks like.
      final matcher = matcherFor(SessionType.sleep);
      expect(matcher.match('اللهم قني عذابك تبعت عبادك')?.dhikrId, 'sl-104');
    });

    test('a shortened but legitimate salawat still counts', () {
      // me-29 is اللهم صل وسلم على نبينا محمد; people commonly say the
      // shorter form. It scores 0.61 — the threshold has to sit below that.
      final matcher = matcherFor(SessionType.morning);
      expect(matcher.match('اللهم صل على محمد')?.dhikrId, 'me-29');
    });

    test('the post-prayer tahlil beats the near-identical one beside it', () {
      // pp-72 is pp-69's closing tahlil plus يحيي ويميت — 0.86 similar, the
      // tightest real contest in the corpus. Each must still win its own.
      final matcher = matcherFor(SessionType.postPrayer);
      expect(matcher.match(byId['pp-72']!.spokenText)?.dhikrId, 'pp-72');
      expect(matcher.match(byId['pp-69']!.reciteSegments.last)?.dhikrId,
          'pp-69');
    });

    test('speech that is not in the session matches nothing', () {
      final matcher = matcherFor(SessionType.morning);
      expect(matcher.match('ما رأيك في الطقس اليوم'), isNull);
      expect(matcher.match(''), isNull);
      // A sleep-only dhikr recited during the morning session.
      expect(matcher.match(byId['sl-105']!.spokenText), isNull);
    });

    test('reciting the opening of a longer dhikr matches the short one, '
        'and reciting it in full matches the long one', () {
      // me-34 (100×) is word-for-word the opening of me-31 (3×).
      final matcher = matcherFor(SessionType.morning);
      expect(matcher.match(byId['me-34']!.spokenText)?.dhikrId, 'me-34');
      expect(matcher.match(byId['me-31']!.spokenText)?.dhikrId, 'me-31');
    });

    test('of two identical dhikrs the earlier one fills first', () {
      // me-28 (10×) and me-32 (100×) are the same phrase; nothing in the
      // audio can tell them apart, so list order decides.
      final morning = repo.defaultList(SessionType.morning);
      expect(byId['me-28']!.spokenText, byId['me-32']!.spokenText);
      expect(morning.indexWhere((d) => d.id == 'me-28'),
          lessThan(morning.indexWhere((d) => d.id == 'me-32')));

      final matcher = matcherFor(SessionType.morning);
      expect(matcher.match(byId['me-28']!.spokenText)?.dhikrId, 'me-28');

      // Once the 10× is done it leaves the candidate set, and the same words
      // start filling the 100×.
      final afterwards = matcherFor(SessionType.morning, done: {'me-28'});
      expect(afterwards.match(byId['me-28']!.spokenText)?.dhikrId, 'me-32');
    });

    test('any phrase of a compound count counts for it', () {
      // pp-69 is 33 × سبحان الله, 33 × الحمد لله, 33 × الله أكبر, then one
      // tahlil — every run says different words, all of them the same card.
      final matcher = matcherFor(SessionType.postPrayer);
      for (final phrase in byId['pp-69']!.reciteSegments) {
        expect(matcher.match(phrase)?.dhikrId, 'pp-69', reason: phrase);
      }
    });

    test('a quick run of tasbih in one breath counts every repetition', () {
      // The detector cuts on silence, so saying سبحان الله four times without
      // pausing arrives as a single utterance — worth four, not one.
      final matcher = matcherFor(SessionType.morning);
      final once = byId['me-34']!.spokenText;
      final match = matcher.match(List.filled(4, once).join(' '));
      expect(match?.dhikrId, 'me-34');
      expect(match?.repetitions, 4);
    });

    test('a dhikr said once is never counted as a run', () {
      // sl-105 is recited once, so no repeat search happens for it at all.
      final matcher = matcherFor(SessionType.sleep);
      final single = byId['sl-105']!.spokenText;
      expect(matcher.match(single)?.repetitions, 1);
      // Even hearing it twice cannot count it twice.
      expect(matcher.match('$single $single')?.repetitions, anyOf(isNull, 1));
    });

    test('Quran passages stay out of voice matching', () {
      final candidates = PhraseMatcher.forDhikrs(
          repo.defaultList(SessionType.morning)).candidates;
      final quranIds = repo
          .defaultList(SessionType.morning)
          .where((d) => d.form == DhikrForm.quran)
          .map((d) => d.id);
      expect(quranIds, isNotEmpty);
      for (final id in quranIds) {
        expect(candidates.map((c) => c.dhikrId), isNot(contains(id)));
      }
    });
  });
}
