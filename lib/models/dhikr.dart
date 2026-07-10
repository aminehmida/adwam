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
  final Set<SessionType> contexts;
  final int sortHint;

  const Dhikr({
    required this.id,
    required this.arabic,
    required this.repetitions,
    required this.form,
    required this.tier,
    this.benefit,
    this.benefitSource,
    required this.contexts,
    this.sortHint = noSortHint,
  });

  /// Final sort tiebreak: shorter text first among otherwise equal dhikrs.
  int get wordCount => arabic.trim().split(RegExp(r'\s+')).length;

  factory Dhikr.fromJson(Map<String, dynamic> json) => Dhikr(
        id: json['id'] as String,
        arabic: json['arabic'] as String,
        repetitions: json['repetitions'] as int,
        form: _formNames[json['form']]!,
        tier: _tierNames[json['benefit_tier']]!,
        benefit: json['benefit_text'] as String?,
        benefitSource: json['benefit_source'] as String?,
        contexts: (json['contexts'] as List)
            .map((c) => _sessionNames[c]!)
            .toSet(),
        sortHint: json['sort_hint'] as int? ?? noSortHint,
      );
}
