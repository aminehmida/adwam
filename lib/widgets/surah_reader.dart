import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/dhikr.dart';
import '../state/settings_controller.dart';
import '../theme.dart';

/// The basmala heading shown above the surah body, as in the mushaf. It is
/// a rendering convention (identical for both sleep surahs), not part of
/// the Tanzil `body` text. Orthography matches Tanzil's Uthmani text.
const _basmala = 'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ';

/// End-of-ayah marker with its verse number (۝ + Arabic-Indic digits), as
/// composed by tool/build_content.py.
final _ayahMarker = RegExp('۝[٠-٩]+');

/// The surah body as spans: ayah text in the ambient style, each ayah
/// marker picked out in [gold] — like the gilded roundels of an
/// illuminated mushaf.
List<TextSpan> _bodySpans(String body, Color gold) {
  final spans = <TextSpan>[];
  var last = 0;
  for (final m in _ayahMarker.allMatches(body)) {
    if (m.start > last) {
      spans.add(TextSpan(text: body.substring(last, m.start)));
    }
    spans.add(
      TextSpan(
        text: m[0],
        style: TextStyle(color: gold),
      ),
    );
    last = m.end;
  }
  if (last < body.length) spans.add(TextSpan(text: body.substring(last)));
  return spans;
}

/// Scrollable mushaf-style reader for a `surah`-form dhikr, shown inside
/// the session screen's reader overlay (dark blurred scrim behind it, so
/// everything here is styled light-on-dark). A Done button after the last
/// ayah calls [onDone]; pulling down past the top calls [onDismiss].
class SurahReader extends StatefulWidget {
  final Dhikr dhikr;
  final VoidCallback onDone;
  final VoidCallback onDismiss;

  /// Owned by the host (SessionScreen) so the hardware volume-down key can
  /// page the reader down. The reader only reads its position (for the
  /// progress line) and never disposes it.
  final ScrollController controller;

  const SurahReader({
    super.key,
    required this.dhikr,
    required this.onDone,
    required this.onDismiss,
    required this.controller,
  });

  @override
  State<SurahReader> createState() => _SurahReaderState();
}

class _SurahReaderState extends State<SurahReader> {
  /// Accumulated pull-down at the top edge; past the threshold the reader
  /// closes without completing (mirrors the focus overlay's 48px swipe).
  double _overscroll = 0;

  /// How far through the surah the reader has scrolled, 0..1 — drives the
  /// gilded progress line along the top of the page.
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onScroll);
  }

  void _onScroll() {
    if (!widget.controller.hasClients) return;
    final position = widget.controller.position;
    final max = position.maxScrollExtent;
    final value = max > 0 ? (position.pixels / max).clamp(0.0, 1.0) : 0.0;
    if (value != _progress) setState(() => _progress = value);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onScroll);
    super.dispose();
  }

  bool _onOverscroll(OverscrollNotification notification) {
    if (notification.overscroll < 0) {
      _overscroll += notification.overscroll;
      if (_overscroll < -48) {
        _overscroll = 0;
        widget.onDismiss();
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    // The same gold as the ayah numbers and the reward-tier accents.
    final gold = tierColor(context, BenefitTier.reward);
    // The basmala tracks the body size, one step smaller (as before the
    // size became adjustable: 22 next to the default body 23).
    final fontSize = context.watch<SettingsController>().quranFontSize;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              // A gilded reading-progress bar in its own band above the page,
              // centred and filling from the leading (right, in RTL) edge as
              // the surah scrolls — a ribbon marking one's place.
              Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 10),
                child: Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: Container(
                      width: 140,
                      height: 6,
                      color: gold.withValues(alpha: .18),
                      alignment: AlignmentDirectional.centerStart,
                      child: FractionallySizedBox(
                        widthFactor: _progress,
                        child: Container(color: gold),
                      ),
                    ),
                  ),
                ),
              ),
              // The rounded manuscript page fills the rest of the height.
              // Styled like the session cards — the card fill inside a gold
              // contour over the plain surface behind.
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardTheme.color,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: gold.withValues(alpha: .6)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: NotificationListener<OverscrollNotification>(
                    onNotification: _onOverscroll,
                    child: SingleChildScrollView(
                      controller: widget.controller,
                      // Clamping physics so pull-down at the top surfaces as
                      // overscroll notifications (bouncing physics would
                      // swallow them).
                      physics: const ClampingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            widget.dhikr.arabic,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Amiri',
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: gold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _basmala,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Amiri Quran',
                              fontSize: fontSize - 1,
                              height: 1.8,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text.rich(
                            TextSpan(
                              children: _bodySpans(widget.dhikr.body!, gold),
                            ),
                            textAlign: TextAlign.justify,
                            style: TextStyle(
                              // Amiri Quran keeps tashkeel and waqf marks tight
                              // over their letters; a little evenly-spread
                              // leading gives the ayah roundels room without
                              // stranding the marks.
                              fontFamily: 'Amiri Quran',
                              fontSize: fontSize,
                              height: 2.0,
                              leadingDistribution: TextLeadingDistribution.even,
                              color: colors.onSurface,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Center(
                            child: FilledButton(
                              onPressed: widget.onDone,
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 48,
                                  vertical: 14,
                                ),
                              ),
                              child: Text(
                                l10n.doneReading,
                                style: const TextStyle(
                                  fontFamily: 'Amiri',
                                  fontSize: 18,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
