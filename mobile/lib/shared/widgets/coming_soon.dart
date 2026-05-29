import 'package:flutter/material.dart';

import '../../core/theme/kora_colors.dart';
import '../../core/theme/kora_spacing.dart';
import '../../core/theme/kora_typography.dart';

/// Écran "bientôt disponible" pour les modules planifiés (Phase 1/2 du CDC).
class ComingSoon extends StatelessWidget {
  const ComingSoon({
    super.key,
    required this.emoji,
    required this.title,
    required this.subtitle,
    this.phase,
  });

  final String emoji;
  final String title;
  final String subtitle;
  final String? phase;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(KoraSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: KoraType.h1()),
            const SizedBox(height: KoraSpacing.md),
            Text(title, style: KoraType.h2(), textAlign: TextAlign.center),
            const SizedBox(height: KoraSpacing.xs),
            Text(
              subtitle,
              style: KoraType.body(color: KoraColors.gray),
              textAlign: TextAlign.center,
            ),
            if (phase != null) ...[
              const SizedBox(height: KoraSpacing.md),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: KoraSpacing.sm, vertical: KoraSpacing.xs),
                decoration: BoxDecoration(
                  color: KoraColors.greenPale,
                  borderRadius: BorderRadius.circular(KoraSpacing.radiusMd),
                ),
                child: Text(phase!,
                    style: KoraType.fieldLabel(color: KoraColors.greenPrimary)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
