import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/kora_colors.dart';
import '../../../core/theme/kora_spacing.dart';
import '../../../core/theme/kora_typography.dart';
import '../../auth/application/auth_controller.dart';

/// Onglet Amis (CDC F21) - parrainage minimum visible :
/// code unique a partager + message preformate. Les badges/defis arrivent
/// dans une iteration suivante.
class CommunityScreen extends ConsumerWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    final code = _referralCode(user?.id);
    final message =
        'Salut ! Avec KORA Finance je suis ma discipline et mes objectifs '
        'd\'epargne directement depuis mon mobile money. Tu devrais essayer. '
        'Mon code parrain : $code';

    return Scaffold(
      appBar: AppBar(title: const Text('Amis')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(KoraSpacing.pagePadding),
          children: [
            const SizedBox(height: KoraSpacing.sm),
            Text('Invite tes amis', style: KoraType.h1()),
            const SizedBox(height: KoraSpacing.xs),
            Text(
              'Plus on est nombreux a tenir notre discipline, plus on tient '
              'sur la duree. Partage ton code, gagne 1 mois Premium par '
              'ami actif (CDC F21).',
              style: KoraType.body(color: KoraColors.gray),
            ),
            const SizedBox(height: KoraSpacing.lg),
            _CodeCard(code: code, message: message),
            const SizedBox(height: KoraSpacing.md),
            _StepsCard(),
            const SizedBox(height: KoraSpacing.md),
            _StatsCard(),
          ],
        ),
      ),
    );
  }

  /// Code de parrainage : derniers 8 hex de l'UUID (sans tirets), en majuscule.
  /// Pas d'info personnelle, juste un identifiant court partageable.
  String _referralCode(String? uid) {
    if (uid == null || uid.isEmpty) return 'KORA-XXXX';
    final hex = uid.replaceAll('-', '');
    final tail = hex.length >= 8 ? hex.substring(hex.length - 8) : hex;
    return 'KORA-${tail.toUpperCase()}';
  }
}

class _CodeCard extends StatelessWidget {
  const _CodeCard({required this.code, required this.message});
  final String code;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: KoraColors.greenPale,
      child: Padding(
        padding: const EdgeInsets.all(KoraSpacing.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ton code parrain', style: KoraType.fieldLabel()),
            const SizedBox(height: KoraSpacing.xs),
            SelectableText(
              code,
              style: KoraType.h1(color: KoraColors.greenPrimary),
            ),
            const SizedBox(height: KoraSpacing.md),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: code));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Code copie'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text('Copier le code'),
                  ),
                ),
                const SizedBox(width: KoraSpacing.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: message));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Message copie - colle dans WhatsApp'),
                            duration: Duration(seconds: 3),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.share_rounded, size: 18),
                    label: const Text('Message'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StepsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final steps = [
      ('1', 'Partage ton code', 'A un ami sur WhatsApp ou en personne.'),
      (
        '2',
        'Ton ami s\'inscrit',
        'Il telecharge KORA et entre ton code a l\'inscription.'
      ),
      (
        '3',
        'Vous gagnez',
        'Toi : 1 mois Premium gratuit. Lui : 14 jours Premium pour demarrer.'
      ),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(KoraSpacing.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Comment ca marche', style: KoraType.cardLabel()),
            const SizedBox(height: KoraSpacing.md),
            for (final (num, title, desc) in steps) ...[
              _StepRow(num: num, title: title, desc: desc),
              if (num != '3') const SizedBox(height: KoraSpacing.md),
            ],
          ],
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.num, required this.title, required this.desc});
  final String num;
  final String title;
  final String desc;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(
            color: KoraColors.greenPrimary,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(num,
                style: KoraType.bodyStrong(color: KoraColors.white)),
          ),
        ),
        const SizedBox(width: KoraSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: KoraType.bodyStrong()),
              Text(desc, style: KoraType.caption()),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Backend ne tracke pas encore les filleuls explicitement - on affiche
    // un compteur a 0 honnete plutot que des fausses metriques.
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(KoraSpacing.cardPadding),
        child: Row(
          children: [
            const Icon(Icons.people_rounded,
                color: KoraColors.greenPrimary, size: 32),
            const SizedBox(width: KoraSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tes filleuls', style: KoraType.cardLabel()),
                  Text('0 amis ont rejoint avec ton code',
                      style: KoraType.caption()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
