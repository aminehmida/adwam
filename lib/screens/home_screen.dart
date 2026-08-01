import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../build_channel.dart';
import '../l10n/app_localizations.dart';
import '../models/dhikr.dart';
import '../state/list_config_controller.dart';
import '../state/prayer_controller.dart';
import '../state/progress_controller.dart';
import '../state/settings_controller.dart';
import '../widgets/context_card.dart';
import '../widgets/dev_badge.dart';
import '../widgets/prayer_selector.dart' show prayerName;
import 'session_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final config = context.watch<ListConfigController>();
    final progress = context.watch<ProgressController>();
    final prayer = context.watch<PrayerController>();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppLocalizations.of(context)!.appTitle,
              style: const TextStyle(fontFamily: 'Amiri'),
            ),
            if (isDevChannel) ...[const SizedBox(width: 8), const DevBadge()],
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: AppLocalizations.of(context)!.settings,
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          for (final session in SessionType.values)
            Builder(
              builder: (context) {
                final visible = config.visibleIds(session);
                final activePrayer = session == SessionType.postPrayer
                    ? prayer.active
                    : null;
                return ContextCard(
                  session: session,
                  done: progress.doneCount(session, visible),
                  total: visible.length,
                  subtitle: activePrayer == null
                      ? null
                      : prayerName(AppLocalizations.of(context)!, activePrayer),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SessionScreen(session: session),
                    ),
                  ),
                  onLongPress: () => _confirmSessionReset(context, session),
                );
              },
            ),
        ],
      ),
    );
  }

  Future<void> _confirmSessionReset(
    BuildContext context,
    SessionType session,
  ) async {
    final settings = context.read<SettingsController>();
    final progress = context.read<ProgressController>();
    if (settings.skipSessionResetConfirm) {
      progress.resetSession(session);
      return;
    }

    final l10n = AppLocalizations.of(context)!;
    var dontShowAgain = false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: Text(l10n.resetSessionTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.resetSessionBody(sessionTitle(context, session))),
              const SizedBox(height: 8),
              CheckboxListTile(
                value: dontShowAgain,
                onChanged: (value) =>
                    setState(() => dontShowAgain = value ?? false),
                title: Text(l10n.dontShowAgain),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
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
      ),
    );
    if (confirmed == true) {
      if (dontShowAgain) settings.setSkipSessionResetConfirm(true);
      progress.resetSession(session);
    }
  }
}
