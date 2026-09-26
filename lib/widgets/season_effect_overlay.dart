import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/real_world_state.dart';

/// Small seasonal accents around the map edges, below the weather layer.
class SeasonEffectOverlay extends StatefulWidget {
  final Season season;
  final DayPhase dayPhase;
  final WeatherCondition weather;

  const SeasonEffectOverlay({
    super.key,
    required this.season,
    required this.dayPhase,
    required this.weather,
  });

  @override
  State<SeasonEffectOverlay> createState() => _SeasonEffectOverlayState();
}

class _SeasonEffectOverlayState extends State<SeasonEffectOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final ValueNotifier<int> _frame = ValueNotifier<int>(0);

  void _advanceFrame() {
    final nextFrame = (_controller.value * 180).floor();
    if (nextFrame != _frame.value) _frame.value = nextFrame;
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )
      ..addListener(_advanceFrame)
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    _frame.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: _frame,
            builder: (context, child) => CustomPaint(
              painter: _SeasonEffectPainter(
                season: widget.season,
                dayPhase: widget.dayPhase,
                weather: widget.weather,
                // Quantize the painter to 15 distinct frames per second.
                frame: _frame.value,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SeasonEffectPainter extends CustomPainter {
  final Season season;
  final DayPhase dayPhase;
  final WeatherCondition weather;
  final int frame;

  const _SeasonEffectPainter({
    required this.season,
    required this.dayPhase,
    required this.weather,
    required this.frame,
  });

  static const _twoPi = math.pi * 2;

  double _fraction(double value) => value - value.floorToDouble();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final muted = switch (weather) {
      WeatherCondition.heavyRain ||
      WeatherCondition.snow ||
      WeatherCondition.thunderstorm => 0.18,
      WeatherCondition.rain || WeatherCondition.fog => 0.38,
      _ => 1.0,
    };
    final time = frame / 180;

    switch (season) {
      case Season.spring:
        _paintDriftingShapes(canvas, size, time, muted, petals: true);
      case Season.autumn:
        _paintDriftingShapes(canvas, size, time, muted, petals: false);
      case Season.summer:
        _paintSummerLights(canvas, size, time, muted);
      case Season.winter:
        _paintWinterGlints(canvas, size, time, muted);
    }
  }

  // Keep the middle of the map clear for locations and navigation controls.
  Offset _edgePosition(Size size, int index, double y) {
    final left = index.isEven;
    final edge = left ? 0.035 : 0.965;
    final sway = math.sin(y * _twoPi + index * 2.1) * 0.15;
    return Offset(size.width * (edge + (left ? sway.abs() : -sway.abs())),
        size.height * y);
  }

  void _paintDriftingShapes(
    Canvas canvas,
    Size size,
    double time,
    double muted, {
    required bool petals,
  }) {
    final count = petals ? 12 : 10;
    final colors = petals
        ? const [Color(0xFFFFA9C9), Color(0xFFFFD9E9), Color(0xFFFFF0F5)]
        : const [Color(0xFFE98A37), Color(0xFFFFC453), Color(0xFFBB5735)];
    final paint = Paint()..style = PaintingStyle.fill;

    for (var i = 0; i < count; i++) {
      if (muted < 0.4 && i.isOdd) continue;
      final speed = i % 4 == 0 ? 2.0 : 1.0;
      final y = _fraction(i * 0.317 + time * speed);
      final position = _edgePosition(size, i, y);
      final fade = math.min(1.0, math.min(y, 1 - y) * 7);
      final opacity = muted * fade * (petals ? 0.72 : 0.76);
      if (opacity <= 0) continue;

      canvas.save();
      canvas.translate(position.dx, position.dy);
      canvas.rotate(time * (i.isEven ? 1.8 : -1.5) + i * 1.9);
      final radius = (petals ? 5.0 : 6.0) + i % 4;
      final path = petals
          ? (Path()
            ..moveTo(0, -radius)
            ..quadraticBezierTo(radius * 1.4, -radius * 0.5, radius * 0.7, radius)
            ..quadraticBezierTo(0, radius * 1.4, -radius * 0.7, radius)
            ..quadraticBezierTo(-radius * 1.4, -radius * 0.5, 0, -radius))
          : (Path()
            ..moveTo(0, -radius * 1.5)
            ..quadraticBezierTo(radius * 1.5, -radius * 0.3, radius, radius)
            ..quadraticBezierTo(0, radius * 0.7, 0, radius * 1.6)
            ..quadraticBezierTo(0, radius * 0.7, -radius, radius)
            ..quadraticBezierTo(-radius * 1.5, -radius * 0.3, 0, -radius * 1.5));
      paint.color = colors[i % colors.length].withValues(alpha: opacity);
      canvas.drawPath(path, paint);
      canvas.restore();
    }
  }

  void _paintSummerLights(Canvas canvas, Size size, double time, double muted) {
    final night = dayPhase == DayPhase.night || dayPhase == DayPhase.evening;
    final paint = Paint();
    for (var i = 0; i < 11; i++) {
      if (muted < 0.4 && i.isOdd) continue;
      final y = _fraction(i * 0.283 - time);
      final position = _edgePosition(size, i, y);
      final shimmer = 0.5 + 0.5 * math.sin(time * _twoPi * 3 + i * 2.4);
      final opacity = muted * (night ? 0.68 : 0.28) * shimmer;
      final color = night ? const Color(0xFFFFEB8C) : const Color(0xFFFFE7B3);
      paint.color = color.withValues(alpha: opacity * 0.20);
      canvas.drawCircle(position, night ? 10 : 15, paint);
      paint.color = color.withValues(alpha: opacity);
      canvas.drawCircle(position, night ? 2.3 : 1.5, paint);
    }
  }

  void _paintWinterGlints(Canvas canvas, Size size, double time, double muted) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 10; i++) {
      if (muted < 0.4 && i.isOdd) continue;
      final y = _fraction(i * 0.381 - time);
      final position = _edgePosition(size, i, y);
      final shimmer = math.max(0.0, math.sin(time * _twoPi * 2 + i * 2.7));
      paint.color = const Color(0xFFD9F2FF)
          .withValues(alpha: muted * shimmer * 0.75);
      paint.strokeWidth = 1.2;
      final radius = 2.5 + i % 3;
      canvas.drawLine(Offset(position.dx - radius, position.dy),
          Offset(position.dx + radius, position.dy), paint);
      canvas.drawLine(Offset(position.dx, position.dy - radius),
          Offset(position.dx, position.dy + radius), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SeasonEffectPainter oldDelegate) =>
      frame != oldDelegate.frame ||
      season != oldDelegate.season ||
      dayPhase != oldDelegate.dayPhase ||
      weather != oldDelegate.weather;
}
