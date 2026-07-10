import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/dhikr.dart';
import '../theme.dart';
import 'tier_header.dart' show tierLabel;

const arabicTextStyle = TextStyle(
  fontFamily: 'Amiri',
  fontSize: 24,
  height: 1.9,
);

/// Tap-to-count card. Renders a thin greyed title-only row when [collapsed].
class DhikrCard extends StatelessWidget {
  final Dhikr dhikr;
  final int count;
  final bool done;
  final bool collapsed;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Edit-mode control strip (drag handle + visibility toggle). When set,
  /// the card shows it above the text and ignores tap/long-press.
  final Widget? editControls;

  const DhikrCard({
    super.key,
    required this.dhikr,
    required this.count,
    required this.done,
    this.collapsed = false,
    this.onTap,
    this.onLongPress,
    this.editControls,
  });

  @override
  Widget build(BuildContext context) {
    if (collapsed) return _collapsedRow(context);

    final colors = Theme.of(context).colorScheme;
    final accent = tierColor(context, dhikr.tier);

    return Card(
      color: done ? colors.primaryContainer.withValues(alpha: .45) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: done ? colors.primary.withValues(alpha: .35) : colors.outlineVariant,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: editControls == null ? onTap : null,
        onLongPress: editControls == null ? onLongPress : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (editControls != null) ...[
                editControls!,
                const SizedBox(height: 8),
              ],
              Directionality(
                textDirection: TextDirection.rtl,
                child: Text(
                  dhikr.arabic,
                  style: arabicTextStyle.copyWith(
                    color: done
                        ? colors.onSurfaceVariant.withValues(alpha: .75)
                        : colors.onSurface,
                  ),
                ),
              ),
              if (dhikr.benefit != null) ...[
                const SizedBox(height: 4),
                _benefitExpander(context),
              ],
              const SizedBox(height: 10),
              _counterRow(context, colors, accent),
              const SizedBox(height: 6),
              _reviewInfoRow(colors),
            ],
          ),
        ),
      ),
    );
  }

  Widget _collapsedRow(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final title = dhikr.arabic.split('\n').first;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.visibility_off_outlined,
                size: 15, color: colors.outline),
            const SizedBox(width: 12),
            Expanded(
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Amiri',
                    fontSize: 16,
                    color: colors.outline,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _benefitExpander(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(bottom: 8),
          dense: true,
          leading: Icon(Icons.auto_awesome, size: 16, color: colors.tertiary),
          title: Text(
            AppLocalizations.of(context)!.virtue,
            style: TextStyle(
              fontFamily: 'Amiri',
              fontSize: 15,
              color: colors.tertiary,
            ),
          ),
          children: [
            Text(
              dhikr.benefit!,
              style: TextStyle(
                fontFamily: 'Amiri',
                fontSize: 17,
                height: 1.7,
                color: colors.onSurfaceVariant,
              ),
            ),
            if (dhikr.benefitSource != null) ...[
              const SizedBox(height: 4),
              Text(
                dhikr.benefitSource!,
                style: TextStyle(fontSize: 12, color: colors.outline),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _counterRow(BuildContext context, ColorScheme colors, Color accent) {
    return Row(
      children: [
        if (done)
          Icon(Icons.check_circle_rounded, size: 26, color: colors.primary)
        else
          SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(
              value: dhikr.repetitions == 0 ? 1 : count / dhikr.repetitions,
              strokeWidth: 3,
              strokeCap: StrokeCap.round,
              color: accent,
              backgroundColor: colors.surfaceContainerHighest,
            ),
          ),
        const SizedBox(width: 12),
        Text(
          '$count / ${dhikr.repetitions}',
          style: TextStyle(
            fontSize: 16,
            fontFeatures: const [FontFeature.tabularFigures()],
            color: done ? colors.primary : colors.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          tierLabel(context, dhikr.tier),
          style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
        ),
      ],
    );
  }

  // Temporary review aid: surfaces the curation id + source on each card so
  // it can be checked against content/REVIEW.md. Remove after review.
  Widget _reviewInfoRow(ColorScheme colors) {
    final style = TextStyle(fontSize: 11, color: colors.outline);
    return Row(
      children: [
        Text(dhikr.id, style: style.copyWith(fontFamily: 'monospace')),
        if (dhikr.benefitSource != null) ...[
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              dhikr.benefitSource!,
              style: style,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textDirection: TextDirection.rtl,
            ),
          ),
        ],
      ],
    );
  }
}
