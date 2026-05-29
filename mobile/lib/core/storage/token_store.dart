import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persistance sécurisée du JWT (Keystore Android / Keychain iOS).
///
/// Le token KORA est un access token JWT (HS256) de 7 jours émis par
/// `POST /auth/otp/verify`. On le garde tel quel + sa date d'expiration.
class TokenStore {
  TokenStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _kToken = 'kora.access_token';
  static const _kExpiresAt = 'kora.expires_at';

  String? _cachedToken;

  /// Accès synchrone (pour l'intercepteur Dio) — alimenté par [load].
  String? get token => _cachedToken;

  Future<void> save(
      {required String token, required DateTime expiresAt}) async {
    _cachedToken = token;
    await _storage.write(key: _kToken, value: token);
    await _storage.write(
      key: _kExpiresAt,
      value: expiresAt.toIso8601String(),
    );
  }

  /// Charge le token au démarrage ; renvoie true s'il est encore valide.
  Future<bool> load() async {
    _cachedToken = await _storage.read(key: _kToken);
    if (_cachedToken == null) return false;

    final raw = await _storage.read(key: _kExpiresAt);
    final expiresAt = raw == null ? null : DateTime.tryParse(raw);
    if (expiresAt != null && expiresAt.isBefore(DateTime.now())) {
      await clear();
      return false;
    }
    return true;
  }

  Future<void> clear() async {
    _cachedToken = null;
    await _storage.delete(key: _kToken);
    await _storage.delete(key: _kExpiresAt);
  }
}
