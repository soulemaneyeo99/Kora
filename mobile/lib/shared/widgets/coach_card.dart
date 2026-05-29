import 'package:flutter/material.dart';

import '../../core/theme/kora_colors.dart';
import '../../core/theme/kora_spacing.dart';
import '../../core/theme/kora_typography.dart';

/// Encadré "Conseil KORA du jour" (Charte : card alerte or, CDC F11).
class CoachCard extends StatelessWidget {
  const CoachCard(
      {super.key, required this.message, this.title = 'Conseil KORA'});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(KoraSpacing.md),
      decoration: BoxDecoration(
        color: KoraColors.goldPale,
        borderRadius: BorderRadius.circular(KoraSpacing.radiusLg),
        border: Border.all(color: KoraColors.gold, width: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.tips_and_updates_rounded, color: KoraColors.gold),
          const SizedBox(width: KoraSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: KoraType.cardLabel()),
                const SizedBox(height: KoraSpacing.micro),
                Text(message, style: KoraType.body()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
