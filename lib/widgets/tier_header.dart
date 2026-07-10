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

/// Mushaf-style section band separating the benefit tiers:
/// ─────── ✦ الحماية ✦ ───────
class TierHeader extends StatelessWidget {
  final BenefitTier tier;

  const TierHeader({super.key, required this.tier});

  @override
  Widget build(BuildContext context) {
    final color = tierColor(context, tier);

    Widget line() => Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withValues(alpha: 0), color.withValues(alpha: .5)],
              ),
            ),
          ),
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
      child: Row(
        children: [
          line(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text('✦', style: TextStyle(fontSize: 9, color: color)),
          ),
          Text(
            tierLabel(context, tier),
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
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    color.withValues(alpha: .5),
                    color.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
