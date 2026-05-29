import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/providers.dart';
import '../domain/kora_user.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(dioProvider)),
);

/// Résultat d'une demande d'OTP.
class OtpRequestResult {
  const OtpRequestResult({required this.expiresInSeconds, this.debugOtp});
  final int expiresInSeconds;

  /// Code renvoyé uniquement si le backend tourne avec DEBUG_OTP=true.
  final String? debugOtp;
}

/// Résultat d'une vérification d'OTP réussie.
class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.expiresAt,
    required this.user,
  });
  final String accessToken;
  final DateTime expiresAt;
  final KoraUser user;
}

/// Appels au module auth OTP du backend FastAPI.
class AuthRepository {
  AuthRepository(this._dio);
  final Dio _dio;

  /// POST /auth/otp/request — déclenche l'envoi du SMS (throttle 60s côté API).
  Future<OtpRequestResult> requestOtp(String phone) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/auth/otp/request',
        data: {'phone': phone},
      );
      final data = res.data!;
      return OtpRequestResult(
        expiresInSeconds: (data['expires_in_seconds'] as num).toInt(),
        debugOtp: data['debug_otp'] as String?,
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// POST /auth/otp/verify — vérifie le code, crée le user au besoin, renvoie le JWT.
  Future<AuthSession> verifyOtp({
    required String phone,
    required String code,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/auth/otp/verify',
        data: {'phone': phone, 'code': code},
      );
      final data = res.data!;
      return AuthSession(
        accessToken: data['access_token'] as String,
        expiresAt: DateTime.parse(data['expires_at'] as String),
        user: KoraUser.fromJson(data['user'] as Map<String, dynamic>),
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
