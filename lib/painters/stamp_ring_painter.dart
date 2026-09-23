import 'dart:math' as math;
import 'package:flutter/material.dart';

class StampRingPainter
    extends CustomPainter {
  final bool large;

  const StampRingPainter({
    this.large = false,
  });

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final center = Offset(
      size.width / 2,
      size.height / 2,
    );

    final radius =
        math.min(
          size.width,
          size.height,
        ) /
            2 -
        (large ? 12 : 8);

    final paint = Paint()
      ..style =
          PaintingStyle.stroke
      ..strokeWidth =
          large ? 2 : 1.4
      ..color =
          Colors.green.withValues(
        alpha: 0.35,
      );

    canvas.drawCircle(
      center,
      radius,
      paint,
    );

    final innerPaint = Paint()
      ..style =
          PaintingStyle.stroke
      ..strokeWidth =
          large ? 1.2 : 1
      ..color =
          Colors.green.withValues(
        alpha: 0.22,
      );

    canvas.drawCircle(
      center,
      radius -
          (large ? 7 : 5),
      innerPaint,
    );
  }

  @override
  bool shouldRepaint(
    covariant StampRingPainter
        oldDelegate,
  ) {
    return oldDelegate.large !=
        large;
  }
}
