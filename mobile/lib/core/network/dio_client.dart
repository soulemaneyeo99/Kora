import 'package:dio/dio.dart';

import '../config/env.dart';
import '../storage/token_store.dart';

/// Construit le client Dio configuré pour le backend FastAPI KORA :
///  - base URL versionnée (/api/v1),
///  - injection automatique du Bearer JWT,
///  - notification [onUnauthorized] sur 401 (token expiré -> logout).
Dio buildDio({
  required TokenStore tokenStore,
  required void Function() onUnauthorized,
}) {
  // Render free tier endort le service apres 15min : le premier appel apres
  // sleep peut prendre 30-45s pour reveiller le container. On laisse de la
  // marge sur les timeouts pour eviter une fausse alerte reseau a froid.
  final dio = Dio(
    BaseOptions(
      baseUrl: Env.apiBaseUrl,
      connectTimeout: const Duration(seconds: 45),
      receiveTimeout: const Duration(seconds: 45),
      contentType: 'application/json',
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = tokenStore.token;
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (err, handler) {
        // Token expiré / révoqué : on déclenche une déconnexion propre.
        if (err.response?.statusCode == 401) {
          onUnauthorized();
        }
        handler.next(err);
      },
    ),
  );

  return dio;
}
