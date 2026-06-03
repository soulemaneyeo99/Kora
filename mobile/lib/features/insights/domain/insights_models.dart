/// Modeles insights : conseil du jour, badges, next action, forecast.
class DailyTip {
  const DailyTip({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
  });

  final int id;
  final String title;
  final String body;
  final String category;

  factory DailyTip.fromJson(Map<String, dynamic> json) => DailyTip(
        id: json['id'] as int,
        title: json['title'] as String,
        body: json['body'] as String,
        category: json['category'] as String,
      );
}

class KoraBadge {
  const KoraBadge({
    required this.code,
    required this.title,
    required this.description,
    required this.emoji,
    required this.earned,
    this.progressLabel,
  });

  final String code;
  final String title;
  final String description;
  final String emoji;
  final bool earned;
  final String? progressLabel;

  factory KoraBadge.fromJson(Map<String, dynamic> json) => KoraBadge(
        code: json['code'] as String,
        title: json['title'] as String,
        description: json['description'] as String,
        emoji: json['emoji'] as String,
        earned: json['earned'] as bool,
        progressLabel: json['progress_label'] as String?,
      );
}

/// Action concrete recommandee par KORA (carte unique sur le dashboard).
class NextAction {
  const NextAction({
    required this.code,
    required this.title,
    required this.body,
    required this.ctaLabel,
    required this.ctaRoute,
    required this.priority,
    this.amountXof,
  });

  final String code;
  final String title;
  final String body;
  final String ctaLabel;
  final String ctaRoute;
  final int priority;
  final int? amountXof;

  factory NextAction.fromJson(Map<String, dynamic> json) => NextAction(
        code: json['code'] as String,
        title: json['title'] as String,
        body: json['body'] as String,
        ctaLabel: json['cta_label'] as String,
        ctaRoute: json['cta_route'] as String,
        priority: json['priority'] as int,
        amountXof: json['amount_xof'] as int?,
      );
}

/// Prevision de fin de mois (extrapolation lineaire des depenses).
class EndOfMonthForecast {
  const EndOfMonthForecast({
    required this.today,
    required this.daysElapsed,
    required this.daysRemaining,
    required this.incomeSoFarXof,
    required this.expenseSoFarXof,
    required this.projectedExpenseXof,
    required this.projectedBalanceXof,
    required this.dailyAvgExpenseXof,
    required this.headline,
    required this.tone,
  });

  final DateTime today;
  final int daysElapsed;
  final int daysRemaining;
  final int incomeSoFarXof;
  final int expenseSoFarXof;
  final int projectedExpenseXof;
  final int projectedBalanceXof;
  final int dailyAvgExpenseXof;
  final String headline;
  /// good | warning | danger | neutral
  final String tone;

  factory EndOfMonthForecast.fromJson(Map<String, dynamic> json) =>
      EndOfMonthForecast(
        today: DateTime.parse(json['today'] as String),
        daysElapsed: json['days_elapsed'] as int,
        daysRemaining: json['days_remaining'] as int,
        incomeSoFarXof: json['income_so_far_xof'] as int,
        expenseSoFarXof: json['expense_so_far_xof'] as int,
        projectedExpenseXof: json['projected_expense_xof'] as int,
        projectedBalanceXof: json['projected_balance_xof'] as int,
        dailyAvgExpenseXof: json['daily_avg_expense_xof'] as int,
        headline: json['headline'] as String,
        tone: json['tone'] as String,
      );
}
