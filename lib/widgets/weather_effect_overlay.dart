import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/real_world_state.dart';

class WeatherEffectOverlay extends StatefulWidget {
  final WeatherCondition weather;
  final DayPhase dayPhase;

  const WeatherEffectOverlay({
    super.key,
    required this.weather,
    required this.dayPhase,
  });

  @override
  State<WeatherEffectOverlay> createState() => _WeatherEffectOverlayState();
}

class _WeatherEffectOverlayState extends State<WeatherEffectOverlay>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _controller;
  final ValueNotifier<int> _frame = ValueNotifier<int>(0);
  bool _reduceMotion = false;

  void _advanceFrame() {
    final nextFrame = (_controller.value * _framesPerCycle).floor();
    if (nextFrame != _frame.value) _frame.value = nextFrame;
  }

  int get _framesPerCycle => switch (widget.weather) {
    WeatherCondition.rain ||
    WeatherCondition.heavyRain ||
    WeatherCondition.snow ||
    WeatherCondition.thunderstorm => 160, // 20画面/秒。雨の勢いを保ちつつMapとの同時描画負荷を抑える
    _ => 120, // ゆっくり動く雲・霧・光は15画面/秒
  };

  bool get _needsAnimation {
    return switch (widget.weather) {
      WeatherCondition.clear ||
      WeatherCondition.partlyCloudy ||
      WeatherCondition.cloudy ||
      WeatherCondition.rain ||
      WeatherCondition.heavyRain ||
      WeatherCondition.snow ||
      WeatherCondition.fog ||
      WeatherCondition.thunderstorm => true,
      WeatherCondition.unknown => false,
    };
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
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

  void _syncMotionPreference() {
    _reduceMotion = MediaQuery.disableAnimationsOf(context) ||
        WidgetsBinding.instance.accessibilityFeatures.reduceMotion;
    _syncAnimation();
  }

  void _syncAnimation() {
    if (_reduceMotion || !_needsAnimation) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant WeatherEffectOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAnimation();
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
    if (_reduceMotion || widget.weather == WeatherCondition.unknown) {
      return const SizedBox.shrink();
    }

    return Positioned.fill(
      child: IgnorePointer(
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: _frame,
            builder: (context, child) {
              return CustomPaint(
                painter: _WeatherEffectPainter(
                  weather: widget.weather,
                  dayPhase: widget.dayPhase,
                  progress:
                      (_controller.value * _framesPerCycle).floor() /
                      _framesPerCycle,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _WeatherEffectPainter extends CustomPainter {
  final WeatherCondition weather;
  final DayPhase dayPhase;
  final double progress;

  const _WeatherEffectPainter({
    required this.weather,
    required this.dayPhase,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    switch (weather) {
      case WeatherCondition.clear:
        _paintSunSparkles(canvas, size);
      case WeatherCondition.partlyCloudy:
        _paintCloudAtmosphere(canvas, size, partlyCloudy: true);
      case WeatherCondition.cloudy:
        _paintCloudAtmosphere(canvas, size, partlyCloudy: false);
      case WeatherCondition.rain:
        _paintRain(canvas, size, heavy: false);
      case WeatherCondition.heavyRain:
        _paintRain(canvas, size, heavy: true);
      case WeatherCondition.snow:
        _paintSnow(canvas, size);
      case WeatherCondition.fog:
        _paintFog(canvas, size);
      case WeatherCondition.thunderstorm:
        _paintThunderstorm(canvas, size);
      case WeatherCondition.unknown:
        break;
    }
  }

  void _paintSunSparkles(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) {
      return;
    }

    final loopAngle = progress * math.pi * 2.0;

    switch (dayPhase) {
      case DayPhase.morning:
        _paintClearMorning(canvas, size, loopAngle);

      case DayPhase.daytime:
        _paintClearDaytime(canvas, size, loopAngle);

      case DayPhase.evening:
        _paintClearEvening(canvas, size, loopAngle);

      case DayPhase.night:
        _paintClearNight(canvas, size, loopAngle);
    }
  }

  void _paintClearMorning(Canvas canvas, Size size, double loopAngle) {
    final breathe =
        0.92 +
        math.sin(loopAngle + 0.45) * 0.055 +
        math.sin(loopAngle * 2.0 + 1.8) * 0.020;

    // 左上から入る朝の暖かい光。
    final glowRect = Rect.fromCircle(
      center: Offset(size.width * 0.04, size.height * 0.12),
      radius: size.width * 0.92,
    );

    final glowPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.78, -0.62),
        radius: 1.0,
        colors: [
          const Color(0xFFFFCF82).withValues(alpha: 0.155 * breathe),
          const Color(0xFFFFE2AD).withValues(alpha: 0.075 * breathe),
          const Color(0xFFFFF2D7).withValues(alpha: 0.025 * breathe),
          Colors.transparent,
        ],
        stops: const [0.0, 0.34, 0.68, 1.0],
      ).createShader(glowRect);

    canvas.drawRect(Offset.zero & size, glowPaint);

    // 朝の斜めの光筋。地図を塗りつぶさないよう薄くする。
    final rayPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFFFFE0A3).withValues(alpha: 0.105 * breathe),
          const Color(0xFFFFEDC7).withValues(alpha: 0.040 * breathe),
          Colors.transparent,
        ],
        stops: const [0.0, 0.46, 1.0],
      ).createShader(Offset.zero & size);

    final rayPath = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width * 0.24, 0)
      ..lineTo(size.width * 0.70, size.height)
      ..lineTo(size.width * 0.46, size.height)
      ..close();

    canvas.drawPath(rayPath, rayPaint);

    _paintClearLightParticles(
      canvas,
      size,
      loopAngle,
      count: 7,
      baseOpacity: 0.24,
      warm: true,
    );
  }

  void _paintClearDaytime(Canvas canvas, Size size, double loopAngle) {
    final breathe =
        0.94 +
        math.sin(loopAngle + 0.30) * 0.035 +
        math.sin(loopAngle * 2.0 + 2.20) * 0.015;

    // 昼は白い太陽光を明確に見せる。
    final glowRect = Rect.fromCircle(
      center: Offset(size.width * 0.04, size.height * 0.04),
      radius: size.width * 0.88,
    );

    final glowPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.82, -0.82),
        radius: 1.0,
        colors: [
          Colors.white.withValues(alpha: 0.27 * breathe),
          const Color(0xFFFFF5CF).withValues(alpha: 0.13 * breathe),
          Colors.white.withValues(alpha: 0.025 * breathe),
          Colors.transparent,
        ],
        stops: const [0.0, 0.32, 0.66, 1.0],
      ).createShader(glowRect);

    canvas.drawRect(Offset.zero & size, glowPaint);

    // 左上から画面へ差し込む大きな光芒。
    final wideRayPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.18 * breathe),
          const Color(0xFFFFF6D9).withValues(alpha: 0.075 * breathe),
          Colors.transparent,
        ],
        stops: const [0.0, 0.48, 1.0],
      ).createShader(Offset.zero & size);

    final wideRayPath = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width * 0.32, 0)
      ..lineTo(size.width * 0.82, size.height)
      ..lineTo(size.width * 0.50, size.height)
      ..close();

    canvas.drawPath(wideRayPath, wideRayPaint);

    // もう一本、細く弱い光を重ねて奥行きを出す。
    final narrowRayPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.090 * breathe),
          Colors.white.withValues(alpha: 0.018 * breathe),
          Colors.transparent,
        ],
        stops: const [0.0, 0.42, 1.0],
      ).createShader(Offset.zero & size);

    final narrowRayPath = Path()
      ..moveTo(size.width * 0.12, 0)
      ..lineTo(size.width * 0.22, 0)
      ..lineTo(size.width * 0.57, size.height)
      ..lineTo(size.width * 0.46, size.height)
      ..close();

    canvas.drawPath(narrowRayPath, narrowRayPaint);

    _paintClearLightParticles(
      canvas,
      size,
      loopAngle,
      count: 9,
      baseOpacity: 0.28,
      warm: false,
    );
  }

  void _paintClearEvening(Canvas canvas, Size size, double loopAngle) {
    // MapPage側の紫→橙グラデーションを残しつつ、
    // 晴れの日だけ西日をはっきり感じられる強さにする。
    final breathe =
        0.92 +
        math.sin(loopAngle + 1.10) * 0.045 +
        math.sin(loopAngle * 2.0 + 0.70) * 0.018;

    final glowRect = Rect.fromCircle(
      center: Offset(size.width * 0.02, size.height * 0.34),
      radius: size.width * 0.86,
    );

    final glowPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.84, -0.18),
        radius: 1.0,
        colors: [
          const Color(0xFFFFA76C).withValues(alpha: 0.125 * breathe),
          const Color(0xFFFFC895).withValues(alpha: 0.060 * breathe),
          const Color(0xFFFFE4C6).withValues(alpha: 0.018 * breathe),
          Colors.transparent,
        ],
        stops: const [0.0, 0.36, 0.68, 1.0],
      ).createShader(glowRect);

    canvas.drawRect(Offset.zero & size, glowPaint);

    final rayPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFFFFC28E).withValues(alpha: 0.075 * breathe),
          const Color(0xFFFFDDBB).withValues(alpha: 0.025 * breathe),
          Colors.transparent,
        ],
        stops: const [0.0, 0.48, 1.0],
      ).createShader(Offset.zero & size);

    final rayPath = Path()
      ..moveTo(0, size.height * 0.14)
      ..lineTo(0, size.height * 0.34)
      ..lineTo(size.width * 0.68, size.height)
      ..lineTo(size.width * 0.43, size.height)
      ..close();

    canvas.drawPath(rayPath, rayPaint);
  }

  void _paintClearNight(Canvas canvas, Size size, double loopAngle) {
    // 夜は太陽光・暖色フレア・昼のキラキラを完全に停止。
    // 夜マップを主役にし、澄んだ冷たい空気だけを極薄く重ねる。
    final breathe =
        0.90 +
        math.sin(loopAngle + 0.80) * 0.035 +
        math.sin(loopAngle * 2.0 + 2.40) * 0.015;

    final clearNightPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF9FC7E8).withValues(alpha: 0.020 * breathe),
          const Color(0xFF5D87AE).withValues(alpha: 0.008 * breathe),
          Colors.transparent,
        ],
        stops: const [0.0, 0.48, 1.0],
      ).createShader(Offset.zero & size);

    canvas.drawRect(Offset.zero & size, clearNightPaint);
  }

  void _paintClearLightParticles(
    Canvas canvas,
    Size size,
    double loopAngle, {
    required int count,
    required double baseOpacity,
    required bool warm,
  }) {
    final particlePaint = Paint()..strokeCap = StrokeCap.round;

    for (var i = 0; i < count; i++) {
      final xSeed = ((i * 83 + 41) % 997) / 997.0;

      final ySeed = ((i * 137 + 73) % 991) / 991.0;

      final phase = loopAngle + i * 1.71;

      final pulse = 0.5 + math.sin(phase) * 0.5;

      // 常時点滅させず、明るい瞬間だけごく薄く見せる。
      if (pulse < 0.68) {
        continue;
      }

      final x = 16 + xSeed * math.max(size.width - 32, 1.0);

      final y = 24 + ySeed * math.max(size.height * 0.72, 1.0);

      final radius = 0.7 + pulse * 1.15;

      final opacity = baseOpacity * ((pulse - 0.68) / 0.32);

      particlePaint
        ..color = (warm ? const Color(0xFFFFE4B5) : Colors.white).withValues(
          alpha: opacity.clamp(0.0, 1.0),
        )
        ..strokeWidth = 0.75 + pulse * 0.35;

      canvas.drawLine(
        Offset(x - radius, y),
        Offset(x + radius, y),
        particlePaint,
      );

      canvas.drawLine(
        Offset(x, y - radius),
        Offset(x, y + radius),
        particlePaint,
      );
    }
  }

  void _paintCloudAtmosphere(
    Canvas canvas,
    Size size, {
    required bool partlyCloudy,
  }) {
    if (size.width <= 0 || size.height <= 0) {
      return;
    }

    double hash(int value, int salt) {
      final n = math.sin(value * 12.9898 + salt * 78.233) * 43758.5453;
      return n - n.floorToDouble();
    }

    final loopAngle = progress * math.pi * 2.0;

    // 時間帯ごとの雲の空気色。
    final Color atmosphereColor;
    final double atmosphereOpacity;
    final Color shadowCoreColor;
    final Color shadowMidColor;
    final double shadowOpacityFactor;

    switch (dayPhase) {
      case DayPhase.morning:
        atmosphereColor = const Color(0xFF8A8790);
        atmosphereOpacity = partlyCloudy ? 0.055 : 0.185;
        shadowCoreColor = const Color(0xFF657180);
        shadowMidColor = const Color(0xFF89929A);
        shadowOpacityFactor = 0.88;

      case DayPhase.daytime:
        atmosphereColor = const Color(0xFF647887);
        atmosphereOpacity = partlyCloudy ? 0.050 : 0.195;
        shadowCoreColor = const Color(0xFF526879);
        shadowMidColor = const Color(0xFF718594);
        shadowOpacityFactor = 1.0;

      case DayPhase.evening:
        atmosphereColor = const Color(0xFF756E80);
        atmosphereOpacity = partlyCloudy ? 0.060 : 0.190;
        shadowCoreColor = const Color(0xFF5E6170);
        shadowMidColor = const Color(0xFF817B86);
        shadowOpacityFactor = 0.92;

      case DayPhase.night:
        atmosphereColor = const Color(0xFF26384D);
        atmosphereOpacity = partlyCloudy ? 0.065 : 0.205;
        shadowCoreColor = const Color(0xFF1E3045);
        shadowMidColor = const Color(0xFF354A60);
        shadowOpacityFactor = 0.82;
    }

    final baseWashPaint = Paint()
      ..color = atmosphereColor.withValues(
        alpha: partlyCloudy ? atmosphereOpacity : 0.075,
      );

    canvas.drawRect(Offset.zero & size, baseWashPaint);

    // 晴れ時々曇りでは雲間の光を時間帯に合わせる。
    // 夜だけは太陽光を完全に出さない。
    if (partlyCloudy && dayPhase != DayPhase.night) {
      final sunlightStrength =
          0.72 +
          math.sin(loopAngle + 0.55) * 0.12 +
          math.sin(loopAngle * 2.0 + 2.1) * 0.05;

      final Color sunlightCore;
      final Color sunlightOuter;
      final double coreOpacity;
      final double outerOpacity;
      final Offset sunlightCenter;

      switch (dayPhase) {
        case DayPhase.morning:
          sunlightCore = const Color(0xFFFFD59A);
          sunlightOuter = const Color(0xFFFFE9C4);
          coreOpacity = 0.110;
          outerOpacity = 0.046;
          sunlightCenter = Offset(size.width * 0.12, size.height * 0.16);

        case DayPhase.daytime:
          sunlightCore = const Color(0xFFFFF9E8);
          sunlightOuter = Colors.white;
          coreOpacity = 0.095;
          outerOpacity = 0.040;
          sunlightCenter = Offset(size.width * 0.20, size.height * 0.12);

        case DayPhase.evening:
          sunlightCore = const Color(0xFFFFB47B);
          sunlightOuter = const Color(0xFFFFD0A5);
          coreOpacity = 0.095;
          outerOpacity = 0.038;
          sunlightCenter = Offset(size.width * 0.08, size.height * 0.30);

        case DayPhase.night:
          sunlightCore = Colors.transparent;
          sunlightOuter = Colors.transparent;
          coreOpacity = 0.0;
          outerOpacity = 0.0;
          sunlightCenter = Offset.zero;
      }

      final sunlightRect = Rect.fromCircle(
        center: sunlightCenter,
        radius: size.width * 0.82,
      );

      final sunlightPaint = Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.55, -0.62),
          radius: 1.0,
          colors: [
            sunlightCore.withValues(alpha: coreOpacity * sunlightStrength),
            sunlightOuter.withValues(alpha: outerOpacity * sunlightStrength),
            Colors.transparent,
          ],
          stops: const [0.0, 0.48, 1.0],
        ).createShader(sunlightRect);

      canvas.drawRect(Offset.zero & size, sunlightPaint);
    }

    void paintShadowField({
      required int count,
      required int seedOffset,
      required double minWidthFactor,
      required double maxWidthFactor,
      required double minHeightFactor,
      required double maxHeightFactor,
      required double minOpacity,
      required double maxOpacity,
      required double horizontalRange,
      required double verticalRange,
    }) {
      for (var i = 0; i < count; i++) {
        final seed = i + seedOffset * 1000;

        final xSeed = hash(seed, 1);
        final ySeed = hash(seed, 2);
        final widthSeed = hash(seed, 3);
        final heightSeed = hash(seed, 4);
        final opacitySeed = hash(seed, 5);
        final phaseSeed = hash(seed, 6);
        final shapeSeed = hash(seed, 7);

        final width =
            size.width *
            (minWidthFactor + (maxWidthFactor - minWidthFactor) * widthSeed);

        final height =
            size.height *
            (minHeightFactor +
                (maxHeightFactor - minHeightFactor) * heightSeed);

        final baseX = -width * 0.12 + xSeed * (size.width + width * 0.24);

        final baseY = -height * 0.05 + ySeed * (size.height + height * 0.10);

        final phaseOffset = phaseSeed * math.pi * 2.0;

        // 整数周期でループ境界を滑らかに保つ。
        final cycle = 1 + ((phaseSeed * 2.0).floor() % 2);

        final angle = loopAngle * cycle + phaseOffset;

        final driftX =
            math.sin(angle) * horizontalRange * (0.55 + shapeSeed * 0.45) +
            math.sin(angle * 2.0 + phaseOffset) * horizontalRange * 0.10;

        final driftY =
            math.cos(angle + shapeSeed * math.pi) *
            verticalRange *
            (0.55 + heightSeed * 0.45);

        final breathe =
            0.82 +
            math.sin(angle + opacitySeed * math.pi * 2.0) * 0.13 +
            math.sin(angle * 2.0 + shapeSeed * math.pi) * 0.05;

        final opacity =
            (minOpacity + (maxOpacity - minOpacity) * opacitySeed) *
            breathe *
            shadowOpacityFactor;

        for (var blob = 0; blob < 4; blob++) {
          final blobSeed = hash(seed, 20 + blob);

          final blobShapeSeed = hash(seed, 30 + blob);

          final blobAngle = angle + blob * 1.57 + blobSeed * 0.8;

          final centerX =
              baseX +
              driftX +
              math.sin(blobAngle) * width * (0.10 + blobSeed * 0.08);

          final centerY =
              baseY +
              driftY +
              math.cos(blobAngle * 0.72) *
                  height *
                  (0.08 + blobShapeSeed * 0.06);

          final blobWidth = width * (0.70 + blobSeed * 0.32);

          final blobHeight = height * (0.72 + blobShapeSeed * 0.28);

          final rect = Rect.fromCenter(
            center: Offset(centerX, centerY),
            width: blobWidth,
            height: blobHeight,
          );

          final blobOpacity = opacity * (0.62 + blobSeed * 0.30);

          final shadowPaint = Paint()
            ..shader = RadialGradient(
              center: Alignment(
                (blobSeed - 0.5) * 0.22,
                (blobShapeSeed - 0.5) * 0.16,
              ),
              radius: 0.82,
              colors: [
                shadowCoreColor.withValues(alpha: blobOpacity),
                shadowMidColor.withValues(alpha: blobOpacity * 0.55),
                shadowMidColor.withValues(alpha: blobOpacity * 0.16),
                Colors.transparent,
              ],
              stops: const [0.0, 0.46, 0.76, 1.0],
            ).createShader(rect);

          canvas.drawOval(rect, shadowPaint);
        }
      }
    }

    if (!partlyCloudy) {
      // 曇天は中央へ雲オブジェクトを浮かべず、画面の縁から
      // 柔らかい雲海が入り込む構図にする。中央は地図の可読域として残す。
      final cloudColor = switch (dayPhase) {
        DayPhase.morning => const Color(0xFFC0C8CD),
        DayPhase.daytime => const Color(0xFFC6CED2),
        DayPhase.evening => const Color(0xFFB9B5BE),
        DayPhase.night => const Color(0xFF8394A3),
      };
      final cloudShade = switch (dayPhase) {
        DayPhase.morning => const Color(0xFF687681),
        DayPhase.daytime => const Color(0xFF657580),
        DayPhase.evening => const Color(0xFF696875),
        DayPhase.night => const Color(0xFF42586A),
      };

      final cloudPaint = Paint();

      void paintEdgeCloud({
        required Offset center,
        required double width,
        required double height,
        required double phase,
      }) {
        // 1つの連続Pathで雲の外形を作る。
        // 個別の楕円を重ねないため、内部にローブの継ぎ目は存在しない。
        final breathe = 1.0 + math.sin(phase * 0.5) * 0.025;
        final w = width * breathe;
        final h = height;
        final left = center.dx - w * 0.58;
        final right = center.dx + w * 0.58;
        final top = center.dy - h * 0.56;
        final bottom = center.dy + h * 0.48;

        // 見える輪郭は非周期的な1本のカーブにし、閉路は十分外側で閉じる。
        // これで画面内に尖った始点・終点や「雲アイコン」の底辺を出さない。
        final path = Path()
          ..moveTo(left - w * 0.24, bottom + h * 0.62)
          ..lineTo(left - w * 0.24, center.dy + h * 0.10)
          ..cubicTo(
            left - w * 0.10,
            center.dy + h * 0.02,
            left + w * 0.02,
            center.dy + h * 0.08,
            left + w * 0.12,
            center.dy - h * 0.04,
          )
          ..cubicTo(
            left + w * 0.18,
            center.dy - h * 0.24,
            left + w * 0.31,
            center.dy - h * 0.14,
            left + w * 0.38,
            center.dy - h * 0.25,
          )
          ..cubicTo(
            left + w * 0.47,
            top - h * 0.06,
            left + w * 0.59,
            top + h * 0.06,
            left + w * 0.64,
            center.dy - h * 0.20,
          )
          ..cubicTo(
            left + w * 0.70,
            center.dy - h * 0.08,
            left + w * 0.77,
            center.dy - h * 0.18,
            left + w * 0.83,
            center.dy - h * 0.10,
          )
          ..cubicTo(
            left + w * 0.91,
            center.dy - h * 0.01,
            right + w * 0.05,
            center.dy - h * 0.04,
            right + w * 0.18,
            center.dy + h * 0.11,
          )
          ..lineTo(right + w * 0.24, bottom + h * 0.62)
          ..close();
        final bounds = path.getBounds();
        cloudPaint.shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            cloudColor.withValues(
              alpha: dayPhase == DayPhase.night ? 0.24 : 0.22,
            ),
            cloudColor.withValues(
              alpha: dayPhase == DayPhase.night ? 0.20 : 0.18,
            ),
            cloudShade.withValues(
              alpha: dayPhase == DayPhase.night ? 0.15 : 0.13,
            ),
          ],
          stops: const [0.0, 0.52, 1.0],
        ).createShader(bounds);
        canvas.drawPath(path, cloudPaint);

      }

      // 上端の大きな雲海。HUDの背後から地図へ少しだけ入り込む。
      paintEdgeCloud(
        center: Offset(
          size.width * 0.28 + math.sin(loopAngle * 0.5) * size.width * 0.025,
          -size.height * 0.015,
        ),
        width: size.width * 0.92,
        height: size.height * 0.21,
        phase: loopAngle,
      );
      paintEdgeCloud(
        center: Offset(
          size.width * 0.82 + math.sin(loopAngle * 0.5 + 2.0) * size.width * 0.02,
          size.height * 0.045,
        ),
        width: size.width * 0.76,
        height: size.height * 0.19,
        phase: loopAngle + 2.0,
      );

      // 左右の縁にも薄い雲を置き、画面中央は空ける。
      paintEdgeCloud(
        center: Offset(
          -size.width * 0.25,
          size.height * 0.42 + math.sin(loopAngle * 0.5 + 1.0) * size.height * 0.018,
        ),
        width: size.width * 0.62,
        height: size.height * 0.17,
        phase: loopAngle + 1.0,
      );
      paintEdgeCloud(
        center: Offset(
          size.width * 1.24,
          size.height * 0.62 + math.sin(loopAngle * 0.5 + 3.0) * size.height * 0.018,
        ),
        width: size.width * 0.66,
        height: size.height * 0.18,
        phase: loopAngle + 3.0,
      );
    }

    if (partlyCloudy) {
      paintShadowField(
        count: 3,
        seedOffset: 71,
        minWidthFactor: 0.72,
        maxWidthFactor: 1.16,
        minHeightFactor: 0.24,
        maxHeightFactor: 0.42,
        minOpacity: 0.040,
        maxOpacity: 0.085,
        horizontalRange: 24,
        verticalRange: 8,
      );
    }
  }

  void _paintRain(Canvas canvas, Size size, {required bool heavy}) {
    // 雨粒そのものは維持し、雨の向こう側の空気色だけを
    // 時間帯へ馴染ませる。
    final Color rainAtmosphereColor;
    final double rainAtmosphereOpacity;

    switch (dayPhase) {
      case DayPhase.morning:
        rainAtmosphereColor = const Color(0xFF6D8191);
        rainAtmosphereOpacity = heavy ? 0.075 : 0.045;

      case DayPhase.daytime:
        rainAtmosphereColor = const Color(0xFF617889);
        rainAtmosphereOpacity = heavy ? 0.085 : 0.050;

      case DayPhase.evening:
        rainAtmosphereColor = const Color(0xFF686579);
        rainAtmosphereOpacity = heavy ? 0.080 : 0.048;

      case DayPhase.night:
        rainAtmosphereColor = const Color(0xFF1E3550);
        rainAtmosphereOpacity = heavy ? 0.110 : 0.070;
    }

    final rainAtmospherePaint = Paint()
      ..color = rainAtmosphereColor.withValues(alpha: rainAtmosphereOpacity);

    canvas.drawRect(Offset.zero & size, rainAtmospherePaint);

    final washPaint = Paint()
      ..color = const Color(0xFF294B68).withValues(alpha: heavy ? 0.18 : 0.095);

    canvas.drawRect(Offset.zero & size, washPaint);

    double hash(int value, int salt) {
      final n = math.sin(value * 12.9898 + salt * 78.233) * 43758.5453;
      return n - n.floorToDouble();
    }

    void paintLayer({
      required int count,
      required int seedOffset,
      required double baseSpeed,
      required double baseLength,
      required double baseStrokeWidth,
      required double baseOpacity,
      required double baseSlant,
    }) {
      final travelWidth = size.width + 180;
      // Paintを雨粒ごとに生成しない。1レイヤーにつき1個を再利用して、
      // 雨量感を保ったままGCとオブジェクト生成負荷を抑える。
      final rainPaint = Paint()..strokeCap = StrokeCap.round;

      for (var i = 0; i < count; i++) {
        final seed = i + seedOffset * 1000;

        final seedX = hash(seed, 1);
        final seedY = hash(seed, 2);
        final speedNoise = hash(seed, 3);
        final lengthNoise = hash(seed, 4);
        final opacityNoise = hash(seed, 5);
        final slantNoise = hash(seed, 6);
        final widthNoise = hash(seed, 7);
        final driftNoise = hash(seed, 8);

        final speed = baseSpeed * (0.78 + speedNoise * 0.48);

        final length = baseLength * (0.72 + lengthNoise * 0.62);

        final strokeWidth = baseStrokeWidth * (0.72 + widthNoise * 0.56);

        final opacity = baseOpacity * (0.70 + opacityNoise * 0.42);

        final slant = baseSlant + (slantNoise - 0.5) * 0.12;

        final travelHeight = size.height + length + 150;

        final phase = (seedY + progress * speed + driftNoise * 0.31) % 1.0;

        final y = phase * travelHeight - length - 40;

        // 粒ごとに横方向の移動量も変える。
        // 雨筋が同じ位置に固まって見えるのを防ぐ。
        final horizontalTravel = progress * speed * (65 + driftNoise * 110);

        final x =
            (seedX * travelWidth + horizontalTravel + phase * length * slant) %
                travelWidth -
            90;

        rainPaint
          ..color = const Color(0xFFE1F4FF)
              .withValues(alpha: opacity.clamp(0.0, 1.0))
          ..strokeWidth = strokeWidth;

        canvas.drawLine(
          Offset(x, y),
          Offset(x - length * slant, y + length),
          rainPaint,
        );
      }
    }

    // 遠景。細い雨を広く散らして雨量を作る。
    paintLayer(
      count: heavy ? 90 : 52,
      seedOffset: 11,
      baseSpeed: heavy ? 2.35 : 1.70,
      baseLength: heavy ? 15 : 11,
      baseStrokeWidth: heavy ? 0.85 : 0.65,
      baseOpacity: heavy ? 0.31 : 0.21,
      baseSlant: 0.23,
    );

    // 中景。雨として認識しやすい主レイヤー。
    paintLayer(
      count: heavy ? 68 : 38,
      seedOffset: 29,
      baseSpeed: heavy ? 3.15 : 2.30,
      baseLength: heavy ? 27 : 21,
      baseStrokeWidth: heavy ? 1.30 : 1.0,
      baseOpacity: heavy ? 0.53 : 0.41,
      baseSlant: 0.29,
    );

    // 近景。少数の長い雨筋だけを高速で通す。
    paintLayer(
      count: heavy ? 30 : 16,
      seedOffset: 47,
      baseSpeed: heavy ? 4.25 : 3.15,
      baseLength: heavy ? 47 : 36,
      baseStrokeWidth: heavy ? 1.90 : 1.45,
      baseOpacity: heavy ? 0.72 : 0.58,
      baseSlant: 0.34,
    );

    // 前景は「濡れた窓」を主役にする。雨筋を無限に増やす代わりに、
    // 上部の薄い濡れ膜と大きな水滴で奥行きと雨量感を出す。
    _paintWetGlassAtmosphere(canvas, size, heavy: heavy);
    _paintGlassRaindrops(canvas, size, heavy: heavy);
    _paintRainRipples(canvas, size, heavy: heavy);
  }

  void _paintWetGlassAtmosphere(
    Canvas canvas,
    Size size, {
    required bool heavy,
  }) {
    if (size.width <= 0 || size.height <= 0) return;

    // 画面全体をぼかさず、上部だけに薄い濡れ膜を置く。
    // GoogleMapをBackdropFilterで再サンプリングしないので描画コストを抑えられる。
    final breath =
        0.92 + math.sin(progress * math.pi * 2.0) * (heavy ? 0.06 : 0.035);
    final rect = Offset.zero & size;
    final filmPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFFE8F7FF).withValues(
            alpha: (heavy ? 0.115 : 0.070) * breath,
          ),
          const Color(0xFFB7D8E8).withValues(
            alpha: (heavy ? 0.045 : 0.025) * breath,
          ),
          Colors.transparent,
        ],
        stops: const [0.0, 0.30, 0.68],
      ).createShader(rect);
    canvas.drawRect(rect, filmPaint);

    // 少数の長い濡れ筋。数ではなく長さと明暗で「窓を伝う雨」を感じさせる。
    final streakPaint = Paint()
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final count = heavy ? 7 : 4;
    for (var i = 0; i < count; i++) {
      final xSeed = ((i * 193 + 61) % 991) / 991.0;
      final phaseSeed = ((i * 271 + 47) % 983) / 983.0;
      final phase = (phaseSeed + progress * (0.34 + i * 0.018)) % 1.0;
      final x =
          18.0 + xSeed * math.max(size.width - 36.0, 1.0) +
          math.sin(progress * math.pi * 2.0 + i) * 2.0;
      final headY = -70.0 + phase * (size.height + 140.0);
      final length = (heavy ? 105.0 : 76.0) + (i % 3) * 16.0;

      streakPaint
        ..color = const Color(0xFFDDF5FF).withValues(
          alpha: heavy ? 0.17 : 0.11,
        )
        ..strokeWidth = heavy ? 1.45 : 1.05;

      final path = Path()
        ..moveTo(x, headY - length)
        ..cubicTo(
          x - 2.2,
          headY - length * 0.70,
          x + 3.0,
          headY - length * 0.34,
          x,
          headY,
        );
      canvas.drawPath(path, streakPaint);
    }
  }

  void _paintRainRipples(Canvas canvas, Size size, {required bool heavy}) {
    final count = heavy ? 10 : 6;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    for (var i = 0; i < count; i++) {
      final phase = (progress * (heavy ? 7.0 : 5.0) + i * 0.618) % 1.0;
      final x = size.width * (((i * 73 + 19) % 101) / 101.0);
      final y = size.height * (0.72 + ((i * 29 + 11) % 23) / 100.0);
      final radius = 2.0 + phase * (heavy ? 13.0 : 9.0);
      paint.color = const Color(0xFFDEF5FF).withValues(
        alpha: (1.0 - phase) * (heavy ? 0.32 : 0.20),
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x, y),
          width: radius * 2.0,
          height: radius * 0.8,
        ),
        paint,
      );
    }
  }

  void _paintGlassRaindrops(Canvas canvas, Size size, {required bool heavy}) {
    if (size.width <= 0 || size.height <= 0) {
      return;
    }

    // ガラス面に留まる小さな水滴。
    final staticDropCount = heavy ? 20 : 14;

    for (var i = 0; i < staticDropCount; i++) {
      final seedX = ((i * 137 + 29) % 997) / 997.0;
      final seedY = ((i * 223 + 71) % 991) / 991.0;
      final sizeSeed = ((i * 59 + 17) % 101) / 101.0;

      final x = 10 + seedX * math.max(size.width - 20, 1.0);
      final y = 10 + seedY * math.max(size.height - 20, 1.0);

      final pulse = 0.92 + math.sin(progress * math.pi * 2 + i * 0.73) * 0.08;

      final radius = (1.3 + sizeSeed * 2.4) * pulse;

      _drawGlassDrop(
        canvas,
        center: Offset(x, y),
        radiusX: radius * (0.86 + sizeSeed * 0.12),
        radiusY: radius * (1.05 + sizeSeed * 0.22),
        opacity: 0.18 + sizeSeed * 0.15,
      );
    }

    // 大きくなった水滴だけが重力で流れる。
    final movingDropCount = heavy ? 8 : 5;

    for (var i = 0; i < movingDropCount; i++) {
      final seedX = ((i * 181 + 43) % 983) / 983.0;
      final seedPhase = ((i * 269 + 31) % 977) / 977.0;
      final sizeSeed = ((i * 47 + 23) % 97) / 97.0;

      final cycleSpeed = heavy
          ? 0.48 + sizeSeed * 0.18
          : 0.34 + sizeSeed * 0.14;

      final phase = (seedPhase + progress * cycleSpeed * 2.0) % 1.0;

      // 最初の約30%はガラス面に溜まっている。
      final resting = phase < 0.30;

      final fallPhase = resting ? 0.0 : ((phase - 0.30) / 0.70).clamp(0.0, 1.0);

      // 落下開始はゆっくり、その後に加速。
      final gravityProgress = fallPhase * fallPhase;

      final startY =
          -20.0 + (((i * 113 + 37) % 401) / 401.0) * size.height * 0.34;

      final travelDistance = size.height + 130;

      final y = startY + gravityProgress * travelDistance;

      // 水滴は完全な直線ではなく少し蛇行する。
      final wobble =
          math.sin(fallPhase * math.pi * 2.1 + i * 1.37) *
          (1.1 + sizeSeed * 2.2);

      final x = 14 + seedX * math.max(size.width - 28, 1.0) + wobble;

      final baseRadius = 3.5 + sizeSeed * 3.2;

      final stretch = resting ? 1.05 : 1.15 + gravityProgress * 1.65;

      // 流れた跡の細い濡れ筋。
      if (!resting && fallPhase > 0.05) {
        final trailLength = 18.0 + gravityProgress * (heavy ? 82.0 : 62.0);

        final trailPaint = Paint()
          ..shader =
              LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: 0.02),
                  const Color(0xFFD8F0FA)
                      .withValues(alpha: heavy ? 0.20 : 0.15),
                  const Color(0xFF9BC4D5).withValues(alpha: 0.05),
                ],
              ).createShader(
                Rect.fromLTWH(x - 2.5, y - trailLength, 5, trailLength),
              )
          ..strokeWidth = 1.3 + sizeSeed * 0.8
          ..strokeCap = StrokeCap.round;

        final trailPath = Path()
          ..moveTo(x, y - trailLength)
          ..cubicTo(
            x - 2.0,
            y - trailLength * 0.70,
            x + 2.5,
            y - trailLength * 0.35,
            x,
            y - baseRadius,
          );

        canvas.drawPath(trailPath, trailPaint);
      }

      _drawGlassDrop(
        canvas,
        center: Offset(x, y),
        radiusX: baseRadius * (0.78 - gravityProgress * 0.08),
        radiusY: baseRadius * stretch,
        opacity: heavy ? 0.55 : 0.45,
      );
    }
  }

  void _drawGlassDrop(
    Canvas canvas, {
    required Offset center,
    required double radiusX,
    required double radiusY,
    required double opacity,
  }) {
    final rect = Rect.fromCenter(
      center: center,
      width: radiusX * 2,
      height: radiusY * 2,
    );

    // 水滴本体。中心は透明感を残し、縁を少し濃くする。
    final bodyPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.30, -0.35),
        radius: 0.95,
        colors: [
          Colors.white.withValues(alpha: opacity * 0.58),
          const Color(0xFFD9F2FC).withValues(alpha: opacity * 0.28),
          const Color(0xFF6E9EB3).withValues(alpha: opacity * 0.42),
        ],
        stops: const [0.0, 0.58, 1.0],
      ).createShader(rect);

    canvas.drawOval(rect, bodyPaint);

    // 水滴の暗い下縁。背景との境界を作る。
    final rimPaint = Paint()
      ..color = const Color(0xFF315B70).withValues(alpha: opacity * 0.24)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    canvas.drawOval(rect, rimPaint);

    // 窓ガラスに光が反射しているようなハイライト。
    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: opacity * 0.68)
      ..strokeWidth = math.max(0.8, radiusX * 0.18)
      ..strokeCap = StrokeCap.round;

    final highlightStart = Offset(
      center.dx - radiusX * 0.34,
      center.dy - radiusY * 0.40,
    );

    final highlightEnd = Offset(
      center.dx - radiusX * 0.10,
      center.dy - radiusY * 0.23,
    );

    canvas.drawLine(highlightStart, highlightEnd, highlightPaint);

    // 下側に小さな屈折光。
    final refractionPaint = Paint()
      ..color = const Color(0xFFEAF8FF).withValues(alpha: opacity * 0.34);

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx + radiusX * 0.18, center.dy + radiusY * 0.32),
        width: math.max(1.2, radiusX * 0.55),
        height: math.max(0.9, radiusY * 0.18),
      ),
      refractionPaint,
    );
  }

  void _paintSnow(Canvas canvas, Size size) {
    // 雪粒の3レイヤーはそのまま維持し、
    // 背景の空気色だけを時間帯へ馴染ませる。
    final Color snowAtmosphereColor;
    final double snowAtmosphereOpacity;

    switch (dayPhase) {
      case DayPhase.morning:
        snowAtmosphereColor = const Color(0xFFD8E6EE);
        snowAtmosphereOpacity = 0.08;

      case DayPhase.daytime:
        snowAtmosphereColor = const Color(0xFFE7F0F5);
        snowAtmosphereOpacity = 0.09;

      case DayPhase.evening:
        snowAtmosphereColor = const Color(0xFF9B91AA);
        snowAtmosphereOpacity = 0.075;

      case DayPhase.night:
        snowAtmosphereColor = const Color(0xFF294765);
        snowAtmosphereOpacity = 0.12;
    }

    final snowAtmospherePaint = Paint()
      ..color = snowAtmosphereColor.withValues(alpha: snowAtmosphereOpacity);

    canvas.drawRect(Offset.zero & size, snowAtmospherePaint);

    if (size.width <= 0 || size.height <= 0) {
      return;
    }

    final washPaint = Paint()
      ..color = const Color(0xFFDCEEFF).withValues(alpha: 0.10);

    canvas.drawRect(Offset.zero & size, washPaint);

    double hash(int value, int salt) {
      final n = math.sin(value * 12.9898 + salt * 78.233) * 43758.5453;
      return n - n.floorToDouble();
    }

    void paintSnowLayer({
      required int count,
      required int seedOffset,
      required double baseSpeed,
      required double minRadius,
      required double maxRadius,
      required double minOpacity,
      required double maxOpacity,
      required double swayAmount,
      required double swaySpeed,
      required bool foreground,
    }) {
      final travelHeight = size.height + 100.0;
      final travelWidth = size.width + 100.0;

      for (var i = 0; i < count; i++) {
        final seed = i + seedOffset * 1000;

        final seedX = hash(seed, 1);
        final seedY = hash(seed, 2);
        final speedSeed = hash(seed, 3);
        final radiusSeed = hash(seed, 4);
        final opacitySeed = hash(seed, 5);
        final swaySeed = hash(seed, 6);
        final phaseSeed = hash(seed, 7);

        final speed = baseSpeed * (0.72 + speedSeed * 0.62);

        final phase = (seedY + progress * speed + phaseSeed * 0.17) % 1.0;

        final y = phase * travelHeight - 50.0;

        final swayPhase =
            progress * math.pi * 2.0 * (swaySpeed * (0.75 + swaySeed * 0.55)) +
            seed * 1.37;

        final primarySway =
            math.sin(swayPhase) * swayAmount * (0.55 + swaySeed * 0.75);

        final secondarySway =
            math.sin(swayPhase * 0.43 + seed * 0.71) * swayAmount * 0.28;

        final x =
            (seedX * travelWidth + primarySway + secondarySway + travelWidth) %
                travelWidth -
            50.0;

        final radius = minRadius + (maxRadius - minRadius) * radiusSeed;

        final opacity = minOpacity + (maxOpacity - minOpacity) * opacitySeed;

        if (foreground) {
          // カメラ直前を横切る大きな雪。
          // 柔らかい外側と芯を重ねて、ピントの外れた雪片を表現する。
          final glowPaint = Paint()
            ..color = Colors.white.withValues(alpha: opacity * 0.18)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.75);

          canvas.drawCircle(Offset(x, y), radius * 1.55, glowPaint);

          final bodyPaint = Paint()
            ..color = Colors.white.withValues(alpha: opacity * 0.52);

          canvas.drawCircle(Offset(x, y), radius, bodyPaint);

          final corePaint = Paint()
            ..color = Colors.white.withValues(alpha: opacity * 0.42);

          canvas.drawCircle(
            Offset(x - radius * 0.18, y - radius * 0.18),
            radius * 0.42,
            corePaint,
          );

          continue;
        }

        final snowPaint = Paint()
          ..color = Colors.white.withValues(alpha: opacity)
          ..style = PaintingStyle.fill;

        canvas.drawCircle(Offset(x, y), radius, snowPaint);
      }
    }

    // 遠景。小さく薄い雪を多めに配置。
    paintSnowLayer(
      count: 48,
      seedOffset: 13,
      baseSpeed: 0.28,
      minRadius: 0.75,
      maxRadius: 1.65,
      minOpacity: 0.28,
      maxOpacity: 0.52,
      swayAmount: 5.0,
      swaySpeed: 0.72,
      foreground: false,
    );

    // 中景。肉眼で最も「雪」と認識しやすい層。
    paintSnowLayer(
      count: 34,
      seedOffset: 31,
      baseSpeed: 0.40,
      minRadius: 1.5,
      maxRadius: 3.2,
      minOpacity: 0.48,
      maxOpacity: 0.78,
      swayAmount: 11.0,
      swaySpeed: 0.90,
      foreground: false,
    );

    // 前景。大きめの雪片を少数だけ通して奥行きを作る。
    paintSnowLayer(
      count: 12,
      seedOffset: 53,
      baseSpeed: 0.54,
      minRadius: 3.6,
      maxRadius: 7.8,
      minOpacity: 0.46,
      maxOpacity: 0.76,
      swayAmount: 19.0,
      swaySpeed: 1.05,
      foreground: true,
    );
  }

  void _paintFog(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) {
      return;
    }

    // 霧の色を時間帯へ馴染ませる。
    final Color fogAtmosphereColor;
    final double fogAtmosphereOpacity;
    final Color fogCoreColor;
    final Color fogMidColor;
    final Color fogOuterColor;

    switch (dayPhase) {
      case DayPhase.morning:
        fogAtmosphereColor = const Color(0xFFE6E7E2);
        fogAtmosphereOpacity = 0.095;
        fogCoreColor = const Color(0xFFF7F7F2);
        fogMidColor = const Color(0xFFECEDE8);
        fogOuterColor = const Color(0xFFDDE5E5);

      case DayPhase.daytime:
        fogAtmosphereColor = const Color(0xFFE7EFF1);
        fogAtmosphereOpacity = 0.10;
        fogCoreColor = const Color(0xFFF7FAFB);
        fogMidColor = const Color(0xFFE8EFF1);
        fogOuterColor = const Color(0xFFDCE7EA);

      case DayPhase.evening:
        fogAtmosphereColor = const Color(0xFFAAA2AE);
        fogAtmosphereOpacity = 0.09;
        fogCoreColor = const Color(0xFFF0E9EB);
        fogMidColor = const Color(0xFFDCD4DA);
        fogOuterColor = const Color(0xFFC6C4CD);

      case DayPhase.night:
        fogAtmosphereColor = const Color(0xFF40566C);
        fogAtmosphereOpacity = 0.12;
        fogCoreColor = const Color(0xFF9EAFBD);
        fogMidColor = const Color(0xFF788C9E);
        fogOuterColor = const Color(0xFF566D82);
    }

    final atmospherePaint = Paint()
      ..color = fogAtmosphereColor.withValues(alpha: fogAtmosphereOpacity);

    canvas.drawRect(Offset.zero & size, atmospherePaint);

    // 横にたなびく薄い霧。境界のある帯を少数だけ使い、
    // 地図ラベルを隠す一様な白塗りを避ける。
    for (var i = 0; i < 2; i++) {
      final drift = math.sin(progress * math.pi * 2 + i * 2.3) * 14;
      final band = Rect.fromLTWH(
        0,
        size.height * (0.22 + i * 0.37) + drift,
        size.width,
        size.height * 0.22,
      );
      final bandPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            fogCoreColor.withValues(
              alpha: dayPhase == DayPhase.night ? 0.10 : 0.16,
            ),
            Colors.transparent,
          ],
        ).createShader(band);
      canvas.drawRect(band, bandPaint);
    }

    double hash(int value, int salt) {
      final n = math.sin(value * 12.9898 + salt * 78.233) * 43758.5453;
      return n - n.floorToDouble();
    }

    // progress=0 と progress=1 で完全に同じ値になる基本角度。
    final loopAngle = progress * math.pi * 2.0;

    void paintFogLayer({
      required int count,
      required int seedOffset,
      required double minWidthFactor,
      required double maxWidthFactor,
      required double minHeight,
      required double maxHeight,
      required double minOpacity,
      required double maxOpacity,
      required double horizontalRange,
      required double verticalRange,
      required double phaseMultiplier,
    }) {
      for (var i = 0; i < count; i++) {
        final seed = i + seedOffset * 1000;

        final xSeed = hash(seed, 1);
        final ySeed = hash(seed, 2);
        final widthSeed = hash(seed, 3);
        final heightSeed = hash(seed, 4);
        final opacitySeed = hash(seed, 5);
        final phaseSeed = hash(seed, 6);
        final shapeSeed = hash(seed, 7);
        final driftSeed = hash(seed, 8);

        final width =
            size.width *
            (minWidthFactor + (maxWidthFactor - minWidthFactor) * widthSeed);

        final height = minHeight + (maxHeight - minHeight) * heightSeed;

        final baseX = -width * 0.12 + xSeed * (size.width + width * 0.24);

        final baseY = ySeed * (size.height + height * 0.25) - height * 0.12;

        // 各霧塊に固有の位相を与える。
        final phaseOffset = phaseSeed * math.pi * 2.0;

        // 周期は整数倍にすることで、8秒の境界でも位置が飛ばない。
        final cycle = 1 + ((phaseSeed * phaseMultiplier).floor() % 3);

        final angle = loopAngle * cycle + phaseOffset;

        // 横方向は単純な往復に見えないよう2種類の波を合成。
        final horizontalDrift =
            math.sin(angle) * horizontalRange * (0.55 + driftSeed * 0.55) +
            math.sin(angle * 2.0 + shapeSeed * math.pi) *
                horizontalRange *
                0.16;

        // 縦方向はさらに別位相。
        final verticalDrift =
            math.cos(angle + shapeSeed * math.pi * 2.0) *
                verticalRange *
                (0.55 + heightSeed * 0.45) +
            math.sin(angle * 3.0 + phaseOffset) * verticalRange * 0.10;

        final center = Offset(baseX + horizontalDrift, baseY + verticalDrift);

        // 濃度も周期関数だけで変える。
        // ループ境界で突然出現・消失しない。
        final breathe =
            0.78 + 0.22 * math.sin(angle + opacitySeed * math.pi * 2.0);

        final opacity =
            (minOpacity + (maxOpacity - minOpacity) * opacitySeed) * breathe;

        // 1つの巨大な楕円ではなく、重なった複数の霧塊として描く。
        // 同じ霧が毎回同じ形で横切る印象を弱める。
        for (var blob = 0; blob < 3; blob++) {
          final blobSeed = hash(seed, 20 + blob);
          final blobShapeSeed = hash(seed, 30 + blob);

          final blobAngle = angle + blob * 2.05 + blobSeed * 0.75;

          final blobX =
              center.dx +
              math.sin(blobAngle) * width * (0.12 + blobSeed * 0.08);

          final blobY =
              center.dy +
              math.cos(blobAngle * 0.7) *
                  height *
                  (0.08 + blobShapeSeed * 0.08);

          final blobWidth = width * (0.66 + blobSeed * 0.30);

          final blobHeight = height * (0.70 + blobShapeSeed * 0.28);

          final rect = Rect.fromCenter(
            center: Offset(blobX, blobY),
            width: blobWidth,
            height: blobHeight,
          );

          final blobOpacity = opacity * (0.62 + blobSeed * 0.30);

          final fogPaint = Paint()
            ..shader = RadialGradient(
              center: Alignment(
                (blobSeed - 0.5) * 0.28,
                (blobShapeSeed - 0.5) * 0.18,
              ),
              radius: 0.78,
              colors: [
                fogCoreColor.withValues(alpha: blobOpacity),
                fogMidColor.withValues(alpha: blobOpacity * 0.62),
                fogOuterColor.withValues(alpha: blobOpacity * 0.18),
                fogOuterColor.withValues(alpha: 0.0),
              ],
              stops: const [0.0, 0.42, 0.76, 1.0],
            ).createShader(rect);

          canvas.drawOval(rect, fogPaint);
        }
      }
    }

    // 遠景。
    // 大きく、薄く、動きも小さい。
    paintFogLayer(
      count: 5,
      seedOffset: 17,
      minWidthFactor: 0.82,
      maxWidthFactor: 1.28,
      minHeight: 140,
      maxHeight: 235,
      minOpacity: 0.060,
      maxOpacity: 0.115,
      horizontalRange: 16,
      verticalRange: 3.5,
      phaseMultiplier: 2.0,
    );

    // 中景。
    // 視界がゆっくり霞んだり戻ったりする主役。
    paintFogLayer(
      count: 7,
      seedOffset: 37,
      minWidthFactor: 0.54,
      maxWidthFactor: 0.94,
      minHeight: 95,
      maxHeight: 175,
      minOpacity: 0.085,
      maxOpacity: 0.155,
      horizontalRange: 24,
      verticalRange: 5.0,
      phaseMultiplier: 3.0,
    );

    // 前景。
    // 少数の大きな薄霧だけをゆっくり漂わせる。
    paintFogLayer(
      count: 4,
      seedOffset: 59,
      minWidthFactor: 0.72,
      maxWidthFactor: 1.16,
      minHeight: 150,
      maxHeight: 255,
      minOpacity: 0.050,
      maxOpacity: 0.100,
      horizontalRange: 32,
      verticalRange: 7.0,
      phaseMultiplier: 4.0,
    );

    // 地表の霧も完全な固定グラデーションにはせず、
    // ごくわずかに呼吸させる。
    final groundBreath =
        0.88 +
        math.sin(loopAngle) * 0.06 +
        math.sin(loopAngle * 2.0 + 1.4) * 0.03;

    final groundFogRect = Rect.fromLTWH(
      0,
      size.height * 0.52,
      size.width,
      size.height * 0.48,
    );

    final groundFogPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          fogOuterColor.withValues(alpha: 0.0),
          fogMidColor.withValues(alpha: 0.042 * groundBreath),
          fogCoreColor.withValues(alpha: 0.072 * groundBreath),
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(groundFogRect);

    canvas.drawRect(groundFogRect, groundFogPaint);
  }

  void _paintThunderstorm(Canvas canvas, Size size) {
    _paintRain(canvas, size, heavy: true);

    final firstPulse = (progress - 0.24).abs() < 0.012;
    final secondPulse = (progress - 0.29).abs() < 0.008;

    if (firstPulse || secondPulse) {
      final flashOpacity = switch (dayPhase) {
        DayPhase.morning => 0.12,
        DayPhase.daytime => 0.10,
        DayPhase.evening => 0.14,
        DayPhase.night => 0.18,
      };

      final flashPaint = Paint()
        ..color = const Color(0xFFE9E4FF).withValues(alpha: flashOpacity);

      canvas.drawRect(Offset.zero & size, flashPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _WeatherEffectPainter oldDelegate) {
    return oldDelegate.weather != weather ||
        oldDelegate.dayPhase != dayPhase ||
        oldDelegate.progress != progress;
  }
}
