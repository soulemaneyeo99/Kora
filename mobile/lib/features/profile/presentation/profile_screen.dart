import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/kora_colors.dart';
import '../../../core/theme/kora_spacing.dart';
import '../../../core/theme/kora_typography.dart';
import '../../../shared/widgets/kora_logo.dart';
import '../../auth/application/auth_controller.dart';

/// Onglet Profil (CDC F25) — infos compte, abonnement, déconnexion.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(KoraSpacing.pagePadding),
          children: [
            const SizedBox(height: KoraSpacing.md),
            Center(
              child: CircleAvatar(
                radius: 36,
                backgroundColor: KoraColors.greenPale,
                child: Text(
                  (user?.greetingName ?? 'K').characters.first.toUpperCase(),
                  style: KoraType.h1(color: KoraColors.greenPrimary),
                ),
              ),
            ),
            const SizedBox(height: KoraSpacing.sm),
            Center(
                child: Text(user?.greetingName ?? 'Champion',
                    style: KoraType.h2())),
            if (user?.phoneE164 != null)
              Center(child: Text(user!.phoneE164, style: KoraType.caption())),
            if (user?.primaryGoal != null) ...[
              const SizedBox(height: KoraSpacing.xs),
              Center(
                child: Text(
                  '${user!.primaryGoal!.emoji}  Objectif : ${user.primaryGoal!.label}',
                  style: KoraType.caption(),
                ),
              ),
            ],
            const SizedBox(height: KoraSpacing.xl),
            _Tile(
              icon: Icons.workspace_premium_rounded,
              title: 'Abonnement',
              subtitle: 'Freemium — passe en Premium quand tu veux',
              onTap: () => context.push('/profile/premium'),
            ),
            _Tile(
              icon: Icons.military_tech_rounded,
              title: 'Mes badges',
              subtitle: 'Débloque-les par tes actions',
              onTap: () => context.push('/profile/badges'),
            ),
            _Tile(
              icon: Icons.school_outlined,
              title: 'Apprendre',
              subtitle: '6 modules pour mieux gérer ton argent',
              onTap: () => context.push('/profile/learn'),
            ),
            _Tile(
              icon: Icons.notifications_outlined,
              title: 'Notifications',
              subtitle: 'Conseil du jour, rappels objectifs',
              onTap: () => context.push('/profile/notifications'),
            ),
            _Tile(
              icon: Icons.sms_outlined,
              title: 'Importer un SMS',
              subtitle: 'Colle un SMS Wave / OM / MoMo, KORA le lit',
              onTap: () => context.push('/sms-sim'),
            ),
            _Tile(
              icon: Icons.shield_outlined,
              title: 'Sécurité & confidentialité',
              subtitle: 'KORA lit seulement — jamais d\'accès à ton argent',
              onTap: () => _showPrivacyDialog(context),
            ),
            const SizedBox(height: KoraSpacing.lg),
            OutlinedButton.icon(
              onPressed: () => _confirmLogout(context, ref),
              style: OutlinedButton.styleFrom(
                foregroundColor: KoraColors.red,
                side: const BorderSide(color: KoraColors.red),
              ),
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Se déconnecter'),
            ),
            const SizedBox(height: KoraSpacing.xl),
            const Center(child: KoraLogo(size: 40)),
            const SizedBox(height: KoraSpacing.xs),
            Center(child: Text('Version 0.1.7', style: KoraType.caption())),
          ],
        ),
      ),
    );
  }

  Future<void> _showPrivacyDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Sécurité & confidentialité', style: KoraType.h2()),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '• KORA ne touche jamais à ton argent. Aucun virement, aucun retrait.',
                style: KoraType.body(),
              ),
              const SizedBox(height: KoraSpacing.sm),
              Text(
                '• Ton mot de passe mobile money n\'est jamais demandé.',
                style: KoraType.body(),
              ),
              const SizedBox(height: KoraSpacing.sm),
              Text(
                '• Les numéros de tes contacts sont anonymisés (SHA-256) avant tout stockage.',
                style: KoraType.body(),
              ),
              const SizedBox(height: KoraSpacing.sm),
              Text(
                '• Le texte brut des SMS n\'est conservé que 7 jours maximum.',
                style: KoraType.body(),
              ),
              const SizedBox(height: KoraSpacing.sm),
              Text(
                '• Tu peux supprimer ton compte à tout moment.',
                style: KoraType.body(),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('J\'ai compris'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Se déconnecter ?', style: KoraType.h2()),
        content: Text('Tu devras entrer un nouveau code SMS pour revenir.',
            style: KoraType.body()),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: KoraColors.red,
              minimumSize: const Size(0, 44),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Déconnexion'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(authControllerProvider.notifier).logout();
    }
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: KoraSpacing.xs),
      child: Card(
        child: ListTile(
          leading: Icon(icon, color: KoraColors.greenPrimary),
          title: Text(title, style: KoraType.cardLabel()),
          subtitle: Text(subtitle, style: KoraType.caption()),
          trailing:
              const Icon(Icons.chevron_right_rounded, color: KoraColors.gray),
          onTap: onTap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(KoraSpacing.radiusLg),
          ),
        ),
      ),
    );
  }
}
