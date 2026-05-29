import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/kora_colors.dart';
import '../../core/theme/kora_spacing.dart';
import '../../core/theme/kora_typography.dart';

/// Rend un [AsyncValue] avec les états chargement / erreur / données,
/// en gardant un ton bienveillant pour les erreurs (charte chapitre 6).
class AsyncValueView<T> extends StatelessWidget {
  const AsyncValueView({
    super.key,
    required this.value,
    required this.data,
    this.onRetry,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: data,
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(KoraSpacing.xxl),
          child: CircularProgressIndicator(color: KoraColors.greenActive),
        ),
      ),
      error: (err, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(KoraSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('😕', style: KoraType.h1()),
              const SizedBox(height: KoraSpacing.xs),
              Text(
                '$err',
                textAlign: TextAlign.center,
                style: KoraType.body(color: KoraColors.gray),
              ),
              if (onRetry != null) ...[
                const SizedBox(height: KoraSpacing.md),
                OutlinedButton(
                  onPressed: onRetry,
                  child: const Text('Réessayer'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
