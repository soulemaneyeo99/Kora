import 'package:flutter/material.dart';

import '../../core/theme/kora_colors.dart';
import '../../core/theme/kora_spacing.dart';
import '../../core/theme/kora_typography.dart';

/// Barre de progression KORA (Charte 4.3) : forme pilule, animée, couleur
/// qui évolue avec l'avancement (vert -> or -> vert foncé proche du but).
class KoraProgressBar extends StatelessWidget {
  const KoraProgressBar({
    super.key,
    required this.value,
    this.height = KoraSpacing.progressHeightProminent,
    this.showLabel = true,
    this.prioritized = false,
  });

  /// Avancement 0.0 -> 1.0.
  final double value;
  final double height;
  final bool showLabel;

  /// Si l'objectif est prioritaire, la zone 61-89% passe en or.
  final bool prioritized;

  Color get _fillColor {
    if (value >= 0.90) return KoraColors.greenPrimary;
    if (value >= 0.61) {
      return prioritized ? KoraColors.gold : KoraColors.greenActive;
    }
    return KoraColors.greenActive;
  }

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(0.0, 1.0);
    final pct = (clamped * 100).round();

    final bar = ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: Stack(
        children: [
          Container(height: height, color: KoraColors.greenPale),
          AnimatedFractionallySizedBox(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            widthFactor: clamped,
            child: Container(height: height, color: _fillColor),
          ),
        ],
      ),
    );

    if (!showLabel) return bar;

    return Row(
      children: [
        Expanded(child: bar),
        const SizedBox(width: KoraSpacing.xs),
        Text('$pct%', style: KoraType.moneyMedium()),
      ],
    );
  }
}
