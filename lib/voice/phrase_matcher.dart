import '../models/dhikr.dart';
import 'arabic_normalizer.dart';

/// One phrase the matcher may recognise, and the dhikr saying it counts for.
///
/// A dhikr can contribute several candidates: a compound count says different
/// words in each of its runs (33 × سبحان الله, then 33 × الحمد لله, …), and
/// any of them counts as reciting that dhikr — exactly as any tap does.
class PhraseCandidate {
  final String dhikrId;
  final String normalized;

  PhraseCandidate({required this.dhikrId, required String text})
      : normalized = normalizeArabic(text);
}

class PhraseMatch {
  final String dhikrId;

  /// How close the utterance was, 0..1. Worth surfacing in the dev-flavour
  /// evaluation harness; the app itself only cares that it cleared the bar.
  final double score;

  const PhraseMatch(this.dhikrId, this.score);
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
      final phrases = dhikr.reciteSegments.isEmpty
          ? [dhikr.spokenText]
          : dhikr.reciteSegments;
      for (final phrase in phrases) {
        candidates.add(PhraseCandidate(dhikrId: dhikr.id, text: phrase));
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
    for (final candidate in candidates) {
      if (candidate.normalized.isEmpty) continue;
      // Only a strict improvement displaces the incumbent, which is what
      // makes the earliest of several equal candidates win.
      final score = similarity(heard, candidate.normalized, floor: bestScore);
      if (score > bestScore) {
        bestScore = score;
        bestId = candidate.dhikrId;
      }
    }
    return bestId == null ? null : PhraseMatch(bestId, bestScore);
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
