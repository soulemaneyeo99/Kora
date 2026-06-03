import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/providers.dart';
import '../domain/insights_models.dart';

final insightsRepositoryProvider = Provider<InsightsRepository>(
  (ref) => InsightsRepository(ref.watch(dioProvider)),
);

/// Acces aux endpoints insights : daily-tip, badges, next-action, forecast.
class InsightsRepository {
  InsightsRepository(this._dio);
  final Dio _dio;

  Future<DailyTip> fetchDailyTip() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/insights/daily-tip');
      return DailyTip.fromJson(res.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<List<KoraBadge>> fetchKoraBadges() async {
    try {
      final res = await _dio.get<List<dynamic>>('/insights/badges');
      return (res.data ?? [])
          .map((e) => KoraBadge.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<NextAction> fetchNextAction() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/insights/next-action');
      return NextAction.fromJson(res.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<EndOfMonthForecast> fetchForecast() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/insights/forecast');
      return EndOfMonthForecast.fromJson(res.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
