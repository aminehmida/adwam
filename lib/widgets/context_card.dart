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

    return Card(
      color: complete ? colors.primaryContainer : null,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(
                complete ? Icons.check_circle : sessionIcons[session],
                size: 32,
                color: complete ? colors.primary : colors.onSurfaceVariant,
              ),
              const Spacer(),
              Text(
                sessionTitlesAr[session]!,
                style: const TextStyle(
                  fontFamily: 'Amiri',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$done / $total',
                style: TextStyle(
                  fontSize: 14,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
