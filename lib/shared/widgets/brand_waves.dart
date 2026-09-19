import 'dart:math';

import 'package:flutter/material.dart';

/// V2.8.2 S2：波纹母题 —— 两道弧线（opacity 16%），锁屏与开屏共享。
///
/// [animate] = true 时随 [progress]（0..1）展开；静态场景传固定 progress。
class BrandWaves extends StatelessWidget {
  const BrandWaves({
    super.key,
    this.color,
    this.progress = 1.0,
    this.opacity = 0.16,
  });

  final Color? color;

  /// 0..1：两道弧线的展开进度（easeOutCubic 由调用方给曲线）。
  final double progress;

  final double opacity;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return CustomPaint(
      size: const Size(double.infinity, 120),
      painter: _WavesPainter(color: c, opacity: opacity, progress: progress),
    );
  }
}

class _WavesPainter extends CustomPainter {
  const _WavesPainter({
    required this.color,
    required this.opacity,
    required this.progress,
  });

  final Color color;
  final double opacity;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = color.withValues(alpha: opacity)
      ..strokeCap = StrokeCap.round;
    for (final (i, baseY) in [size.height * 0.45, size.height * 0.75].indexed) {
      final path = Path();
      final amplitude = 7.0 + i * 3;
      final wavelength = size.width / 1.6;
      final endX = size.width * progress.clamp(0.0, 1.0);
      var first = true;
      for (double x = 0; x <= endX; x += 6) {
        final y = baseY + sin((x / wavelength) * 2 * pi) * amplitude;
        if (first) {
          path.moveTo(x, y);
          first = false;
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WavesPainter old) =>
      old.color != color || old.progress != progress || old.opacity != opacity;
}
