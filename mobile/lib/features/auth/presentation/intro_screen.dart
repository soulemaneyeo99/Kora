import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/kora_colors.dart';
import '../../../core/theme/kora_spacing.dart';
import '../../../core/theme/kora_typography.dart';
import '../../../shared/widgets/kora_logo.dart';
import '../application/auth_controller.dart';

const _demoPhone = '+2250700000000';

/// 3 slides d'intro presentant KORA + bouton "Voir la demo" sur le dernier.
/// Une fois passe, on marque `intro_seen` et on route vers /auth ou /auth/otp.
class IntroScreen extends ConsumerStatefulWidget {
  const IntroScreen({super.key});

  @override
  ConsumerState<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends ConsumerState<IntroScreen> {
  final _pageCtrl = PageController();
  int _index = 0;
  bool _launchingDemo = false;
  String? _demoError;

  static const _slides = <_SlideContent>[
    _SlideContent(
      icon: Icons.insights_rounded,
      title: 'Tes finances, claires.',
      body: 'KORA regroupe tes entrees, sorties et epargne en un seul ecran. '
          'Plus de "ou est passe mon argent ?".',
    ),
    _SlideContent(
      icon: Icons.psychology_alt_rounded,
      title: 'Un coach, pas un Excel.',
      body: 'Score de discipline, conseil du jour adapte, prochaine action '
          'concrete. KORA te dit quoi faire ce dimanche.',
    ),
    _SlideContent(
      icon: Icons.savings_rounded,
      title: 'Atteins tes objectifs.',
      body: 'Pots d\'epargne, objectifs SMART, alertes intelligentes. '
          'Tu construis ton avenir, KORA tient le cap.',
    ),
  ];

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    await ref.read(authControllerProvider.notifier).markIntroSeen();
    if (!mounted) return;
    context.go('/auth');
  }

  Future<void> _launchDemo() async {
    setState(() {
      _launchingDemo = true;
      _demoError = null;
    });
    try {
      final result = await ref
          .read(authControllerProvider.notifier)
          .requestOtp(_demoPhone);
      if (!result.demoMode) {
        if (!mounted) return;
        setState(() {
          _demoError = 'Le mode demo n\'est pas active sur le serveur. '
              'Active AUTH_DEMO_MODE=true dans Render et reessaie.';
        });
        return;
      }
      await ref.read(authControllerProvider.notifier).markIntroSeen();
      if (!mounted) return;
      context.push('/auth/otp', extra: {
        'phone': _demoPhone,
        'expiresIn': result.expiresInSeconds,
        'debugOtp': result.debugOtp,
        'demoMode': true,
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _demoError = e.message);
    } finally {
      if (mounted) setState(() => _launchingDemo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _index == _slides.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  KoraSpacing.lg, KoraSpacing.md, KoraSpacing.lg, 0),
              child: Row(
                children: [
                  const KoraLogo(size: 36),
                  const Spacer(),
                  TextButton(
                    onPressed: _continue,
                    child: Text(
                      isLast ? '' : 'Passer',
                      style: KoraType.body(color: KoraColors.gray),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageCtrl,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (_, i) => _SlideView(slide: _slides[i]),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_slides.length, (i) {
                final active = i == _index;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  height: 8,
                  width: active ? 24 : 8,
                  decoration: BoxDecoration(
                    color: active ? KoraColors.greenPrimary : KoraColors.borderLight,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
            if (_demoError != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    KoraSpacing.lg, KoraSpacing.md, KoraSpacing.lg, 0),
                child: Text(
                  _demoError!,
                  textAlign: TextAlign.center,
                  style: KoraType.caption(color: KoraColors.red),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(KoraSpacing.lg),
              child: Column(
                children: [
                  if (isLast)
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: KoraColors.gold,
                          foregroundColor: KoraColors.white,
                        ),
                        onPressed: _launchingDemo ? null : _launchDemo,
                        icon: _launchingDemo
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: KoraColors.white,
                                ),
                              )
                            : const Icon(Icons.play_arrow_rounded),
                        label: const Text('Voir la demo Awa Kone'),
                      ),
                    ),
                  if (isLast) const SizedBox(height: KoraSpacing.sm),
                  SizedBox(
                    width: double.infinity,
                    child: isLast
                        ? OutlinedButton(
                            onPressed: _continue,
                            child: const Text('Commencer avec mon numero'),
                          )
                        : FilledButton(
                            onPressed: () => _pageCtrl.nextPage(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOut,
                            ),
                            child: const Text('Suivant'),
                          ),
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

class _SlideContent {
  const _SlideContent({
    required this.icon,
    required this.title,
    required this.body,
  });
  final IconData icon;
  final String title;
  final String body;
}

class _SlideView extends StatelessWidget {
  const _SlideView({required this.slide});
  final _SlideContent slide;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: KoraSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: 140,
            width: 140,
            decoration: const BoxDecoration(
              color: KoraColors.greenPale,
              shape: BoxShape.circle,
            ),
            child: Icon(slide.icon, color: KoraColors.greenPrimary, size: 72),
          ),
          const SizedBox(height: KoraSpacing.xl),
          Text(slide.title,
              textAlign: TextAlign.center, style: KoraType.h1()),
          const SizedBox(height: KoraSpacing.md),
          Text(slide.body,
              textAlign: TextAlign.center,
              style: KoraType.body(color: KoraColors.gray)),
        ],
      ),
    );
  }
}
