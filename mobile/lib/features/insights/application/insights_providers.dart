import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/insights_repository.dart';
import '../domain/insights_models.dart';

/// Conseil du jour (deterministe user+date cote backend).
final dailyTipProvider = FutureProvider.autoDispose<DailyTip>(
  (ref) => ref.watch(insightsRepositoryProvider).fetchDailyTip(),
);

/// Liste des 8 badges (CDC F19).
final badgesProvider = FutureProvider.autoDispose<List<KoraBadge>>(
  (ref) => ref.watch(insightsRepositoryProvider).fetchKoraBadges(),
);

/// Prochaine action recommandee par KORA (carte unique sur le dashboard).
final nextActionProvider = FutureProvider.autoDispose<NextAction>(
  (ref) => ref.watch(insightsRepositoryProvider).fetchNextAction(),
);

/// Prevision de fin de mois (extrapolation lineaire des depenses).
final forecastProvider = FutureProvider.autoDispose<EndOfMonthForecast>(
  (ref) => ref.watch(insightsRepositoryProvider).fetchForecast(),
);
