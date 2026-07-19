import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/dhikr.dart';
import '../state/settings_controller.dart';
import '../theme.dart';
import 'count_progress_ring.dart';
import 'tier_header.dart' show tierLabel;

const arabicTextStyle = TextStyle(
  fontFamily: 'Amiri',
  fontSize: 24,
  height: 1.9,
);

/// Quranic passages carry tashkeel and waqf (pause) marks. They render in the
/// Amiri Quran face, whose marks sit tightly over their letters (plain Amiri
/// parks them high, so they'd crowd the line above); a little extra, evenly
/// spread leading gives the ayah roundels room. Applied wherever a dhikr's
/// Arabic is drawn (card + focus flight) so the shared-element animation stays
/// aligned.
TextStyle arabicStyleFor(DhikrForm form) => form == DhikrForm.quran
    ? arabicTextStyle.copyWith(
        fontFamily: 'Amiri Quran',
        height: 2.0,
        leadingDistribution: TextLeadingDistribution.even,
      )
    : arabicTextStyle;

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
              if (dhikr.prayers.isNotEmpty) ...[
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: _PrayerPill(
                    prayers: dhikr.prayers,
                    reps: dhikr.prayersReps,
                  ),
                ),
                const SizedBox(height: 10),
              ],
              Directionality(
                textDirection: TextDirection.rtl,
                child: Opacity(
                  opacity: hiddenForFocus ? 0 : 1,
                  child: Text(
                    dhikr.arabic,
                    key: arabicKey,
                    style: arabicStyleFor(dhikr.form).copyWith(
                      color: done
                          ? colors.onSurfaceVariant.withValues(alpha: .75)
                          : colors.onSurface,
                    ),
                  ),
                ),
              ),
              if ((nonArabicUi && (showTranslation || showTransliteration)) ||
                  dhikr.benefit != null) ...[
                const SizedBox(height: 4),
                _CardExpanders(items: [
                  if (nonArabicUi && (showTranslation || showTransliteration))
                    _translationItem(
                      context,
                      dhikr: dhikr,
                      showTranslation: showTranslation,
                      showTransliteration: showTransliteration,
                    ),
                  if (dhikr.benefit != null) _benefitItem(context, dhikr),
                ]),
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
                CountProgressRing(
                  value: dhikr.repetitions == 0 ? 1 : count / dhikr.repetitions,
                  color: accent,
                  stops: [
                    for (final s in dhikr.segmentStops) s / dhikr.repetitions,
                  ],
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
          dhikr.isCustom
              ? AppLocalizations.of(context)!.myDuas
              : tierLabel(context, dhikr.tier),
          style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
        ),
      ],
    );
  }

}

/// Pill flagging a dhikr said only after specific prayers (e.g. Fajr &
/// Maghrib), so it stands out from the adhkar of every prayer. With [reps]
/// the dhikr isn't restricted; it's repeated more after those prayers.
class _PrayerPill extends StatelessWidget {
  final List<String> prayers;
  final int? reps;

  const _PrayerPill({required this.prayers, this.reps});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    String name(String key) => switch (key) {
          'fajr' => l10n.prayerFajr,
          'dhuhr' => l10n.prayerDhuhr,
          'asr' => l10n.prayerAsr,
          'maghrib' => l10n.prayerMaghrib,
          'isha' => l10n.prayerIsha,
          _ => key,
        };
    final names = prayers.map(name).join(l10n.prayerJoiner);
    final label = reps == null
        ? l10n.afterPrayers(names)
        : l10n.timesAfterPrayers(reps!, names);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
      decoration: BoxDecoration(
        color: colors.tertiary.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.tertiary.withValues(alpha: .45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.mosque_outlined, size: 13, color: colors.tertiary),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colors.tertiary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpanderItem {
  final IconData icon;
  final String label;
  final Widget body;

  const _ExpanderItem({
    required this.icon,
    required this.label,
    required this.body,
  });
}

/// Compact expanders sharing one header row (e.g. Translation next to
/// Virtue), each toggling its own body below. Unlike [ExpansionTile], every
/// tap target is only as wide as its icon + label, so taps elsewhere on the
/// row fall through to the card's counter tap.
class _CardExpanders extends StatefulWidget {
  final List<_ExpanderItem> items;

  const _CardExpanders({required this.items});

  @override
  State<_CardExpanders> createState() => _CardExpandersState();
}

class _CardExpandersState extends State<_CardExpanders> {
  final Set<int> _expanded = {};

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < widget.items.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                _header(i, colors),
              ],
            ],
          ),
        ),
        for (var i = 0; i < widget.items.length; i++)
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: !_expanded.contains(i)
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 8),
                    child: widget.items[i].body,
                  ),
          ),
      ],
    );
  }

  Widget _header(int i, ColorScheme colors) {
    final item = widget.items[i];
    final open = _expanded.contains(i);
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () =>
          setState(() => open ? _expanded.remove(i) : _expanded.add(i)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(item.icon, size: 16, color: colors.tertiary),
            const SizedBox(width: 8),
            Text(
              item.label,
              style: TextStyle(
                fontFamily: 'Amiri',
                fontSize: 15,
                color: colors.tertiary,
              ),
            ),
            const SizedBox(width: 4),
            AnimatedRotation(
              turns: open ? .5 : 0,
              duration: const Duration(milliseconds: 200),
              child: Icon(Icons.expand_more, size: 18, color: colors.tertiary),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Virtue" expander item: the benefit text follows the UI language (falling
/// back to Arabic when no translation exists); the dhikr text itself always
/// stays Arabic.
_ExpanderItem _benefitItem(BuildContext context, Dhikr dhikr) {
  final colors = Theme.of(context).colorScheme;
  final arabicUi = Localizations.localeOf(context).languageCode == 'ar';
  final text = arabicUi ? dhikr.benefit! : (dhikr.benefitEn ?? dhikr.benefit!);
  final source = arabicUi
      ? dhikr.benefitSource
      : (dhikr.benefitSourceEn ?? dhikr.benefitSource);
  final showingArabic = arabicUi || dhikr.benefitEn == null;

  return _ExpanderItem(
    icon: Icons.auto_awesome,
    label: AppLocalizations.of(context)!.virtue,
    body: Directionality(
      textDirection: showingArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Column(
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

/// "Translation" expander item shown on non-Arabic UIs: transliteration
/// first (recitation aid), then the meaning. Which of the two appear is
/// controlled by the settings toggles.
_ExpanderItem _translationItem(
  BuildContext context, {
  required Dhikr dhikr,
  required bool showTranslation,
  required bool showTransliteration,
}) {
  final colors = Theme.of(context).colorScheme;
  return _ExpanderItem(
    icon: Icons.translate,
    label: AppLocalizations.of(context)!.translation,
    body: Directionality(
      textDirection: TextDirection.ltr,
      child: Column(
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
          if (showTransliteration && showTranslation) const SizedBox(height: 6),
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
