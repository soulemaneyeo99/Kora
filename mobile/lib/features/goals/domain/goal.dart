/// Objectif financier — miroir de `GoalOut` (app/schemas/goal.py).
enum GoalStatus { active, completed, abandoned }

GoalStatus _statusFrom(String s) => switch (s) {
      'completed' => GoalStatus.completed,
      'abandoned' => GoalStatus.abandoned,
      _ => GoalStatus.active,
    };

class Goal {
  const Goal({
    required this.id,
    required this.title,
    this.description,
    required this.targetAmountXof,
    required this.currentAmountXof,
    this.targetDate,
    required this.status,
    this.savingsPotId,
    required this.progressPct,
  });

  final String id;
  final String title;
  final String? description;
  final int targetAmountXof;
  final int currentAmountXof;
  final DateTime? targetDate;
  final GoalStatus status;
  final String? savingsPotId;
  final double progressPct;

  double get progress => (progressPct / 100).clamp(0.0, 1.0);
  bool get isReached => currentAmountXof >= targetAmountXof;

  factory Goal.fromJson(Map<String, dynamic> j) => Goal(
        id: j['id'] as String,
        title: j['title'] as String,
        description: j['description'] as String?,
        targetAmountXof: (j['target_amount_xof'] as num).toInt(),
        currentAmountXof: (j['current_amount_xof'] as num).toInt(),
        targetDate: j['target_date'] == null
            ? null
            : DateTime.parse(j['target_date'] as String),
        status: _statusFrom(j['status'] as String),
        savingsPotId: j['savings_pot_id'] as String?,
        progressPct: (j['progress_pct'] as num).toDouble(),
      );
}
