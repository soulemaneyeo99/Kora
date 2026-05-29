import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/kora_colors.dart';
import '../../../core/theme/kora_spacing.dart';
import '../../../core/theme/kora_typography.dart';
import '../application/auth_controller.dart';
import '../domain/kora_user.dart';

/// Onboarding progressif < 3 min (CDC F02) :
/// 3 ecrans verticaux - prenom, tranche revenus, objectif principal.
/// Pas de pièce d'identite, pas de mot de passe.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _page = PageController();
  final _name = TextEditingController();
  IncomeBracket? _bracket;
  PrimaryGoal? _goal;
  bool _submitting = false;
  String? _error;
  int _step = 0;

  @override
  void initState() {
    super.initState();
    // Prerempli avec ce qu'on connait deja eventuellement.
    final u = ref.read(authControllerProvider).user;
    if (u?.displayName != null) _name.text = u!.displayName!;
    _bracket = u?.incomeBracket;
    _goal = u?.primaryGoal;
  }

  @override
  void dispose() {
    _page.dispose();
    _name.dispose();
    super.dispose();
  }

  bool get _canContinue => switch (_step) {
        0 => _name.text.trim().length >= 2,
        1 => _bracket != null,
        2 => _goal != null,
        _ => false,
      };

  Future<void> _next() async {
    if (_step < 2) {
      setState(() => _step++);
      _page.animateToPage(
        _step,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    // Etape 3 : envoi PATCH /users/me.
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).updateProfile(
            displayName: _name.text.trim(),
            incomeBracket: _bracket,
            primaryGoal: _goal,
          );
      // Le routeur redirige vers /home automatiquement.
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Erreur : $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _back() {
    if (_step == 0) return;
    setState(() => _step--);
    _page.animateToPage(
      _step,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: _step > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: _back,
              )
            : null,
        title: Row(
          children: [
            for (var i = 0; i < 3; i++) ...[
              Expanded(
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: i <= _step
                        ? KoraColors.greenPrimary
                        : KoraColors.borderLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              if (i < 2) const SizedBox(width: KoraSpacing.xs),
            ],
          ],
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(KoraSpacing.xl),
          child: Column(
            children: [
              Expanded(
                child: PageView(
                  controller: _page,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _NameStep(
                      controller: _name,
                      onChanged: () => setState(() {}),
                    ),
                    _BracketStep(
                      selected: _bracket,
                      onChanged: (b) => setState(() => _bracket = b),
                    ),
                    _GoalStep(
                      selected: _goal,
                      onChanged: (g) => setState(() => _goal = g),
                    ),
                  ],
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: KoraSpacing.sm),
                Text(_error!, style: KoraType.caption(color: KoraColors.red)),
              ],
              const SizedBox(height: KoraSpacing.md),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed:
                      (_canContinue && !_submitting) ? _next : null,
                  child: _submitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: KoraColors.white),
                        )
                      : Text(_step < 2 ? 'Continuer' : 'C\'est parti !'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NameStep extends StatelessWidget {
  const _NameStep({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('👋', style: KoraType.h1()),
          const SizedBox(height: KoraSpacing.sm),
          Text('Comment tu t\'appelles ?', style: KoraType.h1()),
          const SizedBox(height: KoraSpacing.xs),
          Text(
            'On l\'utilise juste pour te saluer dans l\'app. Tu peux changer plus tard.',
            style: KoraType.body(color: KoraColors.gray),
          ),
          const SizedBox(height: KoraSpacing.xl),
          TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Ton prenom',
              hintText: 'Ex: Konan',
            ),
            onChanged: (_) => onChanged(),
          ),
        ],
      ),
    );
  }
}

class _BracketStep extends StatelessWidget {
  const _BracketStep({required this.selected, required this.onChanged});
  final IncomeBracket? selected;
  final ValueChanged<IncomeBracket> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('💵', style: KoraType.h1()),
          const SizedBox(height: KoraSpacing.sm),
          Text('Tes revenus du mois', style: KoraType.h1()),
          const SizedBox(height: KoraSpacing.xs),
          Text(
            'Une fourchette suffit. Ca aide KORA a te suggerer un bon rythme d\'epargne.',
            style: KoraType.body(color: KoraColors.gray),
          ),
          const SizedBox(height: KoraSpacing.lg),
          for (final b in IncomeBracket.values)
            Padding(
              padding: const EdgeInsets.only(bottom: KoraSpacing.xs),
              child: _OptionTile(
                title: b.label,
                selected: selected == b,
                onTap: () => onChanged(b),
              ),
            ),
        ],
      ),
    );
  }
}

class _GoalStep extends StatelessWidget {
  const _GoalStep({required this.selected, required this.onChanged});
  final PrimaryGoal? selected;
  final ValueChanged<PrimaryGoal> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('🎯', style: KoraType.h1()),
          const SizedBox(height: KoraSpacing.sm),
          Text('Ton objectif principal', style: KoraType.h1()),
          const SizedBox(height: KoraSpacing.xs),
          Text(
            'On va construire l\'app autour de ca. Tu peux ajouter d\'autres objectifs apres.',
            style: KoraType.body(color: KoraColors.gray),
          ),
          const SizedBox(height: KoraSpacing.lg),
          for (final g in PrimaryGoal.values)
            Padding(
              padding: const EdgeInsets.only(bottom: KoraSpacing.xs),
              child: _OptionTile(
                title: '${g.emoji}  ${g.label}',
                selected: selected == g,
                onTap: () => onChanged(g),
              ),
            ),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(KoraSpacing.radiusLg),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(KoraSpacing.md),
        decoration: BoxDecoration(
          color: selected ? KoraColors.greenPale : KoraColors.surfaceLight,
          borderRadius: BorderRadius.circular(KoraSpacing.radiusLg),
          border: Border.all(
            color:
                selected ? KoraColors.greenPrimary : KoraColors.borderLight,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: KoraType.bodyStrong(
                  color: selected
                      ? KoraColors.greenPrimary
                      : KoraColors.charcoal,
                ),
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle_rounded,
                  color: KoraColors.greenPrimary),
          ],
        ),
      ),
    );
  }
}
