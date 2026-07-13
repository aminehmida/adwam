import 'dart:math' as math;
import 'dart:ui' show ImageFilter, lerpDouble;

import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
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
import '../widgets/custom_dhikr_dialog.dart';
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

  /// Edit-mode twins of [_itemKeys] and [_scrollController]: the count and
  /// edit lists briefly coexist during the mode cross-fade, so they cannot
  /// share GlobalKeys or a scroll position. Offsets are re-derived on every
  /// mode switch, so there is nothing worth restoring across route visits.
  final Map<String, GlobalKey> _editKeys = {};
  final ScrollController _editScrollController = ScrollController(
    keepScrollOffset: false,
  );

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
    if (_volumeKeysSupported) {
      _volumeChannel.setMethodCallHandler(_onVolumeCall);
      _settingsForVolume = context.read<SettingsController>()
        ..addListener(_syncVolumeIntercept);
      _syncVolumeIntercept();
    }
  }

  Future<dynamic> _onVolumeCall(MethodCall call) async {
    if (call.method == 'volumeDown') _onVolumeDown();
  }

  /// Intercept only while counting makes sense: setting on and not editing.
  /// Everywhere else the button keeps its normal volume behavior.
  void _syncVolumeIntercept() {
    if (!_volumeKeysSupported) return;
    final enabled = _settingsForVolume?.volumeKeyCounting ?? false;
    _setIntercept(enabled && !_editing);
  }

  void _setIntercept(bool value) {
    // Widget tests run with an Android defaultTargetPlatform but no host.
    _volumeChannel
        .invokeMethod('setIntercept', value)
        .catchError((_) => null, test: (e) => e is MissingPluginException);
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

  /// Android-only: the hardware volume-down key counts the current dhikr.
  /// MainActivity consumes the key (so the volume never changes) and calls
  /// `volumeDown` here; `setIntercept` tells it when to do so.
  static const _volumeChannel = MethodChannel('dev.amine.adwam/volume');
  static bool get _volumeKeysSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  SettingsController? _settingsForVolume;

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
        dhikr.isHighRep &&
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
    if (completed && mounted) await _scrollToNextIncomplete(after: dhikr.id);
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
    final dhikr = _focused;
    if (dhikr == null || _focusDismissing) return;
    _focusDismissing = true;
    await _focusController.reverse();
    _focusDismissing = false;
    if (!mounted) return;
    setState(() => _focused = null);
    if (completed) await _scrollToNextIncomplete(after: dhikr.id);
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

  Future<void> _scrollToNextIncomplete({required String after}) async {
    // Let a re-anchor from the tap take effect before measuring targets:
    // scroll offsets are relative to the (possibly new) origin.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    final config = context.read<ListConfigController>();
    final progress = context.read<ProgressController>();
    final dhikrs = config.listFor(widget.session);
    bool isIncomplete(Dhikr d) =>
        !config.isHidden(widget.session, d.id) &&
        !progress.isDone(widget.session, d.id);
    // Search forward from the finished dhikr so a deliberately skipped
    // earlier one isn't snapped back to; wrap only when nothing is ahead.
    final afterIndex = dhikrs.indexWhere((d) => d.id == after);
    var targetIndex = dhikrs.indexWhere(isIncomplete, afterIndex + 1);
    if (targetIndex == -1) targetIndex = dhikrs.indexWhere(isIncomplete);
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

  /// The first item visible in [controller]'s viewport among [keys]' built
  /// items, with how far its top sits from the viewport's leading edge
  /// (<= 0 while partially scrolled off). This is the fixpoint of a mode
  /// switch: the same card stays at the same place on screen.
  ({String id, double delta})? _topVisibleItem(
    Map<String, GlobalKey> keys,
    List<Dhikr> dhikrs,
    ScrollController controller,
  ) {
    if (!controller.hasClients) return null;
    final pixels = controller.position.pixels;
    for (final dhikr in dhikrs) {
      final object = keys[dhikr.id]?.currentContext?.findRenderObject();
      if (object == null || !object.attached) continue;
      final viewport = RenderAbstractViewport.maybeOf(object);
      if (viewport == null) continue;
      final top = viewport.getOffsetToReveal(object, 0).offset;
      final height = object is RenderBox && object.hasSize
          ? object.size.height
          : 0.0;
      final delta = top - pixels;
      if (delta + height > 0) return (id: dhikr.id, delta: delta);
    }
    return null;
  }

  /// A volume-down press counts whichever card a tap would naturally hit:
  /// the focus overlay if open, else the active card while it is incomplete
  /// and on screen, else the topmost visible incomplete card (so scrolling
  /// past a dhikr skips it, like tapping the next one would), wrapping to
  /// the first incomplete anywhere when nothing ahead is visible.
  void _onVolumeDown() {
    if (!mounted || _editing) return;
    if (ModalRoute.of(context)?.isCurrent == false) return;
    if (_focused != null) {
      _onFocusTap();
      return;
    }
    final config = context.read<ListConfigController>();
    final progress = context.read<ProgressController>();
    final dhikrs = config.listFor(widget.session);
    bool isIncomplete(Dhikr d) =>
        !config.isHidden(widget.session, d.id) &&
        !progress.isDone(widget.session, d.id);
    Dhikr? target;
    final activeIndex = dhikrs.indexWhere((d) => d.id == _activeId);
    if (activeIndex != -1 &&
        isIncomplete(dhikrs[activeIndex]) &&
        _isInViewport(dhikrs[activeIndex].id)) {
      target = dhikrs[activeIndex];
    }
    target ??= _topVisibleWhere(dhikrs, isIncomplete);
    if (target == null) {
      final firstIndex = dhikrs.indexWhere(isIncomplete);
      if (firstIndex != -1) target = dhikrs[firstIndex];
    }
    if (target != null) _onTap(target);
  }

  /// Whether [id]'s card has any part inside the count viewport. Same math
  /// as [_topVisibleItem], plus the upper bound: items built in the cache
  /// extent below the viewport don't count as visible.
  bool _isInViewport(String id) {
    if (!_scrollController.hasClients) return false;
    final object = _itemKeys[id]?.currentContext?.findRenderObject();
    if (object == null || !object.attached) return false;
    final viewport = RenderAbstractViewport.maybeOf(object);
    if (viewport == null) return false;
    final position = _scrollController.position;
    final top = viewport.getOffsetToReveal(object, 0).offset;
    final height = object is RenderBox && object.hasSize
        ? object.size.height
        : 0.0;
    final delta = top - position.pixels;
    return delta + height > 0 && delta < position.viewportDimension;
  }

  /// Topmost dhikr passing [test] with any part inside the count viewport.
  Dhikr? _topVisibleWhere(List<Dhikr> dhikrs, bool Function(Dhikr) test) {
    for (final dhikr in dhikrs) {
      if (!test(dhikr)) continue;
      if (_isInViewport(dhikr.id)) return dhikr;
    }
    return null;
  }

  /// Swap to the edit list, keeping the card at the top of the count list
  /// in place instead of opening at the top.
  void _startEditing() {
    final dhikrs = context.read<ListConfigController>().listFor(widget.session);
    final anchor = _topVisibleItem(_itemKeys, dhikrs, _scrollController);
    var estimate = 0.0;
    if (anchor != null) {
      final position = _scrollController.position;
      final total =
          position.maxScrollExtent -
          position.minScrollExtent +
          position.viewportDimension;
      final index = dhikrs.indexWhere((d) => d.id == anchor.id);
      estimate = math.max(0, index * total / dhikrs.length);
    }
    setState(() => _editing = true);
    _syncVolumeIntercept();
    if (anchor != null) _alignEditListTo(anchor, estimate);
  }

  /// Bring [anchor]'s edit card to the viewport spot it occupied in the
  /// count list. The edit list builds lazily from the top, so jump to an
  /// estimated offset and step until the card exists, then align exactly;
  /// the mode cross-fade covers the intermediate jumps.
  Future<void> _alignEditListTo(
    ({String id, double delta}) anchor,
    double estimate,
  ) async {
    final dhikrs = context.read<ListConfigController>().listFor(widget.session);
    final targetIndex = dhikrs.indexWhere((d) => d.id == anchor.id);
    if (targetIndex == -1) return;
    var jumped = false;
    for (var attempt = 0; attempt < 20; attempt++) {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted || !_editing || !_editScrollController.hasClients) return;
      final position = _editScrollController.position;
      final object = _editKeys[anchor.id]?.currentContext?.findRenderObject();
      final viewport = RenderAbstractViewport.maybeOf(object);
      if (object != null && object.attached && viewport != null) {
        final top = viewport.getOffsetToReveal(object, 0).offset;
        position.jumpTo(
          (top - anchor.delta).clamp(
            position.minScrollExtent,
            position.maxScrollExtent,
          ),
        );
        return;
      }
      if (!jumped) {
        jumped = true;
        position.jumpTo(
          estimate.clamp(position.minScrollExtent, position.maxScrollExtent),
        );
        continue;
      }
      // Still not built: step a viewport at a time, towards wherever the
      // target sits relative to what is currently on screen.
      final probe = _topVisibleItem(_editKeys, dhikrs, _editScrollController);
      final probeIndex = probe == null
          ? -1
          : dhikrs.indexWhere((d) => d.id == probe.id);
      final next =
          (probeIndex >= 0 && probeIndex < targetIndex
                  ? position.pixels + position.viewportDimension
                  : position.pixels - position.viewportDimension)
              .clamp(position.minScrollExtent, position.maxScrollExtent);
      if ((next - position.pixels).abs() < 1) return;
      position.jumpTo(next);
    }
  }

  /// Swap back to the count list, re-anchored on whichever card is at the
  /// top of the edit list so the switch happens in place.
  void _stopEditing() {
    final dhikrs = context.read<ListConfigController>().listFor(widget.session);
    final anchor = _topVisibleItem(_editKeys, dhikrs, _editScrollController);
    setState(() {
      _editing = false;
      if (anchor != null) _anchorId = anchor.id;
    });
    _syncVolumeIntercept();
    if (anchor == null) return;
    // The anchor card sits at offset 0 by construction; shift by the delta
    // it had in the edit list. Runs post-frame so the rebuilt count list has
    // laid out (the cross-fade hides the first mis-positioned frame).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _editing || !_scrollController.hasClients) return;
      final position = _scrollController.position;
      position.jumpTo(
        (-anchor.delta).clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        ),
      );
    });
  }

  @override
  void dispose() {
    if (_volumeKeysSupported) {
      _settingsForVolume?.removeListener(_syncVolumeIntercept);
      _setIntercept(false);
      _volumeChannel.setMethodCallHandler(null);
    }
    _focusScrim.dispose();
    _focusAnim.dispose();
    _focusController.dispose();
    _scrollController.dispose();
    _editScrollController.dispose();
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
          _stopEditing();
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
                      IconButton(
                        icon: const Icon(Icons.add),
                        tooltip: l10n.addCustomDua,
                        onPressed: _addCustomDhikr,
                      ),
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
                        onPressed: _stopEditing,
                      ),
                    ]
                  : [
                      IconButton(
                        icon: const Icon(Icons.tune),
                        tooltip: l10n.editList,
                        onPressed: _startEditing,
                      ),
                    ],
            ),
            body: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: _editing
                  ? KeyedSubtree(
                      key: const ValueKey('edit'),
                      child: _editList(config, dhikrs),
                    )
                  : KeyedSubtree(
                      key: const ValueKey('count'),
                      child: _countList(config, dhikrs),
                    ),
            ),
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
                        sigmaX: 6 * scrimT,
                        sigmaY: 6 * scrimT,
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
                Colors.black.withValues(alpha: .38 * t),
                Colors.black.withValues(alpha: .72 * t),
              ],
            ),
          ),
          child: const SizedBox.expand(),
        );
      case 2: // Faint eight-pointed-star lattice over the dark layer.
        return CustomPaint(
          foregroundPainter: _GeometricPatternPainter(.05 * t),
          child: ColoredBox(
            color: Colors.black.withValues(alpha: .5 * t),
            child: const SizedBox.expand(),
          ),
        );
      default: // Blur only.
        return ColoredBox(
          color: Colors.black.withValues(alpha: .5 * t),
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
    final focusable = dhikr.isHighRep;
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
      scrollController: _editScrollController,
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 32),
      itemCount: dhikrs.length,
      onReorderItem: (oldIndex, newIndex) => context
          .read<ListConfigController>()
          .reorder(widget.session, oldIndex, newIndex),
      // Subtle lift while dragging: a slight grow plus a soft shadow.
      proxyDecorator: (child, index, animation) => AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          final t = Curves.easeOut.transform(animation.value);
          return Transform.scale(
            scale: lerpDouble(1, 1.02, t)!,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .18 * t),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: child,
            ),
          );
        },
        child: child,
      ),
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
                if (dhikr.isCustom) ...[
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: Icon(Icons.edit_outlined, color: colors.secondary),
                    tooltip: AppLocalizations.of(context)!.editCustomDua,
                    onPressed: () => _editCustomDhikr(dhikr),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: Icon(Icons.delete_outline, color: colors.error),
                    tooltip: AppLocalizations.of(context)!.deleteCustomDua,
                    onPressed: () => _confirmDeleteCustom(dhikr),
                  ),
                ],
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
          key: _editKeys.putIfAbsent(dhikr.id, GlobalKey.new),
          child: newSection
              ? Column(children: [sectionBandFor(context, dhikr), card])
              : card,
        );
      },
    );
  }

  Future<void> _addCustomDhikr() async {
    final input = await showCustomDhikrDialog(context, session: widget.session);
    if (input == null || !mounted) return;
    context.read<ListConfigController>().addCustom(
          arabic: input.arabic,
          contexts: input.contexts,
        );
  }

  Future<void> _editCustomDhikr(Dhikr dhikr) async {
    final input = await showCustomDhikrDialog(
      context,
      existing: dhikr,
      session: widget.session,
    );
    if (input == null || !mounted) return;
    context.read<ListConfigController>().updateCustom(
          dhikr.id,
          arabic: input.arabic,
          contexts: input.contexts,
        );
  }

  Future<void> _confirmDeleteCustom(Dhikr dhikr) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.customDuaDeleteTitle),
        content: Text(l10n.customDuaDeleteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      context.read<ListConfigController>().removeCustom(dhikr.id);
    }
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

/// Classic star-and-cross zellige lattice for the focus overlay's pattern
/// background: touching eight-pointed stars on a square grid, an inner echo
/// star rotated an eighth turn inside each, and diamonds filling the cell
/// centres. Detail lines are thinner and fainter than the main lattice.
class _GeometricPatternPainter extends CustomPainter {
  final double opacity;

  const _GeometricPatternPainter(this.opacity);

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0) return;
    final main = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = Colors.white.withValues(alpha: opacity);
    final detail = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..color = Colors.white.withValues(alpha: opacity * .8);
    const cell = 120.0;
    for (var y = 0.0; y < size.height + cell; y += cell) {
      for (var x = 0.0; x < size.width + cell; x += cell) {
        final c = Offset(x, y);
        // Main star, sized so neighbouring points almost touch, plus an
        // inner echo star offset by an eighth turn.
        _star(canvas, c, cell * .48, 0, main);
        _star(canvas, c, cell * .26, math.pi / 8, detail);
        // Diamond in the middle of each group of four stars.
        _diamond(
          canvas,
          c + const Offset(cell / 2, cell / 2),
          cell * .17,
          detail,
        );
      }
    }
  }

  /// Eight-pointed star: two overlapping squares, the second an eighth of a
  /// turn further round.
  void _star(Canvas canvas, Offset c, double r, double rotation, Paint p) {
    canvas
      ..drawPath(_square(c, r, rotation), p)
      ..drawPath(_square(c, r, rotation + math.pi / 4), p);
  }

  void _diamond(Canvas canvas, Offset c, double r, Paint p) =>
      canvas.drawPath(_square(c, r, 0), p);

  Path _square(Offset c, double r, double rotation) {
    final path = Path();
    for (var i = 0; i < 4; i++) {
      final a = rotation + i * math.pi / 2;
      final v = c + Offset(math.cos(a), math.sin(a)) * r;
      i == 0 ? path.moveTo(v.dx, v.dy) : path.lineTo(v.dx, v.dy);
    }
    return path..close();
  }

  @override
  bool shouldRepaint(covariant _GeometricPatternPainter old) =>
      old.opacity != opacity;
}
