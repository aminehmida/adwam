import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/prayer.dart';

String prayerName(AppLocalizations l10n, DailyPrayer prayer) =>
    switch (prayer) {
      DailyPrayer.fajr => l10n.prayerFajr,
      DailyPrayer.dhuhr => l10n.prayerDhuhr,
      DailyPrayer.asr => l10n.prayerAsr,
      DailyPrayer.maghrib => l10n.prayerMaghrib,
      DailyPrayer.isha => l10n.prayerIsha,
    };

/// Picks which prayer the post-prayer adhkar are for.
///
/// Sits in the app bar's bottom slot so it stays put while the list scrolls —
/// correcting a wrong guess must never require scrolling back up. All five are
/// always visible rather than hidden behind a dropdown, because the guess being
/// changeable is the point.
///
/// A selection the app guessed is drawn with a dashed underline; one the user
/// made is solid. That distinction is the whole contract with the user: we will
/// tell you when we're not sure.
class PrayerSelector extends StatelessWidget implements PreferredSizeWidget {
  final DailyPrayer? active;
  final bool isGuess;
  final ValueChanged<DailyPrayer> onSelected;

  const PrayerSelector({
    super.key,
    required this.active,
    required this.isGuess,
    required this.onSelected,
  });

  @override
  Size get preferredSize => const Size.fromHeight(46);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return SizedBox(
      height: preferredSize.height,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
        child: Row(
          children: [
            for (final prayer in DailyPrayer.values)
              Expanded(
                child: _PrayerTab(
                  label: prayerName(l10n, prayer),
                  guessedSuffix: l10n.prayerGuessed,
                  selected: prayer == active,
                  provisional: isGuess,
                  colors: colors,
                  onTap: () => onSelected(prayer),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PrayerTab extends StatelessWidget {
  final String label;
  final String guessedSuffix;
  final bool selected;
  final bool provisional;
  final ColorScheme colors;
  final VoidCallback onTap;

  const _PrayerTab({
    required this.label,
    required this.guessedSuffix,
    required this.selected,
    required this.provisional,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tint = colors.tertiary;
    return Semantics(
      selected: selected,
      button: true,
      onTap: onTap,
      // The dashed underline says "this is a guess" visually; say it out loud
      // too, so a screen-reader user gets the same warning. The inner Text is
      // excluded so this label is the node's label rather than a sibling.
      label: selected && provisional ? '$label, $guessedSuffix' : label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: CustomPaint(
          painter: selected
              ? _UnderlinePainter(color: tint, dashed: provisional)
              : null,
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  fontFamily: 'Amiri',
                  fontSize: 15,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  color: selected ? tint : colors.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Underlines the selected prayer: solid when the user chose it, dashed while
/// it is still the app's guess.
class _UnderlinePainter extends CustomPainter {
  final Color color;
  final bool dashed;

  const _UnderlinePainter({required this.color, required this.dashed});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final y = size.height - 1;
    // Inset so the rule reads as belonging to the word, not the full cell.
    final start = size.width * 0.18;
    final end = size.width * 0.82;
    if (!dashed) {
      canvas.drawLine(Offset(start, y), Offset(end, y), paint);
      return;
    }
    const dash = 4.0;
    const gap = 3.0;
    for (var x = start; x < end; x += dash + gap) {
      canvas.drawLine(Offset(x, y), Offset((x + dash).clamp(start, end), y), paint);
    }
  }

  @override
  bool shouldRepaint(_UnderlinePainter old) =>
      old.color != color || old.dashed != dashed;
}
