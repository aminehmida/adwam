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
///
/// In edit mode [onMoveUp] / [onMoveDown] add the ▲▼ buttons that move the
/// whole section; a null callback renders its arrow disabled (the section is
/// already at that end of the list).
Widget sectionBandFor(
  BuildContext context,
  Dhikr dhikr, {
  bool movable = false,
  VoidCallback? onMoveUp,
  VoidCallback? onMoveDown,
}) {
  final (label, color) = switch (dhikr) {
    _ when dhikr.isCustom => (
        AppLocalizations.of(context)!.myDuas,
        Theme.of(context).colorScheme.primary,
      ),
    _ when dhikr.isHighRep => (
        AppLocalizations.of(context)!.tierHighRep,
        highRepColor(context),
      ),
    _ when dhikr.form == DhikrForm.surah => (
        AppLocalizations.of(context)!.fullSurahs,
        Theme.of(context).colorScheme.tertiary,
      ),
    _ => (tierLabel(context, dhikr.tier), tierColor(context, dhikr.tier)),
  };
  return SectionBand(
    label: label,
    color: color,
    movable: movable,
    onMoveUp: onMoveUp,
    onMoveDown: onMoveDown,
  );
}

/// Whether a section band belongs above [index] — the start of the list or
/// any change of tier / full-surah / high-repetition / custom-dua run.
/// Fixed-order dhikrs follow their sunnah sequence rather than the tier
/// grouping, so no bands appear over that run.
bool startsSection(List<Dhikr> dhikrs, int index) {
  final curr = dhikrs[index];
  if (curr.hasFixedOrder) return false;
  if (index == 0) return true;
  final prev = dhikrs[index - 1];
  if (prev.hasFixedOrder) return true;
  if (prev.isCustom || curr.isCustom) return prev.isCustom != curr.isCustom;
  // High-repetition dhikrs form one section regardless of the tiers inside
  // it: a band only starts when crossing into or out of that run.
  if (prev.isHighRep || curr.isHighRep) return prev.isHighRep != curr.isHighRep;
  return prev.tier != curr.tier ||
      (prev.form == DhikrForm.surah) != (curr.form == DhikrForm.surah);
}

/// Whether [dhikrs] is banded at all. Only a fixed-order session (the
/// post-prayer sunnah sequence) is not, and it is fixed-order throughout —
/// so the first card settles it.
bool hasSectionBands(List<Dhikr> dhikrs) =>
    dhikrs.isNotEmpty && startsSection(dhikrs, 0);

/// Mushaf-style section band: ─────── ✦ الحماية ✦ ───────
class SectionBand extends StatelessWidget {
  final String label;
  final Color color;

  /// Edit mode: show the ▲▼ buttons that move this whole section.
  final bool movable;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  const SectionBand({
    super.key,
    required this.label,
    required this.color,
    this.movable = false,
    this.onMoveUp,
    this.onMoveDown,
  });

  Widget _arrow(IconData icon, String tooltip, VoidCallback? onPressed) =>
      IconButton(
        icon: Icon(icon, size: 20),
        tooltip: tooltip,
        onPressed: onPressed,
        color: color,
        disabledColor: color.withValues(alpha: .25),
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints.tightFor(width: 40, height: 36),
      );

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

    final l10n = AppLocalizations.of(context)!;
    return Padding(
      // The arrows are taller than the label, so their band trims the
      // vertical padding to keep both variants about the same height.
      padding: movable
          ? const EdgeInsets.fromLTRB(20, 14, 6, 4)
          : const EdgeInsets.fromLTRB(20, 22, 20, 10),
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
          if (movable) ...[
            _arrow(Icons.arrow_upward, l10n.moveSectionUp, onMoveUp),
            _arrow(Icons.arrow_downward, l10n.moveSectionDown, onMoveDown),
          ],
        ],
      ),
    );
  }
}
