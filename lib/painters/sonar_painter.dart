import 'dart:math' as math;
import 'package:flutter/material.dart';

class SonarPainter
    extends CustomPainter {
  final double progress;
  final double intensity;

  const SonarPainter({
    required this.progress,
    required this.intensity,
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

    final baseRadius =
        math.min(
          size.width,
          size.height,
        ) /
            2;

    final pulse =
        (progress * 2) % 1.0;

    for (int i = 0; i < 3; i++) {
      final localProgress =
          (pulse + i / 3) % 1.0;

      final radius =
          baseRadius *
              (0.35 +
                  localProgress *
                      0.65);

      final opacity =
          (1.0 -
                  localProgress) *
              intensity *
              0.55;

      final paint = Paint()
        ..style =
            PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors
            .deepPurple
            .withValues(
          alpha: opacity,
        );

      canvas.drawCircle(
        center,
        radius,
        paint,
      );
    }

    final centerPaint = Paint()
      ..style =
          PaintingStyle.fill
      ..color = Colors
          .deepPurple
          .withValues(
        alpha: 0.12 +
            intensity * 0.18,
      );

    canvas.drawCircle(
      center,
      baseRadius * 0.35,
      centerPaint,
    );
  }

  @override
  bool shouldRepaint(
    covariant SonarPainter
        oldDelegate,
  ) {
    return oldDelegate.progress !=
            progress ||
        oldDelegate.intensity !=
            intensity;
  }
}
