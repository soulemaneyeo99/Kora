import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/token_store.dart';
import '../../../core/providers.dart';
import '../data/auth_repository.dart';
import '../domain/kora_user.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

/// État de session global, observé par le routeur pour rediriger.
class AuthState {
  const AuthState({required this.status, this.user});

  final AuthStatus status;
  final KoraUser? user;

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isKnown => status != AuthStatus.unknown;

  AuthState copyWith({AuthStatus? status, KoraUser? user}) =>
      AuthState(status: status ?? this.status, user: user ?? this.user);

  static const unknown = AuthState(status: AuthStatus.unknown);
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);

/// Pilote le cycle de vie de la session : bootstrap au démarrage,
/// connexion après OTP, déconnexion, expiration.
class AuthController extends Notifier<AuthState> {
  late final TokenStore _tokenStore = ref.read(tokenStoreProvider);
  AuthRepository get _repo => ref.read(authRepositoryProvider);

  @override
  AuthState build() {
    // Lance la restauration de session sans bloquer la construction.
    _bootstrap();
    return AuthState.unknown;
  }

  Future<void> _bootstrap() async {
    final valid = await _tokenStore.load();
    state = AuthState(
      status: valid ? AuthStatus.authenticated : AuthStatus.unauthenticated,
    );
  }

  /// Étape 1 : envoi de l'OTP. Remonte le résultat (incl. debug_otp en dev).
  Future<OtpRequestResult> requestOtp(String phone) => _repo.requestOtp(phone);

  /// Étape 2 : vérification du code -> stockage du JWT + passage authentifié.
  Future<void> verifyOtp({required String phone, required String code}) async {
    final session = await _repo.verifyOtp(phone: phone, code: code);
    await _tokenStore.save(
      token: session.accessToken,
      expiresAt: session.expiresAt,
    );
    state = AuthState(status: AuthStatus.authenticated, user: session.user);
  }

  Future<void> logout() async {
    await _tokenStore.clear();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  /// Appelé par l'intercepteur Dio sur un 401 (token expiré / révoqué).
  void onSessionExpired() {
    if (state.status == AuthStatus.authenticated) {
      _tokenStore.clear();
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }
}
