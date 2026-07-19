import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// The small circular counter indicator. Behaves like a plain
/// [CircularProgressIndicator] for an ordinary count, but when [stops] are
/// given (the running totals where a compound dhikr's phrase changes, as
/// fractions of the whole) it beads the ring at those points: a faint marker
/// on the unfilled track, a punched-in notch once the arc has passed it — so
/// the thirds of the tasbih read at a glance without adding any new colour.
class CountProgressRing extends StatelessWidget {
  const CountProgressRing({
    super.key,
    required this.value,
    required this.color,
    this.stops = const [],
    this.size = 26,
    this.strokeWidth = 3,
  });

  final double value;
  final Color color;
  final List<double> stops;
  final double size;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(
          value: value.clamp(0.0, 1.0),
          stops: stops,
          arcColor: color,
          trackColor: colors.surfaceContainerHighest,
          notchColor: colors.surface,
          markerColor: colors.onSurfaceVariant.withValues(alpha: .45),
          strokeWidth: strokeWidth,
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.value,
    required this.stops,
    required this.arcColor,
    required this.trackColor,
    required this.notchColor,
    required this.markerColor,
    required this.strokeWidth,
  });

  final double value;
  final List<double> stops;
  final Color arcColor;
  final Color trackColor;
  final Color notchColor;
  final Color markerColor;
  final double strokeWidth;

  static const _start = -math.pi / 2;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = trackColor,
    );

    final sweep = value * 2 * math.pi;
    if (sweep > 0) {
      canvas.drawArc(
        rect,
        _start,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round
          ..color = arcColor,
      );
    }

    final dotRadius = strokeWidth * 0.85;
    for (final f in stops) {
      final angle = _start + f * 2 * math.pi;
      final at = center + Offset(math.cos(angle), math.sin(angle)) * radius;
      final reached = value >= f - 1e-6;
      canvas.drawCircle(
        at,
        dotRadius,
        Paint()..color = reached ? notchColor : markerColor,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value ||
      old.arcColor != arcColor ||
      !listEquals(old.stops, stops);
}
