import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/providers.dart';
import '../domain/transaction.dart';

final transactionsRepositoryProvider = Provider<TransactionsRepository>(
  (ref) => TransactionsRepository(ref.watch(dioProvider)),
);

class TransactionsRepository {
  TransactionsRepository(this._dio);
  final Dio _dio;

  Future<List<Transaction>> list({TxKind? kind, int limit = 50}) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/transactions',
        queryParameters: {
          if (kind != null) 'kind': kind.apiValue,
          'limit': limit,
        },
      );
      final items = (res.data!['items'] as List).cast<Map<String, dynamic>>();
      return items.map(Transaction.fromJson).toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<Transaction> create({
    required int amountXof,
    required TxKind kind,
    required DateTime occurredAt,
    String? categoryId,
    String? description,
    String? counterparty,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/transactions',
        data: {
          'amount_xof': amountXof,
          'kind': kind.apiValue,
          'occurred_at': occurredAt.toUtc().toIso8601String(),
          if (categoryId != null) 'category_id': categoryId,
          if (description != null && description.isNotEmpty)
            'description': description,
          if (counterparty != null && counterparty.isNotEmpty)
            'counterparty': counterparty,
          'source': 'manual',
        },
      );
      return Transaction.fromJson(res.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> delete(String txId) async {
    try {
      await _dio.delete<void>('/transactions/$txId');
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<List<Category>> listCategories({CategoryKind? kind}) async {
    try {
      final res = await _dio.get<List<dynamic>>(
        '/categories',
        queryParameters: {if (kind != null) 'kind': kind.apiValue},
      );
      return res.data!
          .cast<Map<String, dynamic>>()
          .map(Category.fromJson)
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
