import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/application/auth_controller.dart';
import 'network/dio_client.dart';
import 'storage/token_store.dart';

/// Stockage du JWT — singleton applicatif.
final tokenStoreProvider = Provider<TokenStore>((ref) => TokenStore());

/// Client Dio partagé par tous les repositories.
///
/// Sur 401, on déclenche l'expiration de session (déconnexion propre).
final dioProvider = Provider<Dio>((ref) {
  final tokenStore = ref.watch(tokenStoreProvider);
  return buildDio(
    tokenStore: tokenStore,
    onUnauthorized: () {
      ref.read(authControllerProvider.notifier).onSessionExpired();
    },
  );
});
