import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/dhikr.dart';

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

  const DhikrCard({
    super.key,
    required this.dhikr,
    required this.count,
    required this.done,
    this.collapsed = false,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    if (collapsed) return _collapsedRow(context);

    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Card(
      elevation: done ? 0 : 1,
      color: done ? colors.surfaceContainerHighest : null,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Directionality(
                textDirection: TextDirection.rtl,
                child: Text(
                  dhikr.arabic,
                  style: arabicTextStyle.copyWith(
                    color: done ? colors.outline : colors.onSurface,
                  ),
                ),
              ),
              if (dhikr.benefit != null) ...[
                const SizedBox(height: 4),
                _benefitExpander(context),
              ],
              const SizedBox(height: 8),
              _counterRow(colors),
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            Icon(Icons.visibility_off_outlined, size: 16, color: colors.outline),
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
          leading: Icon(Icons.auto_awesome, size: 18, color: colors.tertiary),
          title: Text(
            AppLocalizations.of(context)!.virtue,
            style: TextStyle(fontSize: 14, color: colors.tertiary),
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

  Widget _counterRow(ColorScheme colors) {
    return Row(
      children: [
        if (done)
          Icon(Icons.check_circle, color: colors.primary)
        else
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              value: dhikr.repetitions == 0 ? 1 : count / dhikr.repetitions,
              strokeWidth: 3,
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
      ],
    );
  }
}
