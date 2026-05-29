import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/money.dart';
import '../../../core/theme/kora_colors.dart';
import '../../../core/theme/kora_spacing.dart';
import '../../../core/theme/kora_typography.dart';
import '../../../shared/widgets/async_value_view.dart';
import '../../../shared/widgets/coach_card.dart';
import '../../../shared/widgets/score_ring.dart';
import '../../auth/application/auth_controller.dart';
import '../application/dashboard_providers.dart';
import '../domain/dashboard_models.dart';

/// Onglet Accueil — dashboard principal (CDC F06) : header, solde estimé,
/// score animé, répartition des dépenses, conseil du jour.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(dashboardSummaryProvider);
    final score = ref.watch(disciplineScoreProvider);
    final user = ref.watch(authControllerProvider).user;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: KoraColors.greenActive,
          onRefresh: () async {
            ref.invalidate(dashboardSummaryProvider);
            ref.invalidate(disciplineScoreProvider);
            await Future.wait([
              ref.read(dashboardSummaryProvider.future),
              ref.read(disciplineScoreProvider.future),
            ]);
          },
          child: ListView(
            padding: const EdgeInsets.all(KoraSpacing.pagePadding),
            children: [
              _Header(name: user?.greetingName ?? 'champion'),
              const SizedBox(height: KoraSpacing.lg),
              AsyncValueView(
                value: summary,
                onRetry: () => ref.invalidate(dashboardSummaryProvider),
                data: (s) => _BalanceCard(summary: s),
              ),
              const SizedBox(height: KoraSpacing.md),
              AsyncValueView(
                value: score,
                onRetry: () => ref.invalidate(disciplineScoreProvider),
                data: (s) => _ScoreCard(score: s),
              ),
              const SizedBox(height: KoraSpacing.md),
              summary.maybeWhen(
                data: (s) => _ExpensesCard(summary: s),
                orElse: () => const SizedBox.shrink(),
              ),
              const SizedBox(height: KoraSpacing.md),
              score.maybeWhen(
                data: (s) => CoachCard(
                  message: s.insights.isNotEmpty
                      ? s.insights.first
                      : 'Chaque petit pas compte. Continue comme ça !',
                ),
                orElse: () => const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Salut $name 👋', style: KoraType.h2()),
              Text('Voici tes finances ce mois-ci.', style: KoraType.caption()),
            ],
          ),
        ),
        IconButton(
          onPressed: () {},
          icon: const Icon(Icons.notifications_none_rounded),
        ),
      ],
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.summary});
  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final c = summary.currentPeriod;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(KoraSpacing.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Solde estimé du mois', style: KoraType.fieldLabel()),
            const SizedBox(height: KoraSpacing.micro),
            Text(Money.format(summary.estimatedBalanceXof),
                style: KoraType.moneyLarge(
                  color: summary.estimatedBalanceXof >= 0
                      ? KoraColors.greenPrimary
                      : KoraColors.red,
                )),
            const SizedBox(height: KoraSpacing.md),
            Row(
              children: [
                _MiniStat(
                  icon: Icons.south_west_rounded,
                  label: 'Entrées',
                  value: Money.compact(c.incomeXof),
                  color: KoraColors.greenActive,
                ),
                const SizedBox(width: KoraSpacing.md),
                _MiniStat(
                  icon: Icons.north_east_rounded,
                  label: 'Sorties',
                  value: Money.compact(c.expenseXof),
                  color: KoraColors.gold,
                ),
                const SizedBox(width: KoraSpacing.md),
                _MiniStat(
                  icon: Icons.savings_rounded,
                  label: 'Épargne',
                  value: Money.compact(summary.savingsTotalXof),
                  color: KoraColors.greenPrimary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: KoraSpacing.micro),
          Text(value, style: KoraType.bodyStrong()),
          Text(label, style: KoraType.caption()),
        ],
      ),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({required this.score});
  final DisciplineScore score;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(KoraSpacing.cardPadding),
        child: Row(
          children: [
            ScoreRing(score: score.score, grade: score.grade, size: 120),
            const SizedBox(width: KoraSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Score de discipline', style: KoraType.cardLabel()),
                  const SizedBox(height: KoraSpacing.xs),
                  ...score.components.entries.take(4).map(
                        (e) => Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(
                            '${_componentLabel(e.key)} · ${e.value} pts',
                            style: KoraType.caption(),
                          ),
                        ),
                      ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _componentLabel(String key) => switch (key) {
        'savings_rate' => 'Épargne',
        'tracking_regularity' => 'Suivi',
        'goal_progress' => 'Objectifs',
        'impulse_control' => 'Contrôle',
        _ => key,
      };
}

class _ExpensesCard extends StatelessWidget {
  const _ExpensesCard({required this.summary});
  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final cats = summary.topExpenseCategories;
    if (cats.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(KoraSpacing.cardPadding),
          child: Row(
            children: [
              const Icon(Icons.pie_chart_outline_rounded,
                  color: KoraColors.gray),
              const SizedBox(width: KoraSpacing.sm),
              Expanded(
                child: Text(
                  'Pas encore de dépenses ce mois. Ajoute-en pour voir la répartition.',
                  style: KoraType.body(color: KoraColors.gray),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final palette = [
      KoraColors.greenPrimary,
      KoraColors.gold,
      KoraColors.greenActive,
      KoraColors.charcoal,
      KoraColors.gray,
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(KoraSpacing.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Où part ton argent', style: KoraType.cardLabel()),
            const SizedBox(height: KoraSpacing.md),
            Row(
              children: [
                SizedBox(
                  height: 120,
                  width: 120,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 30,
                      sections: [
                        for (var i = 0; i < cats.length; i++)
                          PieChartSectionData(
                            value: cats[i].amountXof.toDouble(),
                            color: palette[i % palette.length],
                            title: '',
                            radius: 22,
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: KoraSpacing.md),
                Expanded(
                  child: Column(
                    children: [
                      for (var i = 0; i < cats.length; i++)
                        _LegendRow(
                          color: palette[i % palette.length],
                          item: cats[i],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.color, required this.item});
  final Color color;
  final CategoryBreakdownItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: KoraSpacing.xs),
          Expanded(
            child: Text(item.categoryName,
                style: KoraType.body(), overflow: TextOverflow.ellipsis),
          ),
          Text('${item.pctOfTotal.round()}%', style: KoraType.caption()),
        ],
      ),
    );
  }
}
