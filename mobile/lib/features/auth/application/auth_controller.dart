import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/token_store.dart';
import '../../../core/providers.dart';
import '../../notifications/application/notification_service.dart';
import '../../notifications/data/notification_prefs.dart';
import '../../notifications/data/notifications_repository.dart';
import '../data/auth_repository.dart';
import '../data/intro_prefs.dart';
import '../domain/kora_user.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

/// Etat de completion onboarding deduit du user courant.
enum OnboardingStatus { unknown, needed, complete }

/// État de session global, observé par le routeur pour rediriger.
class AuthState {
  const AuthState({
    required this.status,
    this.user,
    this.introSeen = false,
  });

  final AuthStatus status;
  final KoraUser? user;

  /// True si l'utilisateur a deja vu les 3 slides d'intro. Charge au bootstrap.
  final bool introSeen;

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isKnown => status != AuthStatus.unknown;

  /// True si on doit montrer l'onboarding (user connecte mais profil incomplet).
  OnboardingStatus get onboardingStatus {
    if (status != AuthStatus.authenticated) return OnboardingStatus.unknown;
    if (user == null) return OnboardingStatus.unknown;
    return user!.hasCompletedOnboarding
        ? OnboardingStatus.complete
        : OnboardingStatus.needed;
  }

  AuthState copyWith({AuthStatus? status, KoraUser? user, bool? introSeen}) =>
      AuthState(
        status: status ?? this.status,
        user: user ?? this.user,
        introSeen: introSeen ?? this.introSeen,
      );

  static const unknown = AuthState(status: AuthStatus.unknown);
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);

/// Pilote le cycle de vie de la session : bootstrap au démarrage,
/// connexion après OTP, déconnexion, expiration.
class AuthController extends Notifier<AuthState> {
  late final TokenStore _tokenStore = ref.read(tokenStoreProvider);
  AuthRepository get _repo => ref.read(authRepositoryProvider);
  NotificationsRepository get _notifRepo =>
      ref.read(notificationsRepositoryProvider);
  NotificationService get _notifService =>
      ref.read(notificationServiceProvider);
  NotificationPrefs get _notifPrefs => ref.read(notificationPrefsProvider);
  IntroPrefs get _introPrefs => ref.read(introPrefsProvider);

  @override
  AuthState build() {
    // Lance la restauration de session sans bloquer la construction.
    _bootstrap();
    return AuthState.unknown;
  }

  Future<void> _bootstrap() async {
    final introSeen = await _introPrefs.isIntroSeen();
    final valid = await _tokenStore.load();
    if (!valid) {
      state = AuthState(
        status: AuthStatus.unauthenticated,
        introSeen: introSeen,
      );
      return;
    }
    try {
      final user = await _repo.fetchMe();
      state = AuthState(
        status: AuthStatus.authenticated,
        user: user,
        introSeen: introSeen,
      );
      unawaited(_postLoginHook());
    } catch (_) {
      await _tokenStore.clear();
      state = AuthState(
        status: AuthStatus.unauthenticated,
        introSeen: introSeen,
      );
    }
  }

  /// Marque l'intro comme vue (3 slides accomplis). Idempotent.
  Future<void> markIntroSeen() async {
    if (state.introSeen) return;
    await _introPrefs.markIntroSeen();
    state = state.copyWith(introSeen: true);
  }

  /// Effets de bord post-connexion : permission, register device, schedule.
  /// Best-effort : aucune erreur ne doit casser le flux d'auth.
  Future<void> _postLoginHook() async {
    try {
      final granted = await _notifService.requestPermissionIfNeeded();
      if (!granted) return;
      final deviceId = await _notifPrefs.deviceId();
      final platform = kIsWeb
          ? 'web'
          : (Platform.isIOS ? 'ios' : 'android');
      await _notifRepo.registerDevice(
        token: deviceId,
        platform: platform,
        label: state.user?.displayName,
      );
      await _notifService.rescheduleDailyTip();
    } catch (_) {
      // notif optionnelle : ne jamais bloquer l'auth.
    }
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
    unawaited(_postLoginHook());
  }

  /// PATCH /users/me + mise a jour de l'etat (onboarding F02, edit profil).
  Future<void> updateProfile({
    String? displayName,
    IncomeBracket? incomeBracket,
    PrimaryGoal? primaryGoal,
  }) async {
    final updated = await _repo.updateMe(
      displayName: displayName,
      incomeBracket: incomeBracket,
      primaryGoal: primaryGoal,
    );
    state = state.copyWith(user: updated);
  }

  Future<void> logout() async {
    await _tokenStore.clear();
    await _notifService.cancelAll();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  /// Appelé par l'intercepteur Dio sur un 401 (token expiré / révoqué).
  void onSessionExpired() {
    if (state.status == AuthStatus.authenticated) {
      _tokenStore.clear();
      _notifService.cancelAll();
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }
}
