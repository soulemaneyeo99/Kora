import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/application/auth_controller.dart';
import '../../shared/widgets/kora_logo.dart';
import '../theme/kora_colors.dart';
import '../theme/kora_spacing.dart';
import '../theme/kora_typography.dart';

/// Splash affichee pendant la restauration de session.
///
/// Render free tier endort le backend apres 15min : le 1er reveil prend
/// 30-45s. Sans feedback visible, l'utilisateur croit que l'app est figee.
/// On affiche donc un message qui evolue avec le temps + un bouton
/// "Reessayer" apres 25s qui force un nouveau bootstrap.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  Timer? _ticker;
  int _elapsedSeconds = 0;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsedSeconds++);
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String? get _message {
    if (_elapsedSeconds < 3) return null;
    if (_elapsedSeconds < 12) return 'Démarrage…';
    if (_elapsedSeconds < 25) {
      return 'Réveil du serveur (~30s sur la version gratuite)…';
    }
    return 'C\'est plus long que prévu. Vérifie ta connexion.';
  }

  bool get _showRetry => _elapsedSeconds >= 25;

  void _retry() {
    setState(() => _elapsedSeconds = 0);
    ref.invalidate(authControllerProvider);
  }

  @override
  Widget build(BuildContext context) {
    final msg = _message;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: KoraSpacing.pagePadding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const KoraLogo(size: 96),
                const SizedBox(height: KoraSpacing.xl),
                const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: KoraColors.greenActive,
                  ),
                ),
                const SizedBox(height: KoraSpacing.lg),
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 250),
                  opacity: msg == null ? 0 : 1,
                  child: Text(
                    msg ?? '',
                    textAlign: TextAlign.center,
                    style: KoraType.body(color: KoraColors.gray),
                  ),
                ),
                if (_showRetry) ...[
                  const SizedBox(height: KoraSpacing.lg),
                  OutlinedButton.icon(
                    onPressed: _retry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Réessayer'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
