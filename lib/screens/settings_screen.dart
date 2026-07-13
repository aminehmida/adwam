import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../state/list_config_controller.dart';
import '../state/progress_controller.dart';
import '../state/settings_controller.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsController>();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(l10n.language),
            trailing: DropdownButton<String>(
              value: settings.locale?.languageCode ?? 'system',
              onChanged: (value) => settings.setLocale(
                value == null || value == 'system' ? null : Locale(value),
              ),
              items: [
                DropdownMenuItem(
                    value: 'system', child: Text(l10n.languageSystem)),
                DropdownMenuItem(
                    value: 'ar', child: Text(l10n.languageArabic)),
                DropdownMenuItem(
                    value: 'en', child: Text(l10n.languageEnglish)),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.brightness_6),
            title: Text(l10n.theme),
            trailing: DropdownButton<ThemeMode>(
              value: settings.themeMode,
              onChanged: (value) {
                if (value != null) settings.setThemeMode(value);
              },
              items: [
                DropdownMenuItem(
                    value: ThemeMode.system, child: Text(l10n.themeSystem)),
                DropdownMenuItem(
                    value: ThemeMode.light, child: Text(l10n.themeLight)),
                DropdownMenuItem(
                    value: ThemeMode.dark, child: Text(l10n.themeDark)),
              ],
            ),
          ),
          if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android)
            SwitchListTile(
              secondary: const Icon(Icons.volume_down),
              title: Text(l10n.volumeKeyCounting),
              subtitle: Text(l10n.volumeKeyCountingBody),
              value: settings.volumeKeyCounting,
              onChanged: settings.setVolumeKeyCounting,
            ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.restart_alt),
            title: Text(l10n.resetTodayProgress),
            onTap: () => _confirm(
              context,
              title: l10n.resetTodayProgress,
              body: l10n.resetTodayBody,
              onConfirm: () => context.read<ProgressController>().resetToday(),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.settings_backup_restore),
            title: Text(l10n.resetCustomizations),
            onTap: () => _confirm(
              context,
              title: l10n.resetCustomizations,
              body: l10n.resetCustomizationsBody,
              onConfirm: () => context.read<ListConfigController>().resetAll(),
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(l10n.about),
            subtitle: Text(l10n.aboutBody),
          ),
        ],
      ),
    );
  }

  Future<void> _confirm(
    BuildContext context, {
    required String title,
    required String body,
    required VoidCallback onConfirm,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(body),
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
    if (confirmed == true) onConfirm();
  }
}
