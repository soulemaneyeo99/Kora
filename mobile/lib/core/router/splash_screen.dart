import 'package:flutter/material.dart';

import '../theme/kora_colors.dart';
import '../theme/kora_spacing.dart';
import '../../shared/widgets/kora_logo.dart';

/// Écran de démarrage affiché pendant la restauration de session.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            KoraLogo(size: 88),
            SizedBox(height: KoraSpacing.xl),
            SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: KoraColors.greenActive,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
