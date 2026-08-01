import 'package:flutter/material.dart';

/// Small "dev" tag shown beside the app title so a dev-channel build is never
/// mistaken for the released one. Deliberately untranslated: it names a build
/// channel, not app content.
class DevBadge extends StatelessWidget {
  const DevBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).colorScheme.tertiary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        border: Border.all(color: gold),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'dev',
        textDirection: TextDirection.ltr,
        style: TextStyle(
          color: gold,
          fontSize: 11,
          height: 1.3,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
