import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/dhikr.dart';
import '../state/list_config_controller.dart';
import '../state/progress_controller.dart';
import '../widgets/context_card.dart' show sessionTitlesAr;
import '../widgets/dhikr_card.dart';
import '../widgets/tier_header.dart';

class SessionScreen extends StatefulWidget {
  final SessionType session;

  const SessionScreen({super.key, required this.session});

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  final Map<String, GlobalKey> _itemKeys = {};
  bool _editing = false;

  GlobalKey _keyFor(String id) => _itemKeys.putIfAbsent(id, GlobalKey.new);

  void _onTap(Dhikr dhikr) {
    final progress = context.read<ProgressController>();
    final completed = progress.increment(widget.session, dhikr);
    if (completed) {
      HapticFeedback.mediumImpact();
      _scrollToNextIncomplete();
    } else {
      HapticFeedback.lightImpact();
    }
  }

  void _scrollToNextIncomplete() {
    final config = context.read<ListConfigController>();
    final progress = context.read<ProgressController>();
    for (final d in config.listFor(widget.session)) {
      if (config.isHidden(widget.session, d.id)) continue;
      if (progress.isDone(widget.session, d.id)) continue;
      final itemContext = _keyFor(d.id).currentContext;
      if (itemContext != null) {
        Scrollable.ensureVisible(
          itemContext,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
          alignment: 0.1,
        );
      }
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = context.watch<ListConfigController>();
    final dhikrs = config.listFor(widget.session);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          sessionTitlesAr[widget.session]!,
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
                          AppLocalizations.of(menuContext)!.resetOrderTitle),
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
      body: _editing ? _editList(config, dhikrs) : _countList(config, dhikrs),
    );
  }

  Widget _countList(ListConfigController config, List<Dhikr> dhikrs) {
    final progress = context.watch<ProgressController>();
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 32),
      itemCount: dhikrs.length,
      itemBuilder: (context, index) {
        final dhikr = dhikrs[index];
        final hidden = config.isHidden(widget.session, dhikr.id);
        final newSection = index == 0 || dhikrs[index - 1].tier != dhikr.tier;
        final card = DhikrCard(
          dhikr: dhikr,
          count: progress.countFor(widget.session, dhikr.id),
          done: progress.isDone(widget.session, dhikr.id),
          collapsed: hidden,
          onTap: hidden
              ? () => config.setHidden(widget.session, dhikr.id, false)
              : () => _onTap(dhikr),
          onLongPress: hidden
              ? null
              : () {
                  HapticFeedback.mediumImpact();
                  context
                      .read<ProgressController>()
                      .markDone(widget.session, dhikr);
                },
        );
        return KeyedSubtree(
          key: _keyFor(dhikr.id),
          child: newSection
              ? Column(children: [TierHeader(tier: dhikr.tier), card])
              : card,
        );
      },
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
        final newSection = index == 0 || dhikrs[index - 1].tier != dhikr.tier;
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
                        horizontal: 4, vertical: 4),
                    child: Icon(Icons.drag_indicator,
                        color: colors.onSurfaceVariant),
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
              ? Column(children: [TierHeader(tier: dhikr.tier), card])
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
