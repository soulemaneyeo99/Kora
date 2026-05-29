import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
            const SizedBox(height: KoraSpacing.xl),
            _Tile(
              icon: Icons.workspace_premium_rounded,
              title: 'Abonnement',
              subtitle: 'Freemium — passe en Premium quand tu veux',
              onTap: () {},
            ),
            _Tile(
              icon: Icons.military_tech_rounded,
              title: 'Mes badges',
              subtitle: 'Débloque-les par tes actions',
              onTap: () {},
            ),
            _Tile(
              icon: Icons.notifications_none_rounded,
              title: 'Notifications',
              subtitle: 'Choisis ce que KORA t\'envoie',
              onTap: () {},
            ),
            _Tile(
              icon: Icons.shield_outlined,
              title: 'Sécurité & confidentialité',
              subtitle: 'KORA lit seulement — jamais d\'accès à ton argent',
              onTap: () {},
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
            Center(child: Text('Version 0.1.0', style: KoraType.caption())),
          ],
        ),
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
