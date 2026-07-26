import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../state/prayer_controller.dart';

/// Overrides the timezone used to estimate prayer times.
///
/// Zones, not cities: the app already ships the tz database's zone list, and
/// picking from it costs no extra data. It also happens to solve the worst
/// case — a user in Kashgar whose device reports `Asia/Shanghai`, three hours
/// of longitude away, can pick `Asia/Urumqi` instead.
class ZonePickerScreen extends StatefulWidget {
  const ZonePickerScreen({super.key});

  @override
  State<ZonePickerScreen> createState() => _ZonePickerScreenState();
}

class _ZonePickerScreenState extends State<ZonePickerScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final prayer = context.watch<PrayerController>();
    final needle = _query.trim().toLowerCase();
    final zones = [
      for (final zone in prayer.availableZones)
        if (needle.isEmpty || zone.toLowerCase().contains(needle)) zone,
    ];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.prayerRegion)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              autofocus: false,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                labelText: l10n.prayerRegionSearch,
                border: const OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          Expanded(
            child: ListView.builder(
              // Index 0 is the "follow device" default, ahead of the zones.
              itemCount: zones.length + 1,
              itemBuilder: (context, index) {
                final zone = index == 0 ? null : zones[index - 1];
                return _ZoneTile(
                  label: zone?.replaceAll('_', ' ') ?? l10n.prayerRegionAuto,
                  selected: prayer.zoneOverride == zone,
                  onTap: () {
                    prayer.setZoneOverride(zone);
                    Navigator.of(context).pop();
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ZoneTile extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ZoneTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      title: Text(label),
      trailing: selected ? Icon(Icons.check, color: colors.tertiary) : null,
      selected: selected,
      onTap: onTap,
    );
  }
}
