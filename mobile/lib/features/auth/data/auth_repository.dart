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
  const OtpRequestResult({
    required this.expiresInSeconds,
    this.debugOtp,
    this.demoMode = false,
  });
  final int expiresInSeconds;

  /// Code renvoyé uniquement si le backend tourne avec DEBUG_OTP=true,
  /// ou en mode démo (toujours "000000").
  final String? debugOtp;

  /// True quand le backend tourne en AUTH_DEMO_MODE : le mobile auto-soumet.
  final bool demoMode;
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
        demoMode: (data['demo_mode'] as bool?) ?? false,
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

  /// GET /users/me — recharge le profil courant (utilise au bootstrap).
  Future<KoraUser> fetchMe() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/users/me');
      return KoraUser.fromJson(res.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// PATCH /users/me — onboarding F02 + mise a jour du profil.
  Future<KoraUser> updateMe({
    String? displayName,
    IncomeBracket? incomeBracket,
    PrimaryGoal? primaryGoal,
  }) async {
    try {
      final body = <String, dynamic>{
        if (displayName != null) 'display_name': displayName,
        if (incomeBracket != null) 'income_bracket': incomeBracket.apiValue,
        if (primaryGoal != null) 'primary_goal': primaryGoal.apiValue,
      };
      final res = await _dio.patch<Map<String, dynamic>>(
        '/users/me',
        data: body,
      );
      return KoraUser.fromJson(res.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
