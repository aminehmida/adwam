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

    test('the isti\'adha and basmala may be said, or left out, or both', () {
      final matcher = matcherFor(SessionType.morning);
      // me-02 is written with the isti'adha in front of Ayat al-Kursi.
      final written = normalizeArabic(byId['me-02']!.spokenText);
      final ayahOnly = stripOptionalOpeners(written);
      expect(ayahOnly, isNot(written), reason: 'me-02 should carry an opener');

      for (final spoken in [
        written, // as written
        ayahOnly, // straight into the ayah
        'بسم الله الرحمن الرحيم $ayahOnly', // basmala instead
        'اعوذ بالله من الشيطان الرجيم بسم الله الرحمن الرحيم $ayahOnly', // both
      ]) {
        final match = matcher.match(spoken);
        expect(match?.dhikrId, 'me-02', reason: spoken);
        expect(match!.score, 1, reason: spoken);
      }
    });

    test('a dhikr that merely begins "bismillah" keeps its words', () {
      // me-20 opens بسم الله الذي لا يضر — the basmala's first two words but
      // not the basmala, so nothing may be stripped from it.
      final matcher = matcherFor(SessionType.morning);
      final match = matcher.match(byId['me-20']!.spokenText);
      expect(match?.dhikrId, 'me-20');
      expect(match!.score, 1);
    });

    test('hearing the closing words finishes a long one-time dua', () {
      // me-11 (sayyid al-istighfar) ends فإنه لا يغفر الذنوب إلا أنت. Its
      // middle may be mangled or cut away; the ending still finishes it.
      final matcher = matcherFor(SessionType.morning);
      final words = normalizeArabic(byId['me-11']!.spokenText).split(' ');
      final tail = words.sublist(words.length - endingWords).join(' ');

      final match = matcher.match(tail);
      expect(match?.dhikrId, 'me-11');
      expect(match?.byEnding, isTrue);
    });

    test('a whole recitation is never credited to the ending shortcut', () {
      final matcher = matcherFor(SessionType.morning);
      final match = matcher.match(byId['me-11']!.spokenText);
      expect(match?.dhikrId, 'me-11');
      expect(match?.byEnding, isFalse);
    });

    test('the ending shortcut is only for dhikrs said once', () {
      // me-17 is 7×: reaching its end says nothing about having done seven.
      final matcher = matcherFor(SessionType.morning);
      final repeated = matcher.candidates.firstWhere((c) => c.dhikrId == 'me-17');
      expect(repeated.ending, isNull);
      // And a one-breath dua has no ending either — nothing will cut it in
      // half, and it matches whole.
      final short = matcher.candidates.firstWhere((c) => c.dhikrId == 'me-27');
      expect(short.ending, isNull);
      // A long one does.
      final long = matcher.candidates.firstWhere((c) => c.dhikrId == 'me-11');
      expect(long.ending, isNotNull);
    });

    test('a near miss is reported even though it is not counted', () {
      // What the debug bar needs: "heard you, scored 0.4" has to be
      // distinguishable from "heard nothing at all".
      final matcher = matcherFor(SessionType.morning);
      const heard = 'ما رأيك في الطقس اليوم';
      expect(matcher.match(heard), isNull);
      final closest = matcher.best(heard);
      expect(closest, isNotNull);
      expect(closest!.score, lessThan(PhraseMatcher.defaultThreshold));
      expect(closest.score, greaterThan(0));
      // Nothing at all still yields nothing.
      expect(matcher.best(''), isNull);
    });

    test('ayat and short surahs are matched like any other phrase', () {
      // A short Quranic passage is a fixed phrase; only the full-surah reading
      // is a different problem.
      final ids = PhraseMatcher.forDhikrs(repo.defaultList(SessionType.morning))
          .candidates
          .map((c) => c.dhikrId);
      expect(ids, contains('me-02')); // Ayat al-Kursi
      expect(ids, contains('me-04')); // al-Ikhlas
    });

    test('reciting a short surah counts it', () {
      final matcher = matcherFor(SessionType.morning);
      expect(matcher.match(byId['me-04']!.spokenText)?.dhikrId, 'me-04');
      expect(matcher.match(byId['me-06']!.spokenText)?.dhikrId, 'me-06');
    });

    test('the full bedtime surahs and the narration stay out', () {
      // sl-110a/b are read from the mushaf by name, and sl-99 describes an
      // action rather than being a phrase to say.
      final ids = PhraseMatcher.forDhikrs(repo.defaultList(SessionType.sleep))
          .candidates
          .map((c) => c.dhikrId);
      for (final id in ['sl-110a', 'sl-110b', 'sl-99']) {
        expect(ids, isNot(contains(id)), reason: id);
      }
      // But the bedtime ayat do take part.
      expect(ids, contains('sl-100')); // Ayat al-Kursi
    });
  });
}
