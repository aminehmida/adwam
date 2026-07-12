import 'dart:math' as math;
import 'dart:ui' show ImageFilter, lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderAbstractViewport;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/dhikr.dart';
import '../state/list_config_controller.dart';
import '../state/progress_controller.dart';
import '../state/settings_controller.dart';
import '../theme.dart';
import '../widgets/context_card.dart' show sessionTitle;
import '../widgets/dhikr_card.dart';
import '../widgets/tier_header.dart';

class SessionScreen extends StatefulWidget {
  final SessionType session;

  const SessionScreen({super.key, required this.session});

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen>
    with SingleTickerProviderStateMixin {
  final Map<String, GlobalKey> _itemKeys = {};
  final ScrollController _scrollController = ScrollController();
  bool _editing = false;

  /// Dhikrs with at least this many repetitions count in a full-screen
  /// focus overlay instead of on the card itself.
  static const _focusThreshold = 100;

  /// Dhikr currently counted in the focus overlay; stays set while the
  /// exit animation runs.
  Dhikr? _focused;
  bool _focusDismissing = false;
  double _focusDrag = 0;

  /// Where the card's Arabic text and counter segment sat (in global
  /// coordinates) when the overlay opened — the start/end of the
  /// shared-element flight.
  Rect? _focusArabicFrom;
  Rect? _focusCounterFrom;
  final Map<String, GlobalKey> _arabicKeys = {};
  final Map<String, GlobalKey> _counterKeys = {};

  // TEMP: focus-background candidates under evaluation, switchable live via
  // chips in the overlay. The choice persists on the device (see
  // SettingsController.focusBgVariant); remove the chips once one is chosen.
  static const _focusBgLabels = ['Blur', '+ Vignette', '+ Pattern'];

  late final AnimationController _focusController;
  late final CurvedAnimation _focusAnim;
  late final CurvedAnimation _focusScrim;

  @override
  void initState() {
    super.initState();
    _focusController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
      reverseDuration: const Duration(milliseconds: 450),
    );
    // Both directions are staged so the eye can follow the shared elements.
    // Opening: the scrim darkens first around the still-in-place card
    // elements, then the flight starts. Closing plays the same stages
    // backwards: the elements fly home while the screen is still dark, then
    // the scrim lifts around them as they settle back into the card.
    _focusAnim = CurvedAnimation(
      parent: _focusController,
      curve: const Interval(.25, 1, curve: Curves.easeInOutCubic),
    );
    _focusScrim = CurvedAnimation(
      parent: _focusController,
      curve: const Interval(0, .5, curve: Curves.easeOutCubic),
    );
  }

  /// Hidden or finished dhikrs the user tapped to read. Cleared on scroll —
  /// a peek is temporary; unhiding permanently happens in edit mode.
  final Set<String> _peeked = {};

  /// Last dhikr the user tapped or long-pressed. A finished dhikr stays
  /// expanded while it is the active one — some people tap the count before
  /// reciting — and only collapses once another dhikr is tapped.
  String? _activeId;

  /// Dhikr whose card is the viewport's origin: the count list is split into
  /// two slivers around it and the one holding it is the [CustomScrollView]'s
  /// center. Anything that grows or shrinks *above* the origin (a finished
  /// dhikr animating closed) only changes the extent above it and cannot move
  /// the anchor or anything below — the tapped card is pinned by construction.
  String? _anchorId;
  static const _centerKey = ValueKey('anchor-sliver');

  GlobalKey _keyFor(String id) => _itemKeys.putIfAbsent(id, GlobalKey.new);

  Future<void> _onTap(Dhikr dhikr) async {
    // Measure the flight origins before anything moves.
    final arabicFrom = _globalRect(_arabicKeys[dhikr.id]);
    final counterFrom = _globalRect(_counterKeys[dhikr.id]);
    final progress = context.read<ProgressController>();
    final completed = progress.increment(widget.session, dhikr);
    if (completed) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.lightImpact();
    }
    _anchorTo(dhikr.id);
    if (!completed &&
        dhikr.repetitions >= _focusThreshold &&
        arabicFrom != null &&
        counterFrom != null) {
      setState(() {
        _focused = dhikr;
        _focusArabicFrom = arabicFrom;
        _focusCounterFrom = counterFrom;
      });
      _focusController.forward(from: 0);
      return;
    }
    if (completed && mounted) await _scrollToNextIncomplete();
  }

  Rect? _globalRect(GlobalKey? key) {
    final box = key?.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  void _onFocusTap() {
    final dhikr = _focused;
    if (dhikr == null || _focusDismissing) return;
    final completed = context.read<ProgressController>().increment(
      widget.session,
      dhikr,
    );
    if (completed) {
      HapticFeedback.mediumImpact();
      _dismissFocus(completed: true);
    } else {
      HapticFeedback.lightImpact();
    }
  }

  Future<void> _dismissFocus({bool completed = false}) async {
    if (_focused == null || _focusDismissing) return;
    _focusDismissing = true;
    await _focusController.reverse();
    _focusDismissing = false;
    if (!mounted) return;
    setState(() => _focused = null);
    if (completed) await _scrollToNextIncomplete();
  }

  /// Make [id]'s card the viewport origin (and the active card) without any
  /// visible change: the scroll offset is corrected in the same frame by
  /// exactly the distance the origin moved.
  void _anchorTo(String id) {
    if (_anchorId == id) {
      if (_activeId != id) setState(() => _activeId = id);
      return;
    }
    final renderObject = _keyFor(id).currentContext?.findRenderObject();
    if (renderObject == null ||
        !renderObject.attached ||
        !_scrollController.hasClients) {
      // Not laid out (shouldn't happen for a just-tapped card): keep the old
      // anchor rather than re-origin the viewport blind.
      setState(() => _activeId = id);
      return;
    }
    final position = _scrollController.position;
    // Kill any in-flight scroll animation; its target is in old coordinates.
    position.jumpTo(position.pixels);
    final reveal = RenderAbstractViewport.of(
      renderObject,
    ).getOffsetToReveal(renderObject, 0).offset;
    // In the new coordinate system the tapped card sits at offset 0, so the
    // current offset shifts by -reveal. correctBy applies it without
    // notifying, and the anchor swap lands in the same frame.
    position.correctBy(-reveal);
    setState(() {
      _anchorId = id;
      _activeId = id;
    });
  }

  Future<void> _scrollToNextIncomplete() async {
    // Let a re-anchor from the tap take effect before measuring targets:
    // scroll offsets are relative to the (possibly new) origin.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    final config = context.read<ListConfigController>();
    final progress = context.read<ProgressController>();
    final dhikrs = config.listFor(widget.session);
    final targetIndex = dhikrs.indexWhere(
      (d) =>
          !config.isHidden(widget.session, d.id) &&
          !progress.isDone(widget.session, d.id),
    );
    if (targetIndex == -1) return;
    final targetId = dhikrs[targetIndex].id;

    // ListView.builder only builds items near the viewport, so the target's
    // key may have no context yet. Step towards it until it gets built.
    for (var attempt = 0; attempt < 20; attempt++) {
      if (!mounted) return;
      final itemContext = _keyFor(targetId).currentContext;
      if (itemContext != null && itemContext.mounted) {
        await Scrollable.ensureVisible(
          itemContext,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
          alignment: 0.1,
        );
        return;
      }
      if (!_scrollController.hasClients) return;
      final position = _scrollController.position;
      // Offsets are relative to the anchor sliver, so the scrollable range
      // can start below zero; estimate within the actual extent.
      final estimate =
          position.minScrollExtent +
          (position.maxScrollExtent - position.minScrollExtent) *
              (targetIndex / dhikrs.length);
      final next =
          (estimate > position.pixels
                  ? position.pixels + position.viewportDimension
                  : position.pixels - position.viewportDimension)
              .clamp(position.minScrollExtent, position.maxScrollExtent);
      if ((next - position.pixels).abs() < 1) return;
      await _scrollController.animateTo(
        next,
        duration: const Duration(milliseconds: 120),
        curve: Curves.linear,
      );
    }
  }

  @override
  void dispose() {
    _focusScrim.dispose();
    _focusAnim.dispose();
    _focusController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = context.watch<ListConfigController>();
    final dhikrs = config.listFor(widget.session);
    final l10n = AppLocalizations.of(context)!;

    return PopScope(
      canPop: !_editing && _focused == null,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_focused != null) {
          _dismissFocus();
        } else {
          setState(() => _editing = false);
        }
      },
      // The focus overlay sits above the whole Scaffold (app bar included)
      // so opening it darkens the entire screen.
      child: Stack(
        children: [
          Scaffold(
            appBar: AppBar(
              title: Text(
                sessionTitle(context, widget.session),
                style: const TextStyle(fontFamily: 'Amiri'),
              ),
              actions: _editing
                  ? [
                      PopupMenuButton<String>(
                        onSelected: (_) => _confirmReset(context),
                        itemBuilder: (menuContext) => [
                          PopupMenuItem(
                            value: 'reset',
                            child: Text(
                              AppLocalizations.of(menuContext)!.resetOrderTitle,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.check),
                        tooltip: l10n.doneEditing,
                        onPressed: () => setState(() => _editing = false),
                      ),
                    ]
                  : [
                      IconButton(
                        icon: const Icon(Icons.tune),
                        tooltip: l10n.editList,
                        onPressed: () => setState(() => _editing = true),
                      ),
                    ],
            ),
            body: _editing
                ? _editList(config, dhikrs)
                : _countList(config, dhikrs),
          ),
          if (_focused != null) _focusOverlay(context),
        ],
      ),
    );
  }

  /// Full-screen counting overlay for high-repetition dhikrs. The card's own
  /// Arabic text flies to the top of the screen and its progress-circle +
  /// count segment flies to the center and grows, while the background fades
  /// to dark. Any tap counts; a vertical swipe or back dismisses (reversing
  /// the flight back into the card).
  Widget _focusOverlay(BuildContext context) {
    final dhikr = _focused!;
    final progress = context.watch<ProgressController>();
    final bgVariant = context.watch<SettingsController>().focusBgVariant;
    final count = progress.countFor(widget.session, dhikr.id);
    final done = progress.isDone(widget.session, dhikr.id);
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final accent = tierColor(context, dhikr.tier);
    final media = MediaQuery.of(context);
    final arabicFrom = _focusArabicFrom!;
    final counterFrom = _focusCounterFrom!;
    return AnimatedBuilder(
      animation: _focusController,
      builder: (context, _) {
        final t = _focusAnim.value;
        final scrimT = _focusScrim.value;
        final size = media.size;
        // The text keeps its exact width and wrapping; only its top moves.
        final arabicTop = lerpDouble(
          arabicFrom.top,
          media.padding.top + 24,
          t,
        )!;
        // The counter segment keeps its layout and scales up around its
        // center while that center moves to the middle of the screen.
        final counterCenter = Offset.lerp(
          counterFrom.center,
          Offset(size.width / 2, size.height * .54),
          t,
        )!;
        final counterScale = lerpDouble(1, 3.6, t)!;
        return Material(
          type: MaterialType.transparency,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _onFocusTap,
            onVerticalDragStart: (_) => _focusDrag = 0,
            onVerticalDragUpdate: (details) {
              _focusDrag += details.delta.dy;
              if (_focusDrag.abs() > 48) _dismissFocus();
            },
            onVerticalDragEnd: (details) {
              if ((details.primaryVelocity ?? 0).abs() > 250) _dismissFocus();
            },
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(
                        sigmaX: 8 * scrimT,
                        sigmaY: 8 * scrimT,
                      ),
                      child: _focusBackground(scrimT, bgVariant),
                    ),
                  ),
                ),
                Positioned(
                  left: arabicFrom.left,
                  top: arabicTop,
                  width: arabicFrom.width,
                  child: Directionality(
                    textDirection: TextDirection.rtl,
                    child: Text(
                      dhikr.arabic,
                      style: arabicTextStyle.copyWith(
                        // Tint follows the scrim, not the flight: the text
                        // turns white at its card position while the
                        // background darkens, anchoring the eye to the
                        // departure point.
                        color: Color.lerp(
                          colors.onSurface,
                          Colors.white.withValues(alpha: .95),
                          scrimT,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: counterCenter.dx - counterFrom.width / 2,
                  top: counterCenter.dy - counterFrom.height / 2,
                  child: Transform.scale(
                    scale: counterScale,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 26,
                          height: 26,
                          child: CircularProgressIndicator(
                            value: done ? 1 : count / dhikr.repetitions,
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
                            color: Color.lerp(
                              colors.onSurfaceVariant,
                              Colors.white,
                              scrimT,
                            ),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // TEMP: live switcher between background candidates, sitting
                // just below the counter's final (scaled) position.
                Positioned(
                  left: 0,
                  right: 0,
                  top: size.height * .54 + (counterFrom.height * 3.6) / 2 + 28,
                  child: Opacity(
                    opacity: t,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < _focusBgLabels.length; i++)
                          GestureDetector(
                            onTap: () => context
                                .read<SettingsController>()
                                .setFocusBgVariant(i),
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                color: Colors.white.withValues(
                                  alpha: bgVariant == i ? .25 : .08,
                                ),
                              ),
                              child: Text(
                                _focusBgLabels[i],
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: media.padding.bottom + 28,
                  child: Opacity(
                    opacity: t,
                    child: Center(
                      child: Text(
                        l10n.tapAnywhereToCount,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: .45),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Background behind the blur, per candidate variant. The blur does the
  /// de-cluttering, so the dark layer can stay lighter than a flat scrim.
  Widget _focusBackground(double t, int variant) {
    switch (variant) {
      case 1: // Radial vignette spotlighting the counter.
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, .1),
              radius: 1.2,
              colors: [
                Colors.black.withValues(alpha: .45 * t),
                Colors.black.withValues(alpha: .85 * t),
              ],
            ),
          ),
          child: const SizedBox.expand(),
        );
      case 2: // Faint eight-pointed-star lattice over the dark layer.
        return CustomPaint(
          foregroundPainter: _GeometricPatternPainter(.05 * t),
          child: ColoredBox(
            color: Colors.black.withValues(alpha: .6 * t),
            child: const SizedBox.expand(),
          ),
        );
      default: // Blur only.
        return ColoredBox(
          color: Colors.black.withValues(alpha: .6 * t),
          child: const SizedBox.expand(),
        );
    }
  }

  Widget _countList(ListConfigController config, List<Dhikr> dhikrs) {
    final progress = context.watch<ProgressController>();
    var anchorIndex = _anchorId == null
        ? 0
        : dhikrs.indexWhere((d) => d.id == _anchorId);
    if (anchorIndex < 0) anchorIndex = 0;
    return NotificationListener<ScrollStartNotification>(
      onNotification: (_) {
        if (_peeked.isNotEmpty) setState(_peeked.clear);
        return false;
      },
      // Split at the anchor: items before it live in a reversed sliver that
      // grows upward from the origin, so size changes there (a finished card
      // collapsing) never move the anchor or anything below it.
      child: CustomScrollView(
        controller: _scrollController,
        center: _centerKey,
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) =>
                    _countItem(config, progress, dhikrs, anchorIndex - 1 - i),
                childCount: anchorIndex,
              ),
            ),
          ),
          SliverPadding(
            key: _centerKey,
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 32),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) =>
                    _countItem(config, progress, dhikrs, anchorIndex + i),
                childCount: dhikrs.length - anchorIndex,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _countItem(
    ListConfigController config,
    ProgressController progress,
    List<Dhikr> dhikrs,
    int index,
  ) {
    final dhikr = dhikrs[index];
    final hidden = config.isHidden(widget.session, dhikr.id);
    final done = progress.isDone(widget.session, dhikr.id);
    final finished = !hidden && done && dhikr.id != _activeId;
    final collapsed = hidden || finished;
    final peeking = collapsed && _peeked.contains(dhikr.id);
    final newSection = startsSection(dhikrs, index);
    // A peek is a temporary read-only look at a hidden or finished
    // dhikr; it collapses again on scroll or tap. Unhide permanently
    // via edit mode. The Opacity wrapper is always present so the
    // card's element (and its size animation) survives peek toggles.
    final focusable = dhikr.repetitions >= _focusThreshold;
    final card = Opacity(
      opacity: peeking ? 0.6 : 1,
      child: DhikrCard(
        dhikr: dhikr,
        count: progress.countFor(widget.session, dhikr.id),
        done: done,
        collapsed: collapsed && !peeking,
        arabicKey: focusable
            ? _arabicKeys.putIfAbsent(dhikr.id, GlobalKey.new)
            : null,
        counterKey: focusable
            ? _counterKeys.putIfAbsent(dhikr.id, GlobalKey.new)
            : null,
        hiddenForFocus: _focused?.id == dhikr.id,
        collapsedIcon: hidden
            ? Icons.visibility_off_outlined
            : Icons.check_rounded,
        onTap: peeking
            ? () => setState(() => _peeked.remove(dhikr.id))
            : collapsed
            ? () => setState(() => _peeked.add(dhikr.id))
            : () => _onTap(dhikr),
        onLongPress: collapsed || peeking
            ? null
            : () {
                HapticFeedback.mediumImpact();
                _anchorTo(dhikr.id);
                context.read<ProgressController>().markDone(
                  widget.session,
                  dhikr,
                );
              },
      ),
    );
    return KeyedSubtree(
      key: _keyFor(dhikr.id),
      child: newSection
          ? Column(children: [sectionBandFor(context, dhikr), card])
          : card,
    );
  }

  /// Same full cards, plus a drag handle and visibility toggle per card.
  /// Reordering is confined to the card's tier section (see
  /// ListConfigController.reorder).
  Widget _editList(ListConfigController config, List<Dhikr> dhikrs) {
    final progress = context.watch<ProgressController>();
    final colors = Theme.of(context).colorScheme;
    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 32),
      itemCount: dhikrs.length,
      onReorderItem: (oldIndex, newIndex) => context
          .read<ListConfigController>()
          .reorder(widget.session, oldIndex, newIndex),
      itemBuilder: (context, index) {
        final dhikr = dhikrs[index];
        final hidden = config.isHidden(widget.session, dhikr.id);
        final newSection = startsSection(dhikrs, index);
        final card = Opacity(
          opacity: hidden ? 0.5 : 1,
          child: DhikrCard(
            dhikr: dhikr,
            count: progress.countFor(widget.session, dhikr.id),
            done: progress.isDone(widget.session, dhikr.id),
            editControls: Row(
              children: [
                ReorderableDragStartListener(
                  index: index,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 4,
                    ),
                    child: Icon(
                      Icons.drag_indicator,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    hidden ? Icons.visibility_off : Icons.visibility,
                    color: hidden ? colors.outline : colors.secondary,
                  ),
                  onPressed: () => context
                      .read<ListConfigController>()
                      .setHidden(widget.session, dhikr.id, !hidden),
                ),
              ],
            ),
          ),
        );
        return KeyedSubtree(
          key: ValueKey(dhikr.id),
          child: newSection
              ? Column(children: [sectionBandFor(context, dhikr), card])
              : card,
        );
      },
    );
  }

  Future<void> _confirmReset(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.resetOrderTitle),
        content: Text(l10n.resetOrderBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.reset),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      context.read<ListConfigController>().resetToDefault(widget.session);
    }
  }
}

/// Repeating eight-pointed-star lattice (two overlapping squares per cell),
/// drawn as thin strokes for the focus overlay's pattern background.
class _GeometricPatternPainter extends CustomPainter {
  final double opacity;

  const _GeometricPatternPainter(this.opacity);

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0) return;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..color = Colors.white.withValues(alpha: opacity);
    const cell = 104.0;
    var row = 0;
    for (var y = 0.0; y < size.height + cell; y += cell * .75, row++) {
      final shift = row.isEven ? 0.0 : cell / 2;
      for (var x = -cell + shift; x < size.width + cell; x += cell) {
        _star(canvas, Offset(x, y), cell * .46, paint);
      }
    }
  }

  void _star(Canvas canvas, Offset c, double r, Paint p) {
    final upright = Path();
    final rotated = Path();
    for (var i = 0; i < 4; i++) {
      final a = i * math.pi / 2;
      final v1 = c + Offset(math.cos(a), math.sin(a)) * r;
      final v2 =
          c + Offset(math.cos(a + math.pi / 4), math.sin(a + math.pi / 4)) * r;
      if (i == 0) {
        upright.moveTo(v1.dx, v1.dy);
        rotated.moveTo(v2.dx, v2.dy);
      } else {
        upright.lineTo(v1.dx, v1.dy);
        rotated.lineTo(v2.dx, v2.dy);
      }
    }
    canvas
      ..drawPath(upright..close(), p)
      ..drawPath(rotated..close(), p);
  }

  @override
  bool shouldRepaint(covariant _GeometricPatternPainter old) =>
      old.opacity != opacity;
}
