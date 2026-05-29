import 'package:dio/dio.dart';

/// Erreur API normalisée, prête à afficher à l'utilisateur (français CI,
/// ton bienveillant — charte chapitre 6).
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  bool get isUnauthorized => statusCode == 401;

  /// Construit un message lisible à partir d'une DioException.
  factory ApiException.fromDio(DioException e) {
    final status = e.response?.statusCode;
    final data = e.response?.data;

    // FastAPI renvoie {"detail": "..."} ou {"detail": [{...}]}.
    String? detail;
    if (data is Map && data['detail'] != null) {
      final d = data['detail'];
      if (d is String) {
        detail = d;
      } else if (d is List && d.isNotEmpty) {
        final first = d.first;
        if (first is Map && first['msg'] != null) {
          detail = first['msg'].toString();
        }
      }
    }

    final message = switch (e.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout =>
        'Connexion trop lente. Réessaie dans un instant.',
      DioExceptionType.connectionError =>
        'Pas de connexion au serveur KORA. Vérifie ton réseau.',
      _ => detail ?? _fromStatus(status),
    };

    return ApiException(message, statusCode: status);
  }

  static String _fromStatus(int? status) => switch (status) {
        400 => 'Demande invalide.',
        401 => 'Ta session a expiré. Reconnecte-toi.',
        403 => 'Action non autorisée.',
        404 => 'Introuvable.',
        409 => 'Conflit avec une donnée existante.',
        429 => 'Trop de tentatives. Patiente un peu.',
        final int s when s >= 500 =>
          'Le serveur KORA a un souci. On revient vite.',
        _ => 'Une erreur est survenue.',
      };

  @override
  String toString() => message;
}
