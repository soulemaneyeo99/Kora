import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/dashboard_repository.dart';
import '../domain/dashboard_models.dart';

/// Résumé du dashboard (mois courant) — rechargeable via ref.invalidate.
final dashboardSummaryProvider = FutureProvider.autoDispose<DashboardSummary>(
  (ref) => ref.watch(dashboardRepositoryProvider).fetchSummary(),
);

/// Score de discipline (30 derniers jours roulants).
final disciplineScoreProvider = FutureProvider.autoDispose<DisciplineScore>(
  (ref) => ref.watch(dashboardRepositoryProvider).fetchScore(),
);
