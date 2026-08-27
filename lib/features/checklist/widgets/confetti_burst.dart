import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 全部完成彩蛋：自绘轻量彩带喷发（无第三方包，约 1.6s 自动结束）
class ConfettiBurst extends StatefulWidget {
  const ConfettiBurst({
    super.key,
    required this.colors,
    this.durationMs = 1600,
  });

  /// 彩带用色（调用方传入主题语义色，本组件不硬编码色值）
  final List<Color> colors;
  final int durationMs;

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: widget.durationMs),
  );

  late final List<_Particle> _particles = _generate();

  List<_Particle> _generate() {
    final random = math.Random(42); // 固定种子：每次彩蛋形状一致且可复现
    return List.generate(46, (i) {
      final angle = -math.pi / 2 + (random.nextDouble() - 0.5) * 1.5;
      final speed = 260 + random.nextDouble() * 320;
      return _Particle(
        dxRatio: 0.5 + (random.nextDouble() - 0.5) * 0.24,
        dyRatio: 0.30,
        vx: math.cos(angle) * speed,
        vy: math.sin(angle) * speed,
        gravity: 520 + random.nextDouble() * 240,
        size: 5 + random.nextDouble() * 6,
        rotation: random.nextDouble() * math.pi * 2,
        angularVelocity: (random.nextDouble() - 0.5) * 10,
        round: random.nextBool(),
        color: widget.colors.isEmpty ? const Color(0x00000000) : widget.colors[i % widget.colors.length],
      );
    });
  }

  @override
  void initState() {
    super.initState();
    // forward 从字段初始化挪到 initState：避免 build 期间立即 replace/unmount
    // 时 controller 撞上 unmount（framework.dart '_dependents.isEmpty'）。
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          painter: _ConfettiPainter(
            particles: _particles,
            t: _controller.value,
            secondsPerUnit: widget.durationMs / 1000,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _Particle {
  const _Particle({
    required this.dxRatio,
    required this.dyRatio,
    required this.vx,
    required this.vy,
    required this.gravity,
    required this.size,
    required this.rotation,
    required this.angularVelocity,
    required this.round,
    required this.color,
  });

  final double dxRatio; // 喷发源点（相对画布宽）
  final double dyRatio;
  final double vx; // px/s
  final double vy;
  final double gravity;
  final double size;
  final double rotation;
  final double angularVelocity; // rad/s
  final bool round;
  final Color color;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({
    required this.particles,
    required this.t,
    required this.secondsPerUnit,
  });

  final List<_Particle> particles;
  final double t; // 0..1
  final double secondsPerUnit;

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0 || t >= 1 || particles.isEmpty) return;
    final seconds = t * secondsPerUnit;
    const fadeStart = 0.72;
    final opacity = t < fadeStart
        ? 1.0
        : (1.0 - (t - fadeStart) / (1 - fadeStart)).clamp(0.0, 1.0);

    for (final p in particles) {
      final cx = size.width * p.dxRatio + p.vx * seconds;
      final cy = size.height * p.dyRatio +
          p.vy * seconds +
          0.5 * p.gravity * seconds * seconds;
      if (cy > size.height + 40) continue;

      final spin = p.rotation + p.angularVelocity * seconds;
      final paint = Paint()..color = p.color.withValues(alpha: opacity);
      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(spin);
      if (p.round) {
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
      } else {
        // 扁平纸屑：绕自身纵向翻转产生透视闪烁感
        final flip = (spin.abs() % math.pi) / math.pi;
        final scaleY = 0.35 + 0.65 * flip;
        canvas.scale(1.0, scaleY);
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.62),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) => oldDelegate.t != t;
}
