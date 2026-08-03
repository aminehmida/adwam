import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../voice/model_store.dart';

/// Asks before spending the user's bandwidth on the speech model, then shows
/// it arriving.
///
/// Returns true once the model is installed and voice mode can start. The
/// size and the fact that recognition never leaves the device are both stated
/// up front: this is the only moment the app asks for the network at all.
Future<bool> showVoiceModelSheet(
  BuildContext context,
  ModelStore store,
  ModelSpec spec,
) async {
  final l10n = AppLocalizations.of(context)!;
  final megabytes = (spec.downloadBytes / 1e6).round().toString();

  final wanted = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.voiceSetupTitle),
      content: Text(l10n.voiceSetupBody(megabytes)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(MaterialLocalizations.of(dialogContext).cancelButtonLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(l10n.voiceSetupDownload),
        ),
      ],
    ),
  );
  if (wanted != true || !context.mounted) return false;

  return await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => _DownloadDialog(store: store, spec: spec),
      ) ??
      false;
}

class _DownloadDialog extends StatefulWidget {
  final ModelStore store;
  final ModelSpec spec;

  const _DownloadDialog({required this.store, required this.spec});

  @override
  State<_DownloadDialog> createState() => _DownloadDialogState();
}

class _DownloadDialogState extends State<_DownloadDialog> {
  double _progress = 0;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _download();
  }

  Future<void> _download() async {
    try {
      await for (final progress in widget.store.install(widget.spec)) {
        if (!mounted) return;
        setState(() => _progress = progress);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_error != null) {
      return AlertDialog(
        content: Text(l10n.voiceDownloadFailed),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(MaterialLocalizations.of(context).okButtonLabel),
          ),
        ],
      );
    }
    return AlertDialog(
      title: Text(l10n.voiceDownloading),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LinearProgressIndicator(value: _progress),
          const SizedBox(height: 12),
          Text('${(_progress * 100).round()}%'),
        ],
      ),
    );
  }
}
