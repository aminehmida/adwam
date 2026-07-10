import 'package:flutter/material.dart';

import '../models/dhikr.dart';

const sessionTitlesAr = {
  SessionType.morning: 'أذكار الصباح',
  SessionType.evening: 'أذكار المساء',
  SessionType.postPrayer: 'أذكار بعد الصلاة',
  SessionType.sleep: 'أذكار النوم',
};

const sessionIcons = {
  SessionType.morning: Icons.wb_sunny_outlined,
  SessionType.evening: Icons.wb_twilight,
  SessionType.postPrayer: Icons.mosque_outlined,
  SessionType.sleep: Icons.bedtime_outlined,
};

/// Full-width session card: icon medallion, Arabic title, progress bar.
class ContextCard extends StatelessWidget {
  final SessionType session;
  final int done;
  final int total;
  final VoidCallback onTap;

  const ContextCard({
    super.key,
    required this.session,
    required this.done,
    required this.total,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final complete = total > 0 && done >= total;
    final accent = complete ? colors.primary : colors.secondary;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 7),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(
          color: complete
              ? colors.primary.withValues(alpha: .4)
              : colors.outlineVariant,
        ),
      ),
      color: complete ? colors.primaryContainer.withValues(alpha: .45) : null,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: .14),
                  border: Border.all(color: accent.withValues(alpha: .35)),
                ),
                child: Icon(
                  complete ? Icons.check_rounded : sessionIcons[session],
                  size: 26,
                  color: accent,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sessionTitlesAr[session]!,
                      style: const TextStyle(
                        fontFamily: 'Amiri',
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: total == 0 ? 0 : done / total,
                        minHeight: 5,
                        color: accent,
                        backgroundColor: colors.surfaceContainerHighest,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Text(
                '$done / $total',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: complete ? colors.primary : colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
