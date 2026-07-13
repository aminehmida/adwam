import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/dhikr.dart';
import 'context_card.dart' show sessionTitle;

/// What the user typed into the add/edit custom dua dialog.
typedef CustomDhikrInput = ({String arabic, Set<SessionType> contexts});

/// Form for a user's own dua: the text and which sessions it appears in.
/// Pass [existing] to edit; [session] preselects the session the dialog was
/// opened from.
Future<CustomDhikrInput?> showCustomDhikrDialog(
  BuildContext context, {
  Dhikr? existing,
  required SessionType session,
}) =>
    showDialog<CustomDhikrInput>(
      context: context,
      builder: (_) => _CustomDhikrDialog(existing: existing, session: session),
    );

class _CustomDhikrDialog extends StatefulWidget {
  final Dhikr? existing;
  final SessionType session;

  const _CustomDhikrDialog({this.existing, required this.session});

  @override
  State<_CustomDhikrDialog> createState() => _CustomDhikrDialogState();
}

class _CustomDhikrDialogState extends State<_CustomDhikrDialog> {
  late final TextEditingController _text = TextEditingController(
    text: widget.existing?.arabic ?? '',
  );
  late final Set<SessionType> _contexts = {
    ...widget.existing?.contexts ?? {widget.session},
  };

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  bool get _valid => _text.text.trim().isNotEmpty && _contexts.isNotEmpty;

  void _save() => Navigator.of(context).pop((
        arabic: _text.text.trim(),
        contexts: {..._contexts},
      ));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    return AlertDialog(
      scrollable: true,
      title: Text(
        widget.existing == null
            ? l10n.customDuaNewTitle
            : l10n.customDuaEditTitle,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _text,
            minLines: 2,
            maxLines: 6,
            textDirection: TextDirection.rtl,
            style: const TextStyle(
              fontFamily: 'Amiri',
              fontSize: 20,
              height: 1.9,
            ),
            decoration: InputDecoration(
              hintText: l10n.customDuaTextHint,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.customDuaSessions,
            style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final s in SessionType.values)
                FilterChip(
                  label: Text(sessionTitle(context, s)),
                  selected: _contexts.contains(s),
                  onSelected: (selected) => setState(() {
                    selected ? _contexts.add(s) : _contexts.remove(s);
                  }),
                ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _valid ? _save : null,
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
