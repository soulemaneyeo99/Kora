import 'package:flutter/material.dart';

import '../../../core/theme/kora_colors.dart';
import '../../../core/theme/kora_spacing.dart';
import '../../../core/theme/kora_typography.dart';

/// Ecran Abonnement (CDC F25) - informatif Phase 1, paiement reel branche
/// dans une iteration suivante (CinetPay/Wave). On expose ce que Free / Premium
/// donnent, sans tromper l'utilisateur.
class PremiumScreen extends StatelessWidget {
  const PremiumScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Abonnement')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(KoraSpacing.pagePadding),
          children: [
            const _Hero(),
            const SizedBox(height: KoraSpacing.lg),
            const _PlanCard(
              title: 'Free',
              subtitle: 'Pour demarrer ta discipline',
              price: '0 FCFA',
              features: [
                ('Suivi de tes transactions', true),
                ('Score de discipline', true),
                ('Jusqu\'a 2 objectifs d\'epargne', true),
                ('Conseils du jour', true),
                ('Rapports mensuels', true),
                ('Parsing automatique mobile money', false),
                ('Objectifs illimites', false),
                ('Notifications de coaching', false),
                ('Export PDF des rapports', false),
              ],
              isCurrent: true,
              onTap: null,
            ),
            const SizedBox(height: KoraSpacing.md),
            _PlanCard(
              title: 'Premium',
              subtitle: 'Pour vraiment changer ta situation',
              price: '500 FCFA / mois',
              priceHint: 'ou 4 500 FCFA / an (-25%)',
              features: const [
                ('Tout Free', true),
                ('Parsing auto Wave / OM / MoMo', true),
                ('Objectifs illimites', true),
                ('Notifications de coaching', true),
                ('Export PDF des rapports', true),
                ('Support prioritaire', true),
              ],
              isCurrent: false,
              isHighlight: true,
              onTap: () => _showSoonDialog(context),
            ),
            const SizedBox(height: KoraSpacing.lg),
            _NoteCard(),
          ],
        ),
      ),
    );
  }

  void _showSoonDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Bientot disponible', style: KoraType.h2()),
        content: Text(
          'Le paiement de l\'abonnement Premium arrive tres bientot via Wave, '
          'Orange Money et MTN MoMo. On te previent des que c\'est pret.',
          style: KoraType.body(),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Compris'),
          ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero();
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('🚀  Passe au niveau superieur',
            style: KoraType.h1(color: KoraColors.greenPrimary)),
        const SizedBox(height: KoraSpacing.xs),
        Text(
          'KORA reste utilisable gratuitement. Premium debloque les fonctions '
          'qui changent vraiment ta discipline.',
          style: KoraType.body(),
        ),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    required this.subtitle,
    required this.price,
    this.priceHint,
    required this.features,
    required this.isCurrent,
    this.isHighlight = false,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String price;
  final String? priceHint;
  final List<(String, bool)> features;
  final bool isCurrent;
  final bool isHighlight;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: isHighlight ? KoraColors.greenPale : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KoraSpacing.radiusLg),
        side: isHighlight
            ? const BorderSide(color: KoraColors.greenPrimary, width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(KoraSpacing.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(title, style: KoraType.h2()),
                const SizedBox(width: KoraSpacing.xs),
                if (isCurrent)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: KoraColors.greenActive,
                      borderRadius:
                          BorderRadius.circular(KoraSpacing.radiusMd),
                    ),
                    child: Text(
                      'Actuel',
                      style: KoraType.caption(color: KoraColors.white),
                    ),
                  ),
              ],
            ),
            Text(subtitle, style: KoraType.caption()),
            const SizedBox(height: KoraSpacing.sm),
            Text(price, style: KoraType.h1(color: KoraColors.greenPrimary)),
            if (priceHint != null)
              Text(priceHint!, style: KoraType.caption()),
            const SizedBox(height: KoraSpacing.md),
            for (final (label, included) in features)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Icon(
                      included
                          ? Icons.check_rounded
                          : Icons.close_rounded,
                      size: 18,
                      color: included
                          ? KoraColors.greenActive
                          : KoraColors.gray,
                    ),
                    const SizedBox(width: KoraSpacing.xs),
                    Expanded(
                      child: Text(
                        label,
                        style: KoraType.body(
                          color: included
                              ? KoraColors.charcoal
                              : KoraColors.gray,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (onTap != null) ...[
              const SizedBox(height: KoraSpacing.md),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onTap,
                  child: const Text('Passer Premium'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(KoraSpacing.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pourquoi Premium ?', style: KoraType.cardLabel()),
            const SizedBox(height: KoraSpacing.xs),
            Text(
              'KORA reste un produit Cote d\'Ivoire pour les budgets reels. '
              'On garde Free utilisable a vie. Premium finance le '
              'developpement et reste sous 1% de tes revenus medians.',
              style: KoraType.body(),
            ),
          ],
        ),
      ),
    );
  }
}
