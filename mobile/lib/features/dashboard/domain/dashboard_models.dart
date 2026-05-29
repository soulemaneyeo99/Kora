/// Modèles du dashboard — miroir des schémas Pydantic du backend
/// (`app/schemas/dashboard.py`).
library;

class PeriodTotals {
  const PeriodTotals({
    required this.incomeXof,
    required this.expenseXof,
    required this.netXof,
    required this.transactionsCount,
  });

  final int incomeXof;
  final int expenseXof;
  final int netXof;
  final int transactionsCount;

  factory PeriodTotals.fromJson(Map<String, dynamic> j) => PeriodTotals(
        incomeXof: (j['income_xof'] as num).toInt(),
        expenseXof: (j['expense_xof'] as num).toInt(),
        netXof: (j['net_xof'] as num).toInt(),
        transactionsCount: (j['transactions_count'] as num).toInt(),
      );
}

class CategoryBreakdownItem {
  const CategoryBreakdownItem({
    this.categoryId,
    required this.categoryName,
    required this.amountXof,
    required this.pctOfTotal,
  });

  final String? categoryId;
  final String categoryName;
  final int amountXof;
  final double pctOfTotal;

  factory CategoryBreakdownItem.fromJson(Map<String, dynamic> j) =>
      CategoryBreakdownItem(
        categoryId: j['category_id'] as String?,
        categoryName: j['category_name'] as String,
        amountXof: (j['amount_xof'] as num).toInt(),
        pctOfTotal: (j['pct_of_total'] as num).toDouble(),
      );
}

class DashboardSummary {
  const DashboardSummary({
    required this.periodStart,
    required this.periodEnd,
    required this.currentPeriod,
    required this.previousPeriod,
    required this.topExpenseCategories,
    required this.incomeByCategory,
    required this.savingsTotalXof,
    required this.activeGoalsCount,
    required this.completedGoalsCount,
  });

  final DateTime periodStart;
  final DateTime periodEnd;
  final PeriodTotals currentPeriod;
  final PeriodTotals previousPeriod;
  final List<CategoryBreakdownItem> topExpenseCategories;
  final List<CategoryBreakdownItem> incomeByCategory;
  final int savingsTotalXof;
  final int activeGoalsCount;
  final int completedGoalsCount;

  /// Solde estimé de la période (revenus - dépenses) — affiché en grand.
  int get estimatedBalanceXof => currentPeriod.netXof;

  factory DashboardSummary.fromJson(Map<String, dynamic> j) => DashboardSummary(
        periodStart: DateTime.parse(j['period_start'] as String),
        periodEnd: DateTime.parse(j['period_end'] as String),
        currentPeriod:
            PeriodTotals.fromJson(j['current_period'] as Map<String, dynamic>),
        previousPeriod:
            PeriodTotals.fromJson(j['previous_period'] as Map<String, dynamic>),
        topExpenseCategories: (j['top_expense_categories'] as List)
            .map((e) =>
                CategoryBreakdownItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        incomeByCategory: (j['income_by_category'] as List)
            .map((e) =>
                CategoryBreakdownItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        savingsTotalXof: (j['savings_total_xof'] as num).toInt(),
        activeGoalsCount: (j['active_goals_count'] as num).toInt(),
        completedGoalsCount: (j['completed_goals_count'] as num).toInt(),
      );
}

class DisciplineScore {
  const DisciplineScore({
    required this.score,
    required this.grade,
    required this.components,
    required this.insights,
  });

  final int score;
  final String grade;
  final Map<String, int> components;
  final List<String> insights;

  factory DisciplineScore.fromJson(Map<String, dynamic> j) => DisciplineScore(
        score: (j['score'] as num).toInt(),
        grade: j['grade'] as String,
        components: (j['components'] as Map<String, dynamic>)
            .map((k, v) => MapEntry(k, (v as num).toInt())),
        insights: (j['insights'] as List).map((e) => e.toString()).toList(),
      );
}
