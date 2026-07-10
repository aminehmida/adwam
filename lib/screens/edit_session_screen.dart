import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/dhikr.dart';
import '../state/list_config_controller.dart';
import '../widgets/context_card.dart' show sessionTitlesAr;

/// Reorder (drag handles) and hide/show dhikrs for one session.
/// Separate from SessionScreen so drag gestures never fight tap-to-count.
class EditSessionScreen extends StatelessWidget {
  final SessionType session;

  const EditSessionScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    final config = context.watch<ListConfigController>();
    final dhikrs = config.listFor(session);
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          sessionTitlesAr[session]!,
          style: const TextStyle(fontFamily: 'Amiri'),
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (_) => _confirmReset(context),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'reset',
                child: Text('استعادة الترتيب الافتراضي'),
              ),
            ],
          ),
        ],
      ),
      body: ReorderableListView.builder(
        buildDefaultDragHandles: false,
        padding: const EdgeInsets.only(bottom: 32),
        itemCount: dhikrs.length,
        onReorderItem: (oldIndex, newIndex) =>
            context.read<ListConfigController>().reorder(
                  session,
                  oldIndex,
                  newIndex,
                ),
        itemBuilder: (context, index) {
          final dhikr = dhikrs[index];
          final hidden = config.isHidden(session, dhikr.id);
          return ListTile(
            key: ValueKey(dhikr.id),
            leading: ReorderableDragStartListener(
              index: index,
              child: const Icon(Icons.drag_handle),
            ),
            title: Directionality(
              textDirection: TextDirection.rtl,
              child: Text(
                dhikr.arabic.split('\n').first,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Amiri',
                  fontSize: 18,
                  color: hidden ? colors.outline : null,
                ),
              ),
            ),
            subtitle: Text('×${dhikr.repetitions}'),
            trailing: IconButton(
              icon: Icon(
                hidden ? Icons.visibility_off : Icons.visibility,
                color: hidden ? colors.outline : colors.primary,
              ),
              onPressed: () => context
                  .read<ListConfigController>()
                  .setHidden(session, dhikr.id, !hidden),
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('استعادة الترتيب الافتراضي؟'),
        content: const Text('سيُعاد ترتيب هذه القائمة وإظهار جميع الأذكار.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('استعادة'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      context.read<ListConfigController>().resetToDefault(session);
    }
  }
}
