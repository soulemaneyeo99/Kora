import 'package:flutter/material.dart';

import '../../../shared/widgets/coming_soon.dart';

/// Onglet Communauté (CDC F19-F24) — badges, défis, parrainage, forums.
/// La plupart de ces fonctionnalités sont Phase 2.
class CommunityScreen extends StatelessWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Communauté')),
      body: const SafeArea(
        child: ComingSoon(
          emoji: '🤝',
          title: 'On construit ça ensemble',
          subtitle:
              'Bientôt : badges, défis d\'épargne, parrainage de tes amis et '
              'classements. Discipline + entraide.',
          phase: 'Phase 1/2',
        ),
      ),
    );
  }
}
