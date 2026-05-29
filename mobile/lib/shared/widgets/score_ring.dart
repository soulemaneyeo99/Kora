import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/kora_colors.dart';
import '../../core/theme/kora_typography.dart';

/// Cercle animé du Score de Discipline 0-100 (Charte 3.2 / CDC F09).
///
/// Couleur dynamique : rouge < 40, or 40-79, vert foncé 80-100.
class ScoreRing extends StatelessWidget {
  const ScoreRing({
    super.key,
    required this.score,
    required this.grade,
    this.size = 140,
  });

  final int score;
  final String grade;
  final double size;

  Color get _color {
    if (score >= 80) return KoraColors.greenPrimary;
    if (score >= 40) return KoraColors.gold;
    return KoraColors.red;
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOut,
      tween: Tween(begin: 0, end: score.clamp(0, 100) / 100),
      builder: (context, t, _) {
        return SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _RingPainter(progress: t, color: _color),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${(t * 100).round()}',
                      style: KoraType.moneyLarge(color: _color)),
                  Text('/ 100 · $grade', style: KoraType.caption()),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 12.0;
    final center = size.center(Offset.zero);
    final radius = (size.width - stroke) / 2;

    final track = Paint()
      ..color = KoraColors.greenPale
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;

    final arc = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, track);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color;
}
