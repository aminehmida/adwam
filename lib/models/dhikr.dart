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
/// "high repetitions" section at the bottom of a session and counted in the
/// full-screen focus overlay rather than on the card.
const highRepThreshold = 100;

const _sessionNames = {
  'morning': SessionType.morning,
  'evening': SessionType.evening,
  'post_prayer': SessionType.postPrayer,
  'sleep': SessionType.sleep,
};

class Dhikr {
  final String id;
  final String arabic;
  final int repetitions;
  final DhikrForm form;
  final BenefitTier tier;
  final String? benefit;
  final String? benefitSource;
  final String? benefitEn;
  final String? benefitSourceEn;
  final Set<SessionType> contexts;
  final int sortHint;

  /// Explicit position in the session list (e.g. the sunnah sequence of
  /// the post-prayer adhkar). Outranks every heuristic sort rule.
  final int fixedOrder;

  const Dhikr({
    required this.id,
    required this.arabic,
    required this.repetitions,
    required this.form,
    required this.tier,
    this.benefit,
    this.benefitSource,
    this.benefitEn,
    this.benefitSourceEn,
    required this.contexts,
    this.sortHint = noSortHint,
    this.fixedOrder = noFixedOrder,
  });

  /// Final sort tiebreak: shorter text first among otherwise equal dhikrs.
  int get wordCount => arabic.trim().split(RegExp(r'\s+')).length;

  /// Repeated enough times to belong in the high-repetitions section and to
  /// count in the focus overlay.
  bool get isHighRep => repetitions >= highRepThreshold;

  factory Dhikr.fromJson(Map<String, dynamic> json) => Dhikr(
        id: json['id'] as String,
        arabic: json['arabic'] as String,
        repetitions: json['repetitions'] as int,
        form: _formNames[json['form']]!,
        tier: _tierNames[json['benefit_tier']]!,
        benefit: json['benefit_text'] as String?,
        benefitSource: json['benefit_source'] as String?,
        benefitEn: json['benefit_text_en'] as String?,
        benefitSourceEn: json['benefit_source_en'] as String?,
        contexts: (json['contexts'] as List)
            .map((c) => _sessionNames[c]!)
            .toSet(),
        sortHint: json['sort_hint'] as int? ?? noSortHint,
        fixedOrder: json['fixed_order'] as int? ?? noFixedOrder,
      );
}
