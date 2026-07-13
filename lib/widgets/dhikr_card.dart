import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/dhikr.dart';
import '../state/settings_controller.dart';
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

  /// Icon shown in the collapsed row: eye-off for hidden dhikrs, check for
  /// finished ones.
  final IconData collapsedIcon;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Edit-mode control strip (drag handle + visibility toggle). When set,
  /// the card shows it above the text and ignores tap/long-press.
  final Widget? editControls;

  /// Measurement keys for the focus overlay's shared-element flight: the
  /// Arabic text block and the progress-circle + count segment.
  final Key? arabicKey;
  final Key? counterKey;

  /// While the focus overlay is up its flying copies replace these two
  /// elements, so the card renders them invisibly (layout preserved).
  final bool hiddenForFocus;

  const DhikrCard({
    super.key,
    required this.dhikr,
    required this.count,
    required this.done,
    this.collapsed = false,
    this.collapsedIcon = Icons.visibility_off_outlined,
    this.onTap,
    this.onLongPress,
    this.editControls,
    this.arabicKey,
    this.counterKey,
    this.hiddenForFocus = false,
  });

  @override
  Widget build(BuildContext context) {
    // Animate between the full card and the collapsed row so collapsing a
    // finished dhikr (or peeking a hidden one) doesn't snap.
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      child: collapsed ? _collapsedRow(context) : _fullCard(context),
    );
  }

  Widget _fullCard(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accent = tierColor(context, dhikr.tier);
    final settings = context.watch<SettingsController>();
    final nonArabicUi = Localizations.localeOf(context).languageCode != 'ar';
    final showTranslation =
        settings.showTranslation && dhikr.translation != null;
    final showTransliteration =
        settings.showTransliteration && dhikr.transliteration != null;

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
                child: Opacity(
                  opacity: hiddenForFocus ? 0 : 1,
                  child: Text(
                    dhikr.arabic,
                    key: arabicKey,
                    style: arabicTextStyle.copyWith(
                      color: done
                          ? colors.onSurfaceVariant.withValues(alpha: .75)
                          : colors.onSurface,
                    ),
                  ),
                ),
              ),
              if (nonArabicUi && (showTranslation || showTransliteration)) ...[
                const SizedBox(height: 4),
                _TranslationExpander(
                  dhikr: dhikr,
                  showTranslation: showTranslation,
                  showTransliteration: showTransliteration,
                ),
              ],
              if (dhikr.benefit != null) ...[
                const SizedBox(height: 4),
                _BenefitExpander(dhikr: dhikr),
              ],
              const SizedBox(height: 10),
              _counterRow(context, colors, accent),
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
            Icon(collapsedIcon, size: 15, color: colors.outline),
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

  Widget _counterRow(BuildContext context, ColorScheme colors, Color accent) {
    return Row(
      children: [
        Opacity(
          opacity: hiddenForFocus ? 0 : 1,
          child: Row(
            key: counterKey,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (done)
                Icon(Icons.check_circle_rounded, size: 26, color: colors.primary)
              else
                SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                    value:
                        dhikr.repetitions == 0 ? 1 : count / dhikr.repetitions,
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
            ],
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

}

/// Compact expander. Unlike [ExpansionTile], the tap target is only as wide
/// as its icon + label, so taps elsewhere on the row fall through to the
/// card's counter tap.
class _CardExpander extends StatefulWidget {
  final IconData icon;
  final String label;
  final Widget body;

  const _CardExpander({
    required this.icon,
    required this.label,
    required this.body,
  });

  @override
  State<_CardExpander> createState() => _CardExpanderState();
}

class _CardExpanderState extends State<_CardExpander> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(widget.icon, size: 16, color: colors.tertiary),
                  const SizedBox(width: 8),
                  Text(
                    widget.label,
                    style: TextStyle(
                      fontFamily: 'Amiri',
                      fontSize: 15,
                      color: colors.tertiary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: _expanded ? .5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.expand_more,
                      size: 18,
                      color: colors.tertiary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: !_expanded
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 8),
                  child: widget.body,
                ),
        ),
      ],
    );
  }
}

/// "Virtue" expander: the benefit text follows the UI language (falling back
/// to Arabic when no translation exists); the dhikr text itself always stays
/// Arabic.
class _BenefitExpander extends StatelessWidget {
  final Dhikr dhikr;

  const _BenefitExpander({required this.dhikr});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final arabicUi = Localizations.localeOf(context).languageCode == 'ar';
    final text =
        arabicUi ? dhikr.benefit! : (dhikr.benefitEn ?? dhikr.benefit!);
    final source = arabicUi
        ? dhikr.benefitSource
        : (dhikr.benefitSourceEn ?? dhikr.benefitSource);
    final showingArabic = arabicUi || dhikr.benefitEn == null;

    return Directionality(
      textDirection: showingArabic ? TextDirection.rtl : TextDirection.ltr,
      child: _CardExpander(
        icon: Icons.auto_awesome,
        label: AppLocalizations.of(context)!.virtue,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              text,
              style: showingArabic
                  ? TextStyle(
                      fontFamily: 'Amiri',
                      fontSize: 17,
                      height: 1.7,
                      color: colors.onSurfaceVariant,
                    )
                  : TextStyle(
                      fontSize: 14.5,
                      height: 1.5,
                      color: colors.onSurfaceVariant,
                    ),
            ),
            if (source != null) ...[
              const SizedBox(height: 4),
              Text(
                source,
                style: TextStyle(fontSize: 12, color: colors.outline),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// "Translation" expander shown on non-Arabic UIs: transliteration first
/// (recitation aid), then the meaning. Which of the two appear is controlled
/// by the settings toggles.
class _TranslationExpander extends StatelessWidget {
  final Dhikr dhikr;
  final bool showTranslation;
  final bool showTransliteration;

  const _TranslationExpander({
    required this.dhikr,
    required this.showTranslation,
    required this.showTransliteration,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: _CardExpander(
        icon: Icons.translate,
        label: AppLocalizations.of(context)!.translation,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showTransliteration)
              Text(
                dhikr.transliteration!,
                style: TextStyle(
                  fontSize: 14.5,
                  height: 1.5,
                  fontStyle: FontStyle.italic,
                  color: colors.onSurfaceVariant,
                ),
              ),
            if (showTransliteration && showTranslation)
              const SizedBox(height: 6),
            if (showTranslation)
              Text(
                dhikr.translation!,
                style: TextStyle(
                  fontSize: 14.5,
                  height: 1.5,
                  color: colors.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
