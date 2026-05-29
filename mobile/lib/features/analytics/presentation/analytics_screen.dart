import 'package:flutter/material.dart';

import '../../../shared/widgets/coming_soon.dart';

/// Onglet Analyse (CDC F08) — rapports hebdo/mensuel.
/// Squelette en place ; les graphes détaillés arrivent ensuite.
class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Analyse')),
      body: const SafeArea(
        child: ComingSoon(
          emoji: '📊',
          title: 'Tes rapports arrivent',
          subtitle:
              'Bientôt : dépenses par semaine et par mois, comparaison vs '
              'période précédente, et top de tes catégories.',
          phase: 'Phase 1 — hebdo / mensuel',
        ),
      ),
    );
  }
}
