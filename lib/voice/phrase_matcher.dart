import '../models/dhikr.dart';
import 'arabic_normalizer.dart';

/// One phrase the matcher may recognise, and the dhikr saying it counts for.
///
/// A dhikr can contribute several candidates: a compound count says different
/// words in each of its runs (33 × سبحان الله, then 33 × الحمد لله, …), and
/// any of them counts as reciting that dhikr — exactly as any tap does.
/// Beyond this the audio is cut by the detector's own speech-length limit, so
/// searching for longer runs inside one utterance finds nothing.
const maxRunInOneSegment = 12;

/// Closing words used to tell that a one-time dhikr has been finished.
///
/// Four, from the corpus: at two words `me-11` and `me-16` end identically
/// ("إلا أنت"), as do `pp-70` and `pp-71` ("كل صلاة"); at three they still
/// score 0.71–0.76 against each other. At four no pair anywhere comes within
/// 0.7 of another.
const endingWords = 4;

/// How closely the closing words must match. Well above the whole-phrase bar:
/// four words carry far less evidence than a whole dua, so they have to be
/// nearly right.
const endingThreshold = 0.8;

/// Shorter than this and a dhikr matches whole anyway, and its "ending" would
/// be most of it rather than the end of it.
///
/// Twelve because the corpus divides there: the one-time duas run 4, 6, 7, 9,
/// 9, 10, 11 words — each a single breath that no pause will cut — and then
/// jump to 14 and upwards. Only the long ones need rescuing, and at 14 words a
/// four-word ending is the last quarter rather than half the dua.
const endingMinWords = 12;

class PhraseCandidate {
  final String dhikrId;
  final String normalized;

  /// How many times in a row this phrase could legitimately be said. A run of
  /// quick tasbih comes back as one segment rather than one per repetition, so
  /// the matcher looks for the phrase repeated — but only as far as the dhikr
  /// itself asks for, which is 1 for an ordinary dua and no search at all.
  final int maxRun;

  /// The last [endingWords] words, for a long dhikr said once. Hearing them is
  /// taken as having finished it, which rescues a long dua whose middle the
  /// recogniser mangled or whose recitation the detector cut in two. Null for
  /// anything repeated or short enough to match whole.
  final String? ending;

  PhraseCandidate._({
    required this.dhikrId,
    required this.normalized,
    required this.maxRun,
    required this.ending,
  });

  factory PhraseCandidate({
    required String dhikrId,
    required String text,
    int maxRun = 1,
    bool canFinishEarly = false,
  }) {
    final normalized = stripOptionalOpeners(normalizeArabic(text));
    final words = normalized.isEmpty ? const <String>[] : normalized.split(' ');
    return PhraseCandidate._(
      dhikrId: dhikrId,
      normalized: normalized,
      maxRun: maxRun,
      ending: canFinishEarly && words.length > endingMinWords
          ? words.sublist(words.length - endingWords).join(' ')
          : null,
    );
  }
}

class PhraseMatch {
  final String dhikrId;

  /// How close the utterance was, 0..1. Worth surfacing in the dev-flavour
  /// evaluation harness; the app itself only cares that it cleared the bar.
  final double score;

  /// How many recitations the utterance was worth — more than one when the
  /// phrase was repeated without a long enough pause to split the audio.
  final int repetitions;

  /// True when this was recognised by its closing words rather than as a
  /// whole. Surfaced in the debug bar, since it is a weaker kind of evidence.
  final bool byEnding;

  const PhraseMatch(
    this.dhikrId,
    this.score, {
    this.repetitions = 1,
    this.byEnding = false,
  });
}

/// Decides which dhikr an utterance was, out of the ones still left to recite.
///
/// This is deliberately a closed-set decision rather than transcription: the
/// question is only ever "which of these, or none", which survives a far
/// worse acoustic signal than open-vocabulary recognition would.
class PhraseMatcher {
  /// Provisional, set from the corpus alone: unrelated Arabic speech scores at
  /// most ~0.36 against these phrases, while a shortened but legitimate form
  /// ("اللهم صل على محمد" for me-29) scores 0.61 — so the bar sits in the gap,
  /// nearer the noise. The evaluation harness retunes it against real
  /// recogniser output, where every score drops.
  static const defaultThreshold = 0.55;

  /// In the session's own order. Two dhikrs can be word-for-word identical —
  /// me-28 at 10× and me-32 at 100× are the same phrase — and no audio can
  /// separate them, so the earlier one wins and therefore fills first.
  final List<PhraseCandidate> candidates;

  const PhraseMatcher(this.candidates);

  /// The phrases [dhikrs] can be recited as, in the order given — which must
  /// be the session's own order, holding only what is left to do.
  ///
  /// Short Quranic passages take part: an ayah or a short surah is a fixed
  /// phrase like any other dhikr. The two full surahs read from the mushaf at
  /// bedtime do not — following a thirty-ayah recitation is a different problem
  /// — and they have already opted out via [Dhikr.isRecitable], along with the
  /// narration card whose text is not something you say.
  factory PhraseMatcher.forDhikrs(Iterable<Dhikr> dhikrs) {
    final candidates = <PhraseCandidate>[];
    for (final dhikr in dhikrs) {
      if (!dhikr.isRecitable) continue;
      final segmented = dhikr.reciteSegments.isNotEmpty;
      final phrases = segmented ? dhikr.reciteSegments : [dhikr.spokenText];
      for (var i = 0; i < phrases.length; i++) {
        // Each run of a compound count has its own length: 33 tasbihat, then
        // 33 tahmidat, then a single tahlil to round out the hundred.
        final wanted = segmented ? dhikr.segments![i] : dhikr.repetitions;
        candidates.add(PhraseCandidate(
          dhikrId: dhikr.id,
          text: phrases[i],
          maxRun: wanted < maxRunInOneSegment ? wanted : maxRunInOneSegment,
          // Only something said once can be finished by reaching its end; a
          // count has to be reached repetition by repetition.
          canFinishEarly: !segmented && dhikr.repetitions == 1,
        ));
      }
    }
    return PhraseMatcher(candidates);
  }

  /// The dhikr [transcript] should count for, or null when nothing cleared
  /// [threshold] — a cough, a passing conversation, a dhikr from another
  /// session. Silence is the right answer to those.
  PhraseMatch? match(String transcript, {double threshold = defaultThreshold}) {
    final candidate = best(transcript);
    if (candidate != null && candidate.score > threshold) return candidate;
    // Nothing matched as a whole. A long dua said once may still have been
    // finished — its middle mangled, or its recitation cut in two — so look
    // for its closing words.
    return _finishedByEnding(transcript);
  }

  /// A one-time dhikr whose closing words were just said.
  ///
  /// Reached only after every whole-phrase comparison has already failed,
  /// which is what keeps it safe: a short dhikr recited properly matches whole
  /// and never gets here.
  PhraseMatch? _finishedByEnding(String transcript) {
    final heard = stripOptionalOpeners(normalizeArabic(transcript));
    if (heard.isEmpty) return null;
    final words = heard.split(' ');
    final tail = words.length <= endingWords
        ? heard
        : words.sublist(words.length - endingWords).join(' ');

    String? bestId;
    var bestScore = endingThreshold;
    for (final candidate in candidates) {
      final ending = candidate.ending;
      if (ending == null) continue;
      final score = similarity(tail, ending, floor: bestScore);
      if (score > bestScore) {
        bestScore = score;
        bestId = candidate.dhikrId;
      }
    }
    return bestId == null
        ? null
        : PhraseMatch(bestId, bestScore, byEnding: true);
  }

  /// The closest candidate whatever its score, even a hopeless one.
  ///
  /// [match] throws this away, which is right for counting and useless for
  /// diagnosis: a near miss and never having heard anything look identical
  /// from the outside. The debug bar shows this so the two can be told apart.
  PhraseMatch? best(String transcript) {
    final heard = stripOptionalOpeners(normalizeArabic(transcript));
    if (heard.isEmpty) return null;
    String? bestId;
    var bestScore = 0.0;
    var bestRun = 1;
    for (final candidate in candidates) {
      if (candidate.normalized.isEmpty) continue;
      for (final run in _runsToTry(heard, candidate)) {
        final phrase = run == 1
            ? candidate.normalized
            : List.filled(run, candidate.normalized).join(' ');
        // Only a strict improvement displaces the incumbent, which is what
        // makes the earliest of several equal candidates win.
        final score = similarity(heard, phrase, floor: bestScore);
        if (score > bestScore) {
          bestScore = score;
          bestId = candidate.dhikrId;
          bestRun = run;
        }
      }
    }
    return bestId == null
        ? null
        : PhraseMatch(bestId, bestScore, repetitions: bestRun);
  }

  /// Repetition counts worth testing for [candidate] against [heard]: the one
  /// its length implies, and its neighbours in case a word was lost or gained.
  /// Never more than the dhikr actually asks for.
  static Iterable<int> _runsToTry(String heard, PhraseCandidate candidate) {
    if (candidate.maxRun <= 1) return const [1];
    final unit = candidate.normalized.length + 1;
    final estimate = ((heard.length + 1) / unit).round();
    return {
      for (var run = estimate - 1; run <= estimate + 1; run++)
        if (run >= 1 && run <= candidate.maxRun) run,
      1,
    };
  }
}

/// Similarity of two normalised strings in 0..1: `1 - editDistance / length`
/// of the longer one.
///
/// Character level rather than word level on purpose. A recogniser that hears
/// "والحمد" for "الحمد" should lose one character, not a whole word — while a
/// genuinely absent word still costs its full length. That asymmetry is what
/// separates a stumble from a different dhikr, and it is why reciting only the
/// opening of a long dhikr does not match it: سبحان الله وبحمده scores 1.0
/// against me-34 and far below the threshold against me-31, which continues
/// عدد خلقه ورضا نفسه.
///
/// [floor] is the score to beat; a candidate that provably cannot is
/// abandoned without finishing the comparison.
double similarity(String a, String b, {double floor = 0}) {
  if (a == b) return 1;
  final longest = a.length > b.length ? a.length : b.length;
  if (longest == 0) return 1;
  // Edit distance is never less than the length difference, so a candidate of
  // the wrong size cannot clear the floor and needs no comparison at all.
  final budget = ((1 - floor) * longest).floor();
  if ((a.length - b.length).abs() > budget) return 0;
  final distance = _levenshtein(a, b, budget);
  return distance == null ? 0 : 1 - distance / longest;
}

/// Levenshtein distance, or null once every alignment in flight already costs
/// more than [budget].
int? _levenshtein(String a, String b, int budget) {
  var previous = List<int>.generate(b.length + 1, (i) => i);
  var current = List<int>.filled(b.length + 1, 0);
  for (var i = 1; i <= a.length; i++) {
    current[0] = i;
    var rowMin = i;
    final aChar = a.codeUnitAt(i - 1);
    for (var j = 1; j <= b.length; j++) {
      final substitute = previous[j - 1] + (aChar == b.codeUnitAt(j - 1) ? 0 : 1);
      final delete = previous[j] + 1;
      final insert = current[j - 1] + 1;
      var best = substitute < delete ? substitute : delete;
      if (insert < best) best = insert;
      current[j] = best;
      if (best < rowMin) rowMin = best;
    }
    if (rowMin > budget) return null;
    final finished = previous;
    previous = current;
    current = finished;
  }
  return previous[b.length];
}
