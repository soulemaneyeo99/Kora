import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/money.dart';
import '../../../core/theme/kora_colors.dart';
import '../../../core/theme/kora_spacing.dart';
import '../../../core/theme/kora_typography.dart';
import '../../../shared/widgets/async_value_view.dart';
import '../../../shared/widgets/coach_card.dart';
import '../../../shared/widgets/score_ring.dart';
import '../../auth/application/auth_controller.dart';
import '../../insights/application/insights_providers.dart';
import '../../insights/presentation/daily_tip_card.dart';
import '../../insights/presentation/forecast_card.dart';
import '../../insights/presentation/next_action_card.dart';
import '../../transactions/domain/transaction.dart';
import '../../transactions/presentation/add_transaction_sheet.dart';
import '../application/dashboard_providers.dart';
import '../domain/dashboard_models.dart';

/// Onglet Accueil — dashboard principal (CDC F06) : header, solde estime,
/// score anime, repartition des depenses, conseil du jour.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  Future<void> _openAddSheet(BuildContext context, WidgetRef ref,
      {TxKind initial = TxKind.expense}) async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(KoraSpacing.radiusXl)),
      ),
      builder: (_) => AddTransactionSheet(initialKind: initial),
    );
    if (created == true) {
      ref.invalidate(dashboardSummaryProvider);
      ref.invalidate(disciplineScoreProvider);
      ref.invalidate(nextActionProvider);
      ref.invalidate(forecastProvider);
      ref.invalidate(dailyTipProvider);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(dashboardSummaryProvider);
    final score = ref.watch(disciplineScoreProvider);
    final user = ref.watch(authControllerProvider).user;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: KoraColors.greenPrimary,
        foregroundColor: KoraColors.white,
        onPressed: () => _openAddSheet(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Transaction'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: KoraColors.greenActive,
          onRefresh: () async {
            ref.invalidate(dashboardSummaryProvider);
            ref.invalidate(disciplineScoreProvider);
            ref.invalidate(nextActionProvider);
            ref.invalidate(forecastProvider);
            ref.invalidate(dailyTipProvider);
            await Future.wait([
              ref.read(dashboardSummaryProvider.future),
              ref.read(disciplineScoreProvider.future),
            ]);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              KoraSpacing.pagePadding,
              KoraSpacing.pagePadding,
              KoraSpacing.pagePadding,
              96, // espace pour le FAB
            ),
            children: [
              _Header(name: user?.greetingName ?? 'champion'),
              const SizedBox(height: KoraSpacing.lg),
              AsyncValueView(
                value: summary,
                onRetry: () => ref.invalidate(dashboardSummaryProvider),
                data: (s) => _BalanceCard(
                  summary: s,
                  onTapIncome: () => context.push(
                    '/transactions',
                    extra: {'kind': TxKind.income},
                  ),
                  onTapExpense: () => context.push(
                    '/transactions',
                    extra: {'kind': TxKind.expense},
                  ),
                  onTapSavings: () => context.go('/goals'),
                  onTapAll: () => context.push('/transactions'),
                ),
              ),
              const SizedBox(height: KoraSpacing.md),
              AsyncValueView(
                value: score,
                onRetry: () => ref.invalidate(disciplineScoreProvider),
                data: (s) => _ScoreCard(
                  score: s,
                  hasData: summary.maybeWhen(
                    data: (sm) => sm.currentPeriod.transactionsCount > 0,
                    orElse: () => false,
                  ),
                ),
              ),
              const SizedBox(height: KoraSpacing.md),
              const NextActionCard(),
              const SizedBox(height: KoraSpacing.md),
              const ForecastCard(),
              const SizedBox(height: KoraSpacing.md),
              summary.maybeWhen(
                data: (s) => _ExpensesCard(
                  summary: s,
                  onAddExpense: () => _openAddSheet(context, ref),
                ),
                orElse: () => const SizedBox.shrink(),
              ),
              const SizedBox(height: KoraSpacing.md),
              const DailyTipCard(),
              const SizedBox(height: KoraSpacing.md),
              score.maybeWhen(
                data: (s) => CoachCard(
                  message: s.insights.isNotEmpty
                      ? s.insights.first
                      : 'Chaque petit pas compte. Continue comme ca !',
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
  const _BalanceCard({
    required this.summary,
    required this.onTapIncome,
    required this.onTapExpense,
    required this.onTapSavings,
    required this.onTapAll,
  });
  final DashboardSummary summary;
  final VoidCallback onTapIncome;
  final VoidCallback onTapExpense;
  final VoidCallback onTapSavings;
  final VoidCallback onTapAll;

  @override
  Widget build(BuildContext context) {
    final c = summary.currentPeriod;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(KoraSpacing.radiusLg),
        onTap: onTapAll,
        child: Padding(
          padding: const EdgeInsets.all(KoraSpacing.cardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Solde estime du mois', style: KoraType.fieldLabel()),
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
                    label: 'Entrees',
                    value: Money.compact(c.incomeXof),
                    color: KoraColors.greenActive,
                    onTap: onTapIncome,
                  ),
                  const SizedBox(width: KoraSpacing.md),
                  _MiniStat(
                    icon: Icons.north_east_rounded,
                    label: 'Sorties',
                    value: Money.compact(c.expenseXof),
                    color: KoraColors.gold,
                    onTap: onTapExpense,
                  ),
                  const SizedBox(width: KoraSpacing.md),
                  _MiniStat(
                    icon: Icons.savings_rounded,
                    label: 'Epargne',
                    value: Money.compact(summary.savingsTotalXof),
                    color: KoraColors.greenPrimary,
                    onTap: onTapSavings,
                  ),
                ],
              ),
            ],
          ),
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
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(KoraSpacing.radiusMd),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: KoraSpacing.xs),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(height: KoraSpacing.micro),
              Text(value, style: KoraType.bodyStrong()),
              Text(label, style: KoraType.caption()),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({required this.score, required this.hasData});
  final DisciplineScore score;
  final bool hasData;

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
                  if (!hasData)
                    Text(
                      'On commence ensemble : note tes premieres '
                      'transactions, KORA apprend ton rythme.',
                      style: KoraType.caption(),
                    )
                  else
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
        'savings_rate' => 'Epargne',
        'tracking_regularity' => 'Suivi',
        'goal_progress' => 'Objectifs',
        'impulse_control' => 'Controle',
        _ => key,
      };
}

class _ExpensesCard extends StatelessWidget {
  const _ExpensesCard({required this.summary, required this.onAddExpense});
  final DashboardSummary summary;
  final VoidCallback onAddExpense;

  @override
  Widget build(BuildContext context) {
    final cats = summary.topExpenseCategories;
    if (cats.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(KoraSpacing.cardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.pie_chart_outline_rounded,
                      color: KoraColors.gray),
                  const SizedBox(width: KoraSpacing.sm),
                  Expanded(
                    child: Text(
                      'Pas encore de depenses ce mois.',
                      style: KoraType.bodyStrong(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: KoraSpacing.xs),
              Text(
                'Ajoute ta premiere depense pour voir ou part ton argent.',
                style: KoraType.caption(),
              ),
              const SizedBox(height: KoraSpacing.sm),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.tonalIcon(
                  onPressed: onAddExpense,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Ajouter'),
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
            Text('Ou part ton argent', style: KoraType.cardLabel()),
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
