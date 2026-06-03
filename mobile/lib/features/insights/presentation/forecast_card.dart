import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/money.dart';
import '../../../core/theme/kora_colors.dart';
import '../../../core/theme/kora_spacing.dart';
import '../../../core/theme/kora_typography.dart';
import '../application/insights_providers.dart';
import '../domain/insights_models.dart';

/// Carte "Prevision fin de mois" : extrapolation lineaire des depenses.
/// Cachee tant qu'on a moins de 3 jours de donnees (ton "neutral").
class ForecastCard extends ConsumerWidget {
  const ForecastCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final forecast = ref.watch(forecastProvider);
    return forecast.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (f) {
        if (f.tone == 'neutral') return const SizedBox.shrink();
        return _ForecastContent(forecast: f);
      },
    );
  }
}

class _ForecastContent extends StatelessWidget {
  const _ForecastContent({required this.forecast});
  final EndOfMonthForecast forecast;

  ({Color accent, Color bg, IconData icon}) _palette() => switch (forecast.tone) {
        'danger' => (
            accent: KoraColors.red,
            bg: KoraColors.red.withValues(alpha: 0.08),
            icon: Icons.warning_amber_rounded,
          ),
        'warning' => (
            accent: KoraColors.gold,
            bg: KoraColors.goldPale,
            icon: Icons.trending_flat_rounded,
          ),
        'good' => (
            accent: KoraColors.greenPrimary,
            bg: KoraColors.greenPale,
            icon: Icons.trending_up_rounded,
          ),
        _ => (
            accent: KoraColors.gray,
            bg: KoraColors.surfaceLight,
            icon: Icons.insights_rounded,
          ),
      };

  @override
  Widget build(BuildContext context) {
    final p = _palette();
    final progress = forecast.daysElapsed /
        (forecast.daysElapsed + forecast.daysRemaining);
    return Container(
      padding: const EdgeInsets.all(KoraSpacing.cardPadding),
      decoration: BoxDecoration(
        color: p.bg,
        borderRadius: BorderRadius.circular(KoraSpacing.radiusLg),
        border: Border.all(color: p.accent.withValues(alpha: 0.30), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(p.icon, color: p.accent, size: 20),
              const SizedBox(width: KoraSpacing.xs),
              Text(
                'Prevision fin de mois',
                style: KoraType.fieldLabel(color: p.accent),
              ),
              const Spacer(),
              Text(
                'J${forecast.daysElapsed}/${forecast.daysElapsed + forecast.daysRemaining}',
                style: KoraType.caption(),
              ),
            ],
          ),
          const SizedBox(height: KoraSpacing.xs),
          Text(forecast.headline, style: KoraType.bodyStrong()),
          const SizedBox(height: KoraSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: p.accent.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(p.accent),
            ),
          ),
          const SizedBox(height: KoraSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _Stat(
                  label: 'Depense / jour',
                  value: Money.compact(forecast.dailyAvgExpenseXof),
                ),
              ),
              Expanded(
                child: _Stat(
                  label: 'Projection sortie',
                  value: Money.compact(forecast.projectedExpenseXof),
                ),
              ),
              Expanded(
                child: _Stat(
                  label: 'Solde fin de mois',
                  value: Money.compact(forecast.projectedBalanceXof),
                  color: forecast.projectedBalanceXof < 0
                      ? KoraColors.red
                      : KoraColors.greenPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.color});
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: c == null
              ? KoraType.bodyStrong()
              : KoraType.bodyStrong(color: c),
        ),
        Text(label, style: KoraType.caption()),
      ],
    );
  }
}
