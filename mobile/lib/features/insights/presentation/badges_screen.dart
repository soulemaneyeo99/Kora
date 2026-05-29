import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/kora_colors.dart';
import '../../../core/theme/kora_spacing.dart';
import '../../../core/theme/kora_typography.dart';
import '../../../shared/widgets/async_value_view.dart';
import '../application/insights_providers.dart';
import '../domain/insights_models.dart';

/// Ecran Mes badges (CDC F19) - 8 badges Phase 1, calcules cote backend.
class BadgesScreen extends ConsumerWidget {
  const BadgesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final badges = ref.watch(badgesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Mes badges')),
      body: SafeArea(
        child: RefreshIndicator(
          color: KoraColors.greenActive,
          onRefresh: () async {
            ref.invalidate(badgesProvider);
            await ref.read(badgesProvider.future);
          },
          child: AsyncValueView(
            value: badges,
            onRetry: () => ref.invalidate(badgesProvider),
            data: (list) {
              final earned = list.where((b) => b.earned).length;
              return ListView(
                padding: const EdgeInsets.all(KoraSpacing.pagePadding),
                children: [
                  _Header(earnedCount: earned, total: list.length),
                  const SizedBox(height: KoraSpacing.lg),
                  for (final b in list)
                    Padding(
                      padding: const EdgeInsets.only(bottom: KoraSpacing.sm),
                      child: _BadgeRow(badge: b),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.earnedCount, required this.total});
  final int earnedCount;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: KoraColors.greenPale,
      child: Padding(
        padding: const EdgeInsets.all(KoraSpacing.cardPadding),
        child: Row(
          children: [
            Text('🏅', style: KoraType.h1()),
            const SizedBox(width: KoraSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$earnedCount / $total debloques',
                      style: KoraType.h2(color: KoraColors.greenPrimary)),
                  Text(
                    earnedCount == 0
                        ? 'Lance-toi : ton premier badge est a une transaction.'
                        : 'Bravo. Continue, il en reste a debloquer.',
                    style: KoraType.caption(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BadgeRow extends StatelessWidget {
  const _BadgeRow({required this.badge});
  final KoraBadge badge;

  @override
  Widget build(BuildContext context) {
    final earned = badge.earned;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(KoraSpacing.cardPadding),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: earned ? KoraColors.greenPale : KoraColors.surfaceLight,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Opacity(
                opacity: earned ? 1.0 : 0.35,
                child: Text(badge.emoji, style: const TextStyle(fontSize: 28)),
              ),
            ),
            const SizedBox(width: KoraSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          badge.title,
                          style: KoraType.bodyStrong(
                            color: earned
                                ? KoraColors.charcoal
                                : KoraColors.gray,
                          ),
                        ),
                      ),
                      if (earned)
                        const Icon(Icons.check_circle_rounded,
                            color: KoraColors.greenActive, size: 20)
                      else if (badge.progressLabel != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: KoraColors.surfaceLight,
                            borderRadius:
                                BorderRadius.circular(KoraSpacing.radiusMd),
                          ),
                          child: Text(badge.progressLabel!,
                              style: KoraType.caption()),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(badge.description,
                      style: KoraType.caption(color: KoraColors.gray)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
