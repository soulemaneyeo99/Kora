/// Modeles insights : conseil du jour + badges (CDC F11, F19).
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
