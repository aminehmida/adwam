enum DhikrForm { quran, short, long }

enum BenefitTier { protection, reward, otherBenefit, none }

enum SessionType { morning, evening, postPrayer, sleep }

const _formNames = {'quran': DhikrForm.quran, 'short': DhikrForm.short, 'long': DhikrForm.long};

const _tierNames = {
  'protection': BenefitTier.protection,
  'reward': BenefitTier.reward,
  'other_benefit': BenefitTier.otherBenefit,
  'none': BenefitTier.none,
};

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

  const Dhikr({
    required this.id,
    required this.arabic,
    required this.repetitions,
    required this.form,
    required this.tier,
    this.benefit,
    this.benefitSource,
    required this.contexts,
  });

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
      );
}
