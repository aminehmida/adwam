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

class PhraseCandidate {
  final String dhikrId;
  final String normalized;

  /// How many times in a row this phrase could legitimately be said. A run of
  /// quick tasbih comes back as one segment rather than one per repetition, so
  /// the matcher looks for the phrase repeated — but only as far as the dhikr
  /// itself asks for, which is 1 for an ordinary dua and no search at all.
  final int maxRun;

  PhraseCandidate({
    required this.dhikrId,
    required String text,
    this.maxRun = 1,
  }) : normalized = normalizeArabic(text);
}

class PhraseMatch {
  final String dhikrId;

  /// How close the utterance was, 0..1. Worth surfacing in the dev-flavour
  /// evaluation harness; the app itself only cares that it cleared the bar.
  final double score;

  /// How many recitations the utterance was worth — more than one when the
  /// phrase was repeated without a long enough pause to split the audio.
  final int repetitions;

  const PhraseMatch(this.dhikrId, this.score, {this.repetitions = 1});
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
  /// Quran passages are left out: following recitation of an ayah against the
  /// mushaf is a different problem from recognising a fixed dhikr phrase, and
  /// those cards stay tap-driven. Cards whose Arabic is not something you say
  /// have already opted out via [Dhikr.isRecitable].
  factory PhraseMatcher.forDhikrs(Iterable<Dhikr> dhikrs) {
    final candidates = <PhraseCandidate>[];
    for (final dhikr in dhikrs) {
      if (!dhikr.isRecitable || dhikr.form == DhikrForm.quran) continue;
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
        ));
      }
    }
    return PhraseMatcher(candidates);
  }

  /// The best candidate for [transcript], or null if nothing cleared
  /// [threshold] — a cough, a passing conversation, or a dhikr from another
  /// session. Silence is the right answer to those.
  PhraseMatch? match(String transcript, {double threshold = defaultThreshold}) {
    final heard = normalizeArabic(transcript);
    if (heard.isEmpty) return null;
    String? bestId;
    var bestScore = threshold;
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
