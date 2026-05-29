import 'package:flutter/foundation.dart';

/// Configuration d'environnement, surchargée au build via --dart-define.
///
/// Valeur par défaut = backend prod Render. Un APK release oublié sans
/// `--dart-define` pointe donc sur prod, pas sur localhost (qui cassait
/// l'app pour le client). En dev local, on override explicitement :
///
///   flutter run --dart-define=API_BASE_URL=http://localhost:8001/api/v1
///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8001/api/v1  # emu Android
///   flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8001/api/v1
abstract final class Env {
  Env._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://kora-backend-17ws.onrender.com/api/v1',
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
