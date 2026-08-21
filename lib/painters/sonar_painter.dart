import 'package:flutter/material.dart';

class SonarPainter extends CustomPainter {
  final double progress;
  final double intensity;

  SonarPainter({required this.progress, required this.intensity});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.deepPurple.withValues(alpha: 0.25);

    canvas.drawCircle(center, maxRadius * 0.82, basePaint);

    for (int i = 0; i < 3; i++) {
      final waveProgress = (progress + i * 0.33) % 1.0;
      final radius = maxRadius * waveProgress;

      final opacity = (1.0 - waveProgress) * intensity * 0.45;

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.deepPurple.withValues(alpha: opacity);

      canvas.drawCircle(center, radius, paint);
    }

    final glowPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.deepPurple.withValues(alpha: 0.08 + intensity * 0.12);

    canvas.drawCircle(center, maxRadius * 0.38, glowPaint);
  }

  @override
  bool shouldRepaint(covariant SonarPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.intensity != intensity;
  }
}
