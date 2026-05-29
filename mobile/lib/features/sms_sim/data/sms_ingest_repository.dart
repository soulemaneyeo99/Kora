import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/providers.dart';
import '../domain/ingest_result.dart';

final smsIngestRepositoryProvider = Provider<SmsIngestRepository>(
  (ref) => SmsIngestRepository(ref.watch(dioProvider)),
);

/// Acces a `POST /transactions/ingest`.
/// Endpoint partage avec le futur NotificationListener Android (F03).
class SmsIngestRepository {
  SmsIngestRepository(this._dio);
  final Dio _dio;

  Future<IngestResult> ingest({
    required String packageSource,
    required String rawText,
    required DateTime capturedAt,
    String? parserHint,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/transactions/ingest',
        data: {
          'package_source': packageSource,
          'raw_text': rawText,
          'captured_at': capturedAt.toUtc().toIso8601String(),
          if (parserHint != null) 'parser_hint': parserHint,
        },
      );
      return IngestResult.fromJson(res.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
