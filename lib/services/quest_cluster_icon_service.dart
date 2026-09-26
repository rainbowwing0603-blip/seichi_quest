import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class QuestClusterIconService {
  QuestClusterIconService();

  final Map<String, BitmapDescriptor> _cache = {};

  Future<BitmapDescriptor> iconForCount(int count) async {
    final label = count > 99 ? '99+' : count.toString();
    final cached = _cache[label];
    if (cached != null) return cached;

    const size = 112.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final center = const Offset(size / 2, size / 2);

    final shadowPaint = Paint()..color = const Color(0x33000000);
    canvas.drawCircle(center + const Offset(0, 5), 46, shadowPaint);

    final fillPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF7568F3), Color(0xFF3E47B8)],
      ).createShader(const Rect.fromLTWH(0, 0, size, size));
    canvas.drawCircle(center, 45, fillPaint);

    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;
    canvas.drawCircle(center, 42, borderPaint);

    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 31,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: 88);

    painter.paint(
      canvas,
      Offset((size - painter.width) / 2, (size - painter.height) / 2 - 1),
    );

    final image = await recorder.endRecording().toImage(size.toInt(), size.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (bytes == null) return BitmapDescriptor.defaultMarker;

    final descriptor = BitmapDescriptor.bytes(
      Uint8List.view(bytes.buffer),
      imagePixelRatio: 2.0,
    );
    _cache[label] = descriptor;
    return descriptor;
  }
}
