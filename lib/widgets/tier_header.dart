import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/dhikr.dart';
import '../theme.dart';

String tierLabel(BuildContext context, BenefitTier tier) {
  final l10n = AppLocalizations.of(context)!;
  return switch (tier) {
    BenefitTier.protection => l10n.tierProtection,
    BenefitTier.reward => l10n.tierReward,
    BenefitTier.none => l10n.tierOther,
  };
}

/// Section band for a list run. The user's own duas, high-repetition runs
/// and the full-surah band each get their own label; every other run is
/// labeled by tier.
Widget sectionBandFor(BuildContext context, Dhikr dhikr) {
  if (dhikr.isCustom) {
    return SectionBand(
      label: AppLocalizations.of(context)!.myDuas,
      color: Theme.of(context).colorScheme.primary,
    );
  }
  if (dhikr.isHighRep) {
    return SectionBand(
      label: AppLocalizations.of(context)!.tierHighRep,
      color: highRepColor(context),
    );
  }
  if (dhikr.form == DhikrForm.surah) {
    return SectionBand(
      label: AppLocalizations.of(context)!.fullSurahs,
      color: Theme.of(context).colorScheme.tertiary,
    );
  }
  return SectionBand(
    label: tierLabel(context, dhikr.tier),
    color: tierColor(context, dhikr.tier),
  );
}

/// Whether a section band belongs above [index] — the start of the list or
/// any change of tier / full-surah / high-repetition / custom-dua run.
bool startsSection(List<Dhikr> dhikrs, int index) {
  if (index == 0) return true;
  final prev = dhikrs[index - 1];
  final curr = dhikrs[index];
  if (prev.isCustom || curr.isCustom) return prev.isCustom != curr.isCustom;
  // High-repetition dhikrs form one section regardless of the tiers inside
  // it: a band only starts when crossing into or out of that run.
  if (prev.isHighRep || curr.isHighRep) return prev.isHighRep != curr.isHighRep;
  return prev.tier != curr.tier ||
      (prev.form == DhikrForm.surah) != (curr.form == DhikrForm.surah);
}

/// Mushaf-style section band: ─────── ✦ الحماية ✦ ───────
class SectionBand extends StatelessWidget {
  final String label;
  final Color color;

  const SectionBand({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    Widget line(bool fadeOut) => Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: fadeOut
                    ? [color.withValues(alpha: .5), color.withValues(alpha: 0)]
                    : [color.withValues(alpha: 0), color.withValues(alpha: .5)],
              ),
            ),
          ),
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
      child: Row(
        children: [
          line(false),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text('✦', style: TextStyle(fontSize: 9, color: color)),
          ),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Amiri',
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text('✦', style: TextStyle(fontSize: 9, color: color)),
          ),
          line(true),
        ],
      ),
    );
  }
}
