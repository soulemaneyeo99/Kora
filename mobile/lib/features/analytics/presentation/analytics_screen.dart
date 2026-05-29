import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/format/money.dart';
import '../../../core/theme/kora_colors.dart';
import '../../../core/theme/kora_spacing.dart';
import '../../../core/theme/kora_typography.dart';
import '../../../shared/widgets/async_value_view.dart';
import '../../dashboard/application/dashboard_providers.dart';
import '../../dashboard/domain/dashboard_models.dart';

/// Onglet Analyse (CDC F08) - rapports mensuel : period vs period precedente,
/// repartition par categorie, top depenses, indicateurs de tendance.
class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(dashboardSummaryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Analyse')),
      body: SafeArea(
        child: RefreshIndicator(
          color: KoraColors.greenActive,
          onRefresh: () async {
            ref.invalidate(dashboardSummaryProvider);
            await ref.read(dashboardSummaryProvider.future);
          },
          child: AsyncValueView(
            value: summary,
            onRetry: () => ref.invalidate(dashboardSummaryProvider),
            data: (s) => ListView(
              padding: const EdgeInsets.all(KoraSpacing.pagePadding),
              children: [
                _PeriodHeader(periodStart: s.periodStart),
                const SizedBox(height: KoraSpacing.md),
                _TrendCard(summary: s),
                const SizedBox(height: KoraSpacing.md),
                _ExpensesCategoryCard(items: s.topExpenseCategories),
                const SizedBox(height: KoraSpacing.md),
                _IncomeCategoryCard(items: s.incomeByCategory),
                const SizedBox(height: KoraSpacing.md),
                _GoalsSummaryCard(summary: s),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PeriodHeader extends StatelessWidget {
  const _PeriodHeader({required this.periodStart});
  final DateTime periodStart;

  @override
  Widget build(BuildContext context) {
    final label = DateFormat('MMMM yyyy', 'fr').format(periodStart);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Mois en cours', style: KoraType.caption()),
        Text(label[0].toUpperCase() + label.substring(1),
            style: KoraType.h1()),
      ],
    );
  }
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.summary});
  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final cur = summary.currentPeriod;
    final prev = summary.previousPeriod;

    int pct(int a, int b) {
      if (b == 0) return a == 0 ? 0 : 100;
      return (((a - b) / b) * 100).round();
    }

    final incomeDelta = pct(cur.incomeXof, prev.incomeXof);
    final expenseDelta = pct(cur.expenseXof, prev.expenseXof);
    final netDelta = pct(cur.netXof, prev.netXof);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(KoraSpacing.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Comparaison vs mois precedent', style: KoraType.cardLabel()),
            const SizedBox(height: KoraSpacing.md),
            _TrendRow(
              label: 'Entrees',
              amount: cur.incomeXof,
              deltaPct: incomeDelta,
              good: incomeDelta >= 0,
            ),
            const Divider(height: KoraSpacing.md),
            _TrendRow(
              label: 'Sorties',
              amount: cur.expenseXof,
              deltaPct: expenseDelta,
              good: expenseDelta <= 0,
            ),
            const Divider(height: KoraSpacing.md),
            _TrendRow(
              label: 'Solde net',
              amount: cur.netXof,
              deltaPct: netDelta,
              good: netDelta >= 0,
              isBalance: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendRow extends StatelessWidget {
  const _TrendRow({
    required this.label,
    required this.amount,
    required this.deltaPct,
    required this.good,
    this.isBalance = false,
  });
  final String label;
  final int amount;
  final int deltaPct;
  final bool good;
  final bool isBalance;

  @override
  Widget build(BuildContext context) {
    final deltaColor = good ? KoraColors.greenActive : KoraColors.red;
    final deltaIcon =
        deltaPct >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: KoraType.caption()),
              Text(
                Money.format(amount),
                style: KoraType.moneyMedium(
                  color: isBalance && amount < 0
                      ? KoraColors.red
                      : KoraColors.charcoal,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: KoraSpacing.sm, vertical: 4),
          decoration: BoxDecoration(
            color: deltaColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(KoraSpacing.radiusMd),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(deltaIcon, size: 14, color: deltaColor),
              const SizedBox(width: 4),
              Text(
                '${deltaPct.abs()}%',
                style: KoraType.caption(color: deltaColor),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ExpensesCategoryCard extends StatelessWidget {
  const _ExpensesCategoryCard({required this.items});
  final List<CategoryBreakdownItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(KoraSpacing.cardPadding),
          child: Text(
            'Pas encore de depenses ce mois — rien a analyser pour l\'instant.',
            style: KoraType.body(color: KoraColors.gray),
          ),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(KoraSpacing.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Top depenses par categorie', style: KoraType.cardLabel()),
            const SizedBox(height: KoraSpacing.md),
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: KoraSpacing.sm),
                child: _CategoryRow(item: item, color: KoraColors.gold),
              ),
          ],
        ),
      ),
    );
  }
}

class _IncomeCategoryCard extends StatelessWidget {
  const _IncomeCategoryCard({required this.items});
  final List<CategoryBreakdownItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(KoraSpacing.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('D\'ou viennent tes entrees', style: KoraType.cardLabel()),
            const SizedBox(height: KoraSpacing.md),
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: KoraSpacing.sm),
                child: _CategoryRow(item: item, color: KoraColors.greenActive),
              ),
          ],
        ),
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.item, required this.color});
  final CategoryBreakdownItem item;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(item.categoryName, style: KoraType.bodyStrong()),
            ),
            Text(Money.format(item.amountXof), style: KoraType.bodyStrong()),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (item.pctOfTotal / 100).clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: KoraColors.surfaceLight,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${item.pctOfTotal.toStringAsFixed(1)}% du total',
          style: KoraType.caption(),
        ),
      ],
    );
  }
}

class _GoalsSummaryCard extends StatelessWidget {
  const _GoalsSummaryCard({required this.summary});
  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(KoraSpacing.cardPadding),
        child: Row(
          children: [
            Expanded(
              child: _StatBlock(
                label: 'Objectifs en cours',
                value: '${summary.activeGoalsCount}',
              ),
            ),
            Container(
              width: 1,
              height: 40,
              color: KoraColors.borderLight,
            ),
            Expanded(
              child: _StatBlock(
                label: 'Atteints',
                value: '${summary.completedGoalsCount}',
              ),
            ),
            Container(
              width: 1,
              height: 40,
              color: KoraColors.borderLight,
            ),
            Expanded(
              child: _StatBlock(
                label: 'Epargne',
                value: Money.compact(summary.savingsTotalXof),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatBlock extends StatelessWidget {
  const _StatBlock({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: KoraSpacing.xs),
      child: Column(
        children: [
          Text(value,
              style: KoraType.h2(color: KoraColors.greenPrimary),
              textAlign: TextAlign.center),
          Text(label,
              style: KoraType.caption(), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
