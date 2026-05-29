import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/transactions_repository.dart';
import '../domain/transaction.dart';

/// Liste des transactions de l'utilisateur, filtrable par sens.
final transactionsListProvider =
    FutureProvider.autoDispose.family<List<Transaction>, TxKind?>(
  (ref, kind) => ref.watch(transactionsRepositoryProvider).list(kind: kind),
);

/// Categories disponibles pour la saisie d'une transaction.
final categoriesProvider =
    FutureProvider.autoDispose.family<List<Category>, CategoryKind?>(
  (ref, kind) =>
      ref.watch(transactionsRepositoryProvider).listCategories(kind: kind),
);
