import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderAbstractViewport;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/dhikr.dart';
import '../state/list_config_controller.dart';
import '../state/progress_controller.dart';
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

  late final AnimationController _focusController;
  late final CurvedAnimation _focusAnim;

  @override
  void initState() {
    super.initState();
    _focusController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
      reverseDuration: const Duration(milliseconds: 250),
    );
    _focusAnim = CurvedAnimation(
      parent: _focusController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
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
    final progress = context.read<ProgressController>();
    final completed = progress.increment(widget.session, dhikr);
    if (completed) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.lightImpact();
    }
    _anchorTo(dhikr.id);
    if (!completed && dhikr.repetitions >= _focusThreshold) {
      setState(() => _focused = dhikr);
      _focusController.forward(from: 0);
      return;
    }
    if (completed && mounted) await _scrollToNextIncomplete();
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

  /// Full-screen counting overlay for high-repetition dhikrs: the dhikr text
  /// rises to the top, a large counter grows in the middle and the background
  /// fades to dark. Any tap counts; a vertical swipe or back dismisses.
  Widget _focusOverlay(BuildContext context) {
    final dhikr = _focused!;
    final progress = context.watch<ProgressController>();
    final count = progress.countFor(widget.session, dhikr.id);
    final l10n = AppLocalizations.of(context)!;
    return FadeTransition(
      opacity: _focusAnim,
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
        child: ColoredBox(
          color: Colors.black.withValues(alpha: .82),
          child: SafeArea(
            child: Column(
              children: [
                SlideTransition(
                  position: Tween(
                    begin: const Offset(0, .35),
                    end: Offset.zero,
                  ).animate(_focusAnim),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.sizeOf(context).height * .35,
                      ),
                      child: Directionality(
                        textDirection: TextDirection.rtl,
                        child: Text(
                          dhikr.arabic,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.fade,
                          style: arabicTextStyle.copyWith(
                            color: Colors.white.withValues(alpha: .95),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: ScaleTransition(
                      scale: Tween(begin: .7, end: 1.0).animate(_focusAnim),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 120),
                            transitionBuilder: (child, anim) => FadeTransition(
                              opacity: anim,
                              child: ScaleTransition(
                                scale: Tween(
                                  begin: .85,
                                  end: 1.0,
                                ).animate(anim),
                                child: child,
                              ),
                            ),
                            child: Text(
                              '$count',
                              key: ValueKey(count),
                              style: const TextStyle(
                                fontSize: 112,
                                fontWeight: FontWeight.w600,
                                fontFeatures: [FontFeature.tabularFigures()],
                                color: Colors.white,
                              ),
                            ),
                          ),
                          Text(
                            '/ ${dhikr.repetitions}',
                            style: TextStyle(
                              fontSize: 22,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                              color: Colors.white.withValues(alpha: .55),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Text(
                    l10n.tapAnywhereToCount,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: .45),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
    final card = Opacity(
      opacity: peeking ? 0.6 : 1,
      child: DhikrCard(
        dhikr: dhikr,
        count: progress.countFor(widget.session, dhikr.id),
        done: done,
        collapsed: collapsed && !peeking,
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
