import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/providers.dart';
import '../domain/dashboard_models.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>(
  (ref) => DashboardRepository(ref.watch(dioProvider)),
);

/// Accès aux endpoints `/dashboard/summary` et `/dashboard/score`.
class DashboardRepository {
  DashboardRepository(this._dio);
  final Dio _dio;

  Future<DashboardSummary> fetchSummary() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/dashboard/summary');
      return DashboardSummary.fromJson(res.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<DisciplineScore> fetchScore() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/dashboard/score');
      return DisciplineScore.fromJson(res.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
