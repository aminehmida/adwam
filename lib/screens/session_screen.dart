import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/dhikr.dart';
import '../state/list_config_controller.dart';
import '../state/progress_controller.dart';
import '../widgets/context_card.dart' show sessionTitlesAr;
import '../widgets/dhikr_card.dart';
import 'edit_session_screen.dart';

class SessionScreen extends StatefulWidget {
  final SessionType session;

  const SessionScreen({super.key, required this.session});

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  final Map<String, GlobalKey> _itemKeys = {};

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

  Future<void> _confirmUnhide(Dhikr dhikr) async {
    final config = context.read<ListConfigController>();
    config.setHidden(widget.session, dhikr.id, false);
  }

  @override
  Widget build(BuildContext context) {
    final config = context.watch<ListConfigController>();
    final progress = context.watch<ProgressController>();
    final dhikrs = config.listFor(widget.session);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          sessionTitlesAr[widget.session]!,
          style: const TextStyle(fontFamily: 'Amiri'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Edit list',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => EditSessionScreen(session: widget.session),
              ),
            ),
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
        itemCount: dhikrs.length,
        itemBuilder: (context, index) {
          final dhikr = dhikrs[index];
          final hidden = config.isHidden(widget.session, dhikr.id);
          return KeyedSubtree(
            key: _keyFor(dhikr.id),
            child: DhikrCard(
              dhikr: dhikr,
              count: progress.countFor(widget.session, dhikr.id),
              done: progress.isDone(widget.session, dhikr.id),
              collapsed: hidden,
              onTap: hidden ? () => _confirmUnhide(dhikr) : () => _onTap(dhikr),
              onLongPress: hidden
                  ? null
                  : () {
                      HapticFeedback.mediumImpact();
                      context
                          .read<ProgressController>()
                          .markDone(widget.session, dhikr);
                    },
            ),
          );
        },
      ),
    );
  }
}
