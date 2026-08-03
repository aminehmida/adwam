/// Folds Arabic to the form voice matching compares in: what a speech
/// recogniser can be expected to agree on, and nothing finer.
///
/// Recognisers do not reliably emit tashkeel, and the several written forms of
/// hamza and the alef family are orthographic convention rather than sound.
/// Comparing raw text would punish an engine for hearing the pronunciation
/// correctly, which is the only thing being asked of it. Everything folded
/// away here is inaudible.
library;

/// Tashkeel, Quranic annotation and the tatweel elongation: written, but never
/// sounded as anything a recogniser could emit.
final _unspoken = RegExp('['
    'ؐ-ؚ' // honorific signs
    'ً-ٟ' // tanwin, harakat, shadda, sukun
    'ٰ' //        superscript alef
    'ۖ-ۭ' // waqf marks, ayah roundel, small vowels
    'ـ' //        tatweel
    ']');

/// Letters whose several written forms sound the same.
const _folded = {
  'أ': 'ا',
  'إ': 'ا',
  'آ': 'ا',
  'ٱ': 'ا',
  'ة': 'ه',
  'ى': 'ي',
  'ؤ': 'و',
  'ئ': 'ي',
};

/// Whatever survives that is not an Arabic letter: punctuation, digits, Latin,
/// the ornate Quran brackets.
final _notLetters = RegExp('[^ء-ي ]');

final _runsOfSpace = RegExp(r'\s+');

/// [input] reduced to bare, space-separated Arabic letters.
String normalizeArabic(String input) {
  final folded = StringBuffer();
  for (final rune in input.replaceAll(_unspoken, '').runes) {
    final character = String.fromCharCode(rune);
    folded.write(_folded[character] ?? character);
  }
  return folded
      .toString()
      .replaceAll(_notLetters, ' ')
      .replaceAll(_runsOfSpace, ' ')
      .trim();
}
