import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/money.dart';
import '../../../core/theme/kora_colors.dart';
import '../../../core/theme/kora_spacing.dart';
import '../../../core/theme/kora_typography.dart';
import '../application/insights_providers.dart';
import '../domain/insights_models.dart';

/// Carte "Prochaine action" : une seule action concrete recommandee a
/// l'utilisateur, calculee par le coaching backend. Silencieuse en
/// chargement / erreur (le dashboard reste lisible).
class NextActionCard extends ConsumerWidget {
  const NextActionCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final action = ref.watch(nextActionProvider);
    return action.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (a) => _NextActionContent(action: a),
    );
  }
}

class _NextActionContent extends StatelessWidget {
  const _NextActionContent({required this.action});
  final NextAction action;

  Color _accent() => switch (action.priority) {
        1 => KoraColors.red,
        2 => KoraColors.gold,
        _ => KoraColors.greenPrimary,
      };

  IconData _icon() => switch (action.code) {
        'log_first_tx' || 'log_more_tx' => Icons.edit_note_rounded,
        'log_income' => Icons.south_west_rounded,
        'create_first_goal' => Icons.flag_rounded,
        'save_weekly' => Icons.savings_rounded,
        'trim_impulse' => Icons.warning_amber_rounded,
        'catch_up_goal' => Icons.trending_up_rounded,
        'celebrate' => Icons.celebration_rounded,
        _ => Icons.auto_awesome_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final accent = _accent();
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(KoraSpacing.radiusLg),
        onTap: () => context.push(action.ctaRoute),
        child: Padding(
          padding: const EdgeInsets.all(KoraSpacing.cardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius:
                          BorderRadius.circular(KoraSpacing.radiusMd),
                    ),
                    child: Icon(_icon(), color: accent, size: 22),
                  ),
                  const SizedBox(width: KoraSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Ta prochaine action',
                            style: KoraType.fieldLabel(color: accent)),
                        const SizedBox(height: 2),
                        Text(action.title, style: KoraType.bodyStrong()),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: KoraSpacing.xs),
              Text(action.body, style: KoraType.body()),
              if (action.amountXof != null) ...[
                const SizedBox(height: KoraSpacing.xs),
                Text(
                  Money.format(action.amountXof!),
                  style: KoraType.bodyStrong(color: accent),
                ),
              ],
              const SizedBox(height: KoraSpacing.sm),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: KoraColors.white,
                  ),
                  onPressed: () => context.push(action.ctaRoute),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: Text(action.ctaLabel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
