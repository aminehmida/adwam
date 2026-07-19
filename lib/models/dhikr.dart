/// `surah` = a full surah referenced by name (e.g. سورة الملك before
/// sleep), read from the mushaf — always sorted to the end of a session.
enum DhikrForm { quran, short, long, surah }

enum BenefitTier { protection, reward, none }

enum SessionType { morning, evening, postPrayer, sleep }

const _formNames = {
  'quran': DhikrForm.quran,
  'short': DhikrForm.short,
  'long': DhikrForm.long,
  'surah': DhikrForm.surah,
};

const _tierNames = {
  'protection': BenefitTier.protection,
  'reward': BenefitTier.reward,
  'none': BenefitTier.none,
};

/// Dhikrs without an explicit sort_hint sort after hinted ones.
const noSortHint = 1 << 20;

/// Dhikrs without a fixed_order sort after fixed ones (which never
/// happens in practice: a session either fixes every entry or none).
const noFixedOrder = 1 << 20;

/// Dhikrs repeated at least this many times are grouped into their own
/// "high repetitions" section at the bottom of a session.
const highRepThreshold = 100;

/// Dhikrs repeated at least this many times are counted in the full-screen
/// focus overlay rather than on the card. Lower than [highRepThreshold] so
/// that ordinary tasbih runs (e.g. 7x, 10x, 33x) also open the dedicated
/// counting interface, while list sectioning/sorting stays keyed off the
/// higher threshold.
const focusRepThreshold = 7;

const _sessionNames = {
  'morning': SessionType.morning,
  'evening': SessionType.evening,
  'post_prayer': SessionType.postPrayer,
  'sleep': SessionType.sleep,
};

/// Ids of user-created dhikrs (see ListConfigController.addCustom); the
/// built-in content uses source-derived ids like `me-01`.
const customIdPrefix = 'custom-';

class Dhikr {
  final String id;
  final String arabic;

  /// Full mushaf text (with end-of-ayah markers) of `surah`-form dhikrs,
  /// shown in the reader overlay; [arabic] stays the display name.
  final String? body;
  final int repetitions;

  /// For a compound count (the post-prayer / sleep tasbih) the individual
  /// phrase runs that make up [repetitions], e.g. `[33, 33, 33, 1]`. Null for
  /// a plain single-phrase count. Their sum equals [repetitions].
  final List<int>? segments;
  final DhikrForm form;
  final BenefitTier tier;
  final String? benefit;
  final String? benefitSource;
  final String? benefitEn;
  final String? benefitSourceEn;
  final String? translation;
  final String? transliteration;
  final Set<SessionType> contexts;

  /// Prayers this dhikr is specific to (keys like `fajr`, `maghrib`),
  /// empty for adhkar said after every prayer.
  final List<String> prayers;

  /// When set, [prayers] doesn't restrict the dhikr but raises its count:
  /// said [prayersReps] times after those prayers (e.g. the three Quls,
  /// 3x after Fajr and Maghrib), [repetitions] times otherwise.
  final int? prayersReps;
  final int sortHint;

  /// Explicit position in the session list (e.g. the sunnah sequence of
  /// the post-prayer adhkar). Outranks every heuristic sort rule.
  final int fixedOrder;

  const Dhikr({
    required this.id,
    required this.arabic,
    this.body,
    required this.repetitions,
    this.segments,
    required this.form,
    required this.tier,
    this.benefit,
    this.benefitSource,
    this.benefitEn,
    this.benefitSourceEn,
    this.translation,
    this.transliteration,
    required this.contexts,
    this.prayers = const [],
    this.prayersReps,
    this.sortHint = noSortHint,
    this.fixedOrder = noFixedOrder,
  });

  /// Final sort tiebreak: shorter text first among otherwise equal dhikrs.
  int get wordCount => arabic.trim().split(RegExp(r'\s+')).length;

  /// Repeated enough times to belong in the high-repetitions section.
  bool get isHighRep => repetitions >= highRepThreshold;

  /// Repeated enough times to be counted in the full-screen focus overlay
  /// (the dedicated counting interface) rather than on the card.
  bool get isFocusable => repetitions >= focusRepThreshold;

  /// Running counts at which one phrase run ends and the next begins, e.g.
  /// `[33, 66, 99]` for `[33, 33, 33, 1]`. The final run's end (== total, the
  /// completion) is excluded; empty when there are fewer than two [segments].
  List<int> get segmentStops {
    final segs = segments;
    if (segs == null || segs.length < 2) return const [];
    final stops = <int>[];
    var running = 0;
    for (var i = 0; i < segs.length - 1; i++) {
      running += segs[i];
      stops.add(running);
    }
    return stops;
  }

  /// Part of an explicitly ordered sunnah sequence (the post-prayer adhkar):
  /// sorted by that sequence and shown without category bands.
  bool get hasFixedOrder => fixedOrder != noFixedOrder;

  /// User-created (editable and deletable), as opposed to built-in content.
  bool get isCustom => id.startsWith(customIdPrefix);

  factory Dhikr.fromJson(Map<String, dynamic> json) => Dhikr(
        id: json['id'] as String,
        arabic: json['arabic'] as String,
        body: json['body'] as String?,
        repetitions: json['repetitions'] as int,
        segments: (json['segments'] as List?)?.cast<int>(),
        form: _formNames[json['form']]!,
        tier: _tierNames[json['benefit_tier']]!,
        benefit: json['benefit_text'] as String?,
        benefitSource: json['benefit_source'] as String?,
        benefitEn: json['benefit_text_en'] as String?,
        benefitSourceEn: json['benefit_source_en'] as String?,
        translation: json['translation'] as String?,
        transliteration: json['transliteration'] as String?,
        contexts: (json['contexts'] as List)
            .map((c) => _sessionNames[c]!)
            .toSet(),
        prayers: (json['prayers'] as List?)?.cast<String>() ?? const [],
        prayersReps: json['prayers_reps'] as int?,
        sortHint: json['sort_hint'] as int? ?? noSortHint,
        fixedOrder: json['fixed_order'] as int? ?? noFixedOrder,
      );

  /// Inverse of [Dhikr.fromJson] (same keys as assets/adhkar.json), used to
  /// persist user-created dhikrs.
  Map<String, dynamic> toJson() => {
        'id': id,
        'arabic': arabic,
        'repetitions': repetitions,
        if (segments != null) 'segments': segments,
        'form': form.name,
        'benefit_tier': tier.name,
        if (benefit != null) 'benefit_text': benefit,
        if (benefitSource != null) 'benefit_source': benefitSource,
        if (benefitEn != null) 'benefit_text_en': benefitEn,
        if (benefitSourceEn != null) 'benefit_source_en': benefitSourceEn,
        if (translation != null) 'translation': translation,
        if (transliteration != null) 'transliteration': transliteration,
        'contexts': [
          for (final c in contexts)
            _sessionNames.entries.firstWhere((e) => e.value == c).key,
        ],
        if (sortHint != noSortHint) 'sort_hint': sortHint,
        if (fixedOrder != noFixedOrder) 'fixed_order': fixedOrder,
      };
}
