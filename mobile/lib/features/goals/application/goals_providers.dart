import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/goals_repository.dart';
import '../domain/goal.dart';

/// Liste des objectifs de l'utilisateur (tous statuts).
final goalsListProvider = FutureProvider.autoDispose<List<Goal>>(
  (ref) => ref.watch(goalsRepositoryProvider).list(),
);
