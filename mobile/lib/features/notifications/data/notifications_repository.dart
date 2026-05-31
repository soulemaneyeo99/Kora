import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/providers.dart';

final notificationsRepositoryProvider = Provider<NotificationsRepository>(
  (ref) => NotificationsRepository(ref.watch(dioProvider)),
);

/// Acces aux endpoints /users/me/devices et /notifications/*.
class NotificationsRepository {
  NotificationsRepository(this._dio);
  final Dio _dio;

  /// Enregistre ou rafraichit un device push cote backend (idempotent).
  Future<void> registerDevice({
    required String token,
    required String platform,
    String? label,
    String? locale,
  }) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        '/users/me/devices',
        data: {
          'token': token,
          'platform': platform,
          if (label != null) 'label': label,
          if (locale != null) 'locale': locale,
        },
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Pousse une notification de test au user courant (debug demo).
  Future<NotificationTestResult> sendTest() async {
    try {
      final res = await _dio
          .post<Map<String, dynamic>>('/notifications/test');
      return NotificationTestResult.fromJson(res.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

class NotificationTestResult {
  const NotificationTestResult({
    required this.sentToDevices,
    required this.pushProvider,
    required this.title,
    required this.body,
  });

  final int sentToDevices;
  final String pushProvider;
  final String title;
  final String body;

  factory NotificationTestResult.fromJson(Map<String, dynamic> j) =>
      NotificationTestResult(
        sentToDevices: (j['sent_to_devices'] as num).toInt(),
        pushProvider: j['push_provider'] as String,
        title: j['title'] as String,
        body: j['body'] as String,
      );
}
