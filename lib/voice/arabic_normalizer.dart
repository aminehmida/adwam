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

/// Openings that may be said before a passage or left out, in any
/// combination, without changing which passage it is.
///
/// Already normalised, since they are only ever compared against normalised
/// text. The isti'adha has a longer form some readers use.
const _optionalOpeners = [
  'اعوذ بالله السميع العليم من الشيطان الرجيم',
  'اعوذ بالله من الشيطان الرجيم',
  'بسم الله الرحمن الرحيم',
];

/// Drops any isti'adha and basmala from the front of already-normalised text.
///
/// Whether a reader says one, both or neither is a matter of custom, not of
/// which dhikr it is, so both sides of a comparison have them removed and the
/// question never arises. Only a *complete* opener is stripped — me-20 begins
/// "بسم الله الذي لا يضر" and must keep its words.
///
/// Text that is nothing but openers is returned untouched: something has to be
/// left to compare.
String stripOptionalOpeners(String normalized) {
  var text = normalized;
  for (var pass = 0; pass < _optionalOpeners.length; pass++) {
    final before = text;
    for (final opener in _optionalOpeners) {
      if (text == opener) return normalized;
      if (text.startsWith('$opener ')) {
        text = text.substring(opener.length + 1);
        break;
      }
    }
    if (before == text) break;
  }
  return text.isEmpty ? normalized : text;
}

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
