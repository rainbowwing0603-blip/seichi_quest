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
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _controller;
  final ValueNotifier<int> _frame = ValueNotifier<int>(0);
  bool _reduceMotion = false;

  void _advanceFrame() {
    final nextFrame = (_controller.value * 180).floor();
    if (nextFrame != _frame.value) _frame.value = nextFrame;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..addListener(_advanceFrame);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotionPreference();
  }

  @override
  void didChangeAccessibilityFeatures() {
    _syncMotionPreference();
    setState(() {});
  }

  bool get _weatherSuppressesSeasonAnimation => switch (widget.weather) {
    WeatherCondition.rain ||
    WeatherCondition.heavyRain ||
    WeatherCondition.snow ||
    WeatherCondition.thunderstorm => true,
    _ => false,
  };

  void _syncMotionPreference() {
    _reduceMotion = MediaQuery.disableAnimationsOf(context) ||
        WidgetsBinding.instance.accessibilityFeatures.reduceMotion;
    if (_reduceMotion || _weatherSuppressesSeasonAnimation) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant SeasonEffectOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncMotionPreference();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    _frame.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_reduceMotion || _weatherSuppressesSeasonAnimation) {
      return const SizedBox.shrink();
    }
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
  static final Path _sakuraPetal = Path()
    ..moveTo(0, -0.78)
    ..cubicTo(-0.24, -1.25, -1.05, -0.93, -1.0, -0.22)
    ..cubicTo(-0.95, 0.50, -0.30, 1.06, 0, 1.18)
    ..cubicTo(0.30, 1.06, 0.95, 0.50, 1.0, -0.22)
    ..cubicTo(1.05, -0.93, 0.24, -1.25, 0, -0.78)
    ..close();
  static final Path _mapleLeaf = Path()
    ..moveTo(0, -1.25)
    ..lineTo(0.27, -0.72)
    ..lineTo(0.65, -0.99)
    ..lineTo(0.58, -0.40)
    ..lineTo(1.08, -0.37)
    ..lineTo(0.75, -0.02)
    ..lineTo(0.98, 0.28)
    ..lineTo(0.30, 0.22)
    ..lineTo(0.12, 0.78)
    ..lineTo(0.08, 1.24)
    ..lineTo(-0.08, 1.24)
    ..lineTo(-0.12, 0.78)
    ..lineTo(-0.30, 0.22)
    ..lineTo(-0.98, 0.28)
    ..lineTo(-0.75, -0.02)
    ..lineTo(-1.08, -0.37)
    ..lineTo(-0.58, -0.40)
    ..lineTo(-0.65, -0.99)
    ..lineTo(-0.27, -0.72)
    ..close();
  static final Path _snowCrystal = _buildSnowCrystal();

  static Path _buildSnowCrystal() {
    final path = Path();
    for (var arm = 0; arm < 6; arm++) {
      final angle = arm * math.pi / 3;
      final dx = math.cos(angle);
      final dy = math.sin(angle);
      path.moveTo(0, 0);
      path.lineTo(dx, dy);
      for (final distance in [0.55, 0.78]) {
        final x = dx * distance;
        final y = dy * distance;
        for (final direction in [-1.0, 1.0]) {
          path.moveTo(x, y);
          path.lineTo(
            x - dx * 0.16 + -dy * direction * 0.17,
            y - dy * 0.16 + dx * direction * 0.17,
          );
        }
      }
    }
    return path;
  }

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
  Offset _edgePosition(Size size, int index, double y, double time) {
    final left = index.isEven;
    final edge = left ? 0.035 : 0.965;
    final sway = math.sin(y * _twoPi + index * 2.1 + time * _twoPi) * 0.15;
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
    final count = petals ? 18 : 16;
    final colors = petals
        ? const [Color(0xFFFFA9C9), Color(0xFFFFD9E9), Color(0xFFFFF0F5)]
        : const [Color(0xFFE98A37), Color(0xFFFFC453), Color(0xFFBB5735)];
    final paint = Paint()..style = PaintingStyle.fill;

    for (var depth = 0; depth < 3; depth++) {
      for (var i = depth; i < count; i += 3) {
        if (muted < 0.4 && i.isOdd) continue;
        final speed = depth == 2 ? 2.0 : 1.0;
        final y = _fraction(i * 0.317 + time * speed);
        final position = _edgePosition(size, i, y, time);
        final fade = math.min(1.0, math.min(y, 1 - y) * 7);
        final depthOpacity = [0.35, 0.65, 1.0][depth];
        final opacity = muted * fade * depthOpacity *
            (petals ? 0.72 : 0.76);
        if (opacity <= 0) continue;

        canvas.save();
        canvas.translate(position.dx, position.dy);
        canvas.rotate(
          time * _twoPi * (i.isEven ? 1 : -1) +
              i * 1.9 +
              math.sin(time * _twoPi * 2 + i) * 0.28,
        );
        final radius = ((petals ? 5.0 : 6.0) + i % 4) *
            [0.65, 0.95, 1.35][depth];
        canvas.scale(radius);
        paint.color = colors[i % colors.length].withValues(alpha: opacity);
        canvas.drawPath(petals ? _sakuraPetal : _mapleLeaf, paint);
        canvas.restore();
      }
    }
  }

  void _paintSummerLights(Canvas canvas, Size size, double time, double muted) {
    final night = dayPhase == DayPhase.night || dayPhase == DayPhase.evening;
    final paint = Paint();
    for (var i = 0; i < 15; i++) {
      if (muted < 0.4 && i.isOdd) continue;
      final y = _fraction(i * 0.283) +
          math.sin(time * _twoPi + i * 1.7) * 0.032;
      final position = _edgePosition(size, i, y, time);
      final shimmer = 0.5 + 0.5 * math.sin(time * _twoPi * 3 + i * 2.4);
      final depth = i % 3;
      final scale = [0.65, 0.95, 1.25][depth];
      final opacity = muted * [0.4, 0.7, 1.0][depth] *
          (night ? 0.68 : 0.42) * shimmer;
      final color = night ? const Color(0xFFFFEB8C) : const Color(0xFFFFE7B3);
      canvas.save();
      canvas.translate(position.dx, position.dy);
      canvas.scale(scale);
      paint.color = color.withValues(alpha: opacity * 0.20);
      canvas.drawCircle(Offset.zero, night ? 10 : 12, paint);
      paint.color = color.withValues(alpha: opacity);
      if (night) {
        // Pale wings and a glowing abdomen make this a firefly, not a dot.
        paint.color = Colors.white.withValues(alpha: opacity * 0.55);
        canvas.drawOval(Rect.fromCenter(
          center: const Offset(-3, -2), width: 5, height: 3), paint);
        canvas.drawOval(Rect.fromCenter(
          center: const Offset(3, -2), width: 5, height: 3), paint);
        paint.color = const Color(0xFF344A36).withValues(alpha: opacity);
        canvas.drawOval(Rect.fromCenter(
          center: const Offset(0, -1), width: 2, height: 5), paint);
        paint.color = color.withValues(alpha: opacity);
        canvas.drawCircle(const Offset(0, 2), 2.3, paint);
      } else {
        // Tiny sun motifs suggest summer daylight without washing out the map.
        canvas.drawCircle(Offset.zero, 3.0, paint);
        paint.style = PaintingStyle.stroke;
        paint.strokeWidth = 1.1;
        for (var ray = 0; ray < 8; ray++) {
          final angle = ray * math.pi / 4;
          canvas.drawLine(
            Offset(math.cos(angle) * 5, math.sin(angle) * 5),
            Offset(math.cos(angle) * 8, math.sin(angle) * 8),
            paint,
          );
        }
        paint.style = PaintingStyle.fill;
      }
      canvas.restore();
    }
  }

  void _paintWinterGlints(Canvas canvas, Size size, double time, double muted) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 14; i++) {
      if (muted < 0.4 && i.isOdd) continue;
      final y = _fraction(i * 0.381 - time);
      final position = _edgePosition(size, i, y, time);
      final shimmer = math.max(0.0, math.sin(time * _twoPi * 2 + i * 2.7));
      final depth = i % 3;
      paint.color = const Color(0xFFD9F2FF).withValues(
        alpha: muted * shimmer * [0.3, 0.55, 0.8][depth],
      );
      final radius = (5.0 + i % 3) * [0.65, 0.95, 1.3][depth];
      canvas.save();
      canvas.translate(position.dx, position.dy);
      canvas.rotate(math.sin(time * _twoPi + i) * 0.22);
      canvas.scale(radius);
      paint.strokeWidth = 1.2 / radius;
      canvas.drawPath(_snowCrystal, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _SeasonEffectPainter oldDelegate) =>
      frame != oldDelegate.frame ||
      season != oldDelegate.season ||
      dayPhase != oldDelegate.dayPhase ||
      weather != oldDelegate.weather;
}
