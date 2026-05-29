import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/kora_colors.dart';
import '../../../core/theme/kora_spacing.dart';
import '../../../core/theme/kora_typography.dart';
import '../application/insights_providers.dart';

/// Conseil du jour (CDC F11) : affiche un conseil personnalise sous le dashboard.
/// Silencieux si erreur ou chargement (pas de spinner ni d'erreur visible).
class DailyTipCard extends ConsumerWidget {
  const DailyTipCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tip = ref.watch(dailyTipProvider);
    return tip.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (t) => Card(
        color: KoraColors.greenPale,
        child: Padding(
          padding: const EdgeInsets.all(KoraSpacing.cardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.lightbulb_outline_rounded,
                      color: KoraColors.greenPrimary, size: 20),
                  const SizedBox(width: KoraSpacing.xs),
                  Text(
                    'Conseil du jour',
                    style: KoraType.fieldLabel(color: KoraColors.greenPrimary),
                  ),
                ],
              ),
              const SizedBox(height: KoraSpacing.xs),
              Text(t.title, style: KoraType.bodyStrong()),
              const SizedBox(height: KoraSpacing.micro),
              Text(t.body, style: KoraType.body()),
            ],
          ),
        ),
      ),
    );
  }
}
