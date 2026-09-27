import 'dart:math' as math;

import 'package:flutter/material.dart';

class SonarPainter extends CustomPainter {
  final double progress;
  final double intensity;

  const SonarPainter({
    required this.progress,
    required this.intensity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = math.min(size.width, size.height) / 2;

    // Card sonar stays on the existing controller, but uses one restrained
    // pulse instead of three overlapping radar rings.
    const activeFraction = 0.38;
    if (progress < activeFraction) {
      final localProgress = progress / activeFraction;
      final radius = baseRadius * (0.30 + localProgress * 0.34);
      final fade = math.pow(1.0 - localProgress, 1.45).toDouble();
      final opacity = fade * intensity * 0.14;

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = Colors.deepPurple.withValues(alpha: opacity);

      canvas.drawCircle(center, radius, paint);
    }

    final centerPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.deepPurple.withValues(
        alpha: 0.035 + intensity * 0.045,
      );

    canvas.drawCircle(center, baseRadius * 0.27, centerPaint);
  }

  @override
  bool shouldRepaint(covariant SonarPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.intensity != intensity;
  }
}
