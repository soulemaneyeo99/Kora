import 'package:flutter/foundation.dart';

/// Configuration d'environnement, surchargée au build via --dart-define.
///
/// Exemples :
///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8001/api/v1
///   flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8001/api/v1
///
/// Valeurs par défaut :
///  - Web / desktop : localhost (le backend dev tourne sur le port 8001).
///  - Émulateur Android : utiliser 10.0.2.2 (alias hôte) via --dart-define.
abstract final class Env {
  Env._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8001/api/v1',
  );

  /// En dev, le backend renvoie l'OTP dans la réponse si DEBUG_OTP=true.
  /// On l'affiche alors pour faciliter les tests.
  ///
  /// Defense en profondeur : on refuse d'afficher l'OTP en build release
  /// meme si quelqu'un passe --dart-define=SHOW_DEBUG_OTP=true par erreur.
  static bool get showDebugOtp => kDebugMode && _showDebugOtpFlag;

  static const bool _showDebugOtpFlag = bool.fromEnvironment(
    'SHOW_DEBUG_OTP',
    defaultValue: true,
  );
}
