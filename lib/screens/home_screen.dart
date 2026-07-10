import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/dhikr.dart';
import '../state/list_config_controller.dart';
import '../state/progress_controller.dart';
import '../state/settings_controller.dart';
import '../widgets/context_card.dart';
import 'session_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final config = context.watch<ListConfigController>();
    final progress = context.watch<ProgressController>();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context)!.appTitle,
          style: const TextStyle(fontFamily: 'Amiri'),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: AppLocalizations.of(context)!.settings,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          for (final session in SessionType.values)
            Builder(builder: (context) {
              final visible = config.visibleIds(session);
              return ContextCard(
                session: session,
                done: progress.doneCount(session, visible),
                total: visible.length,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SessionScreen(session: session),
                  ),
                ),
              );
            }),
          _languageSelector(context),
        ],
      ),
    );
  }

  /// Quick UI-language toggle; same override as the language setting in
  /// SettingsScreen.
  Widget _languageSelector(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Center(
        child: SegmentedButton<String>(
          segments: const [
            ButtonSegment(
              value: 'ar',
              label: Text('العربية', style: TextStyle(fontFamily: 'Amiri')),
            ),
            ButtonSegment(value: 'en', label: Text('English')),
          ],
          selected: {Localizations.localeOf(context).languageCode},
          showSelectedIcon: false,
          onSelectionChanged: (selection) =>
              settings.setLocale(Locale(selection.first)),
          style: SegmentedButton.styleFrom(
            visualDensity: VisualDensity.compact,
            side: BorderSide(color: colors.outlineVariant),
            foregroundColor: colors.onSurfaceVariant,
            selectedForegroundColor: colors.onPrimaryContainer,
            selectedBackgroundColor: colors.primaryContainer,
          ),
        ),
      ),
    );
  }
}
