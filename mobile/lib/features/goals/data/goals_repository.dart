import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/providers.dart';
import '../domain/goal.dart';

final goalsRepositoryProvider = Provider<GoalsRepository>(
  (ref) => GoalsRepository(ref.watch(dioProvider)),
);

/// Accès aux endpoints `/goals` (CRUD + contribute/withdraw).
class GoalsRepository {
  GoalsRepository(this._dio);
  final Dio _dio;

  Future<List<Goal>> list({GoalStatus? status}) async {
    try {
      final res = await _dio.get<List<dynamic>>(
        '/goals',
        queryParameters: {
          if (status != null) 'status': status.name,
        },
      );
      return res.data!
          .map((e) => Goal.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<Goal> create({
    required String title,
    required int targetAmountXof,
    DateTime? targetDate,
    String? description,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/goals',
        data: {
          'title': title,
          'target_amount_xof': targetAmountXof,
          if (targetDate != null)
            'target_date': targetDate.toIso8601String().split('T').first,
          if (description != null && description.isNotEmpty)
            'description': description,
        },
      );
      return Goal.fromJson(res.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<Goal> contribute({required String goalId, required int amountXof}) =>
      _movement(goalId, 'contribute', amountXof);

  Future<Goal> withdraw({required String goalId, required int amountXof}) =>
      _movement(goalId, 'withdraw', amountXof);

  Future<Goal> _movement(String goalId, String action, int amountXof) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/goals/$goalId/$action',
        data: {'amount_xof': amountXof},
      );
      return Goal.fromJson(res.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
