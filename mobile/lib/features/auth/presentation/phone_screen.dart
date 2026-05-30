import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/kora_colors.dart';
import '../../../core/theme/kora_spacing.dart';
import '../../../core/theme/kora_typography.dart';
import '../../../shared/widgets/kora_logo.dart';
import '../application/auth_controller.dart';

/// Écran 1 du flux auth : saisie du numéro Wave/OM (+225) — CDC F01.
class PhoneScreen extends ConsumerStatefulWidget {
  const PhoneScreen({super.key});

  @override
  ConsumerState<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends ConsumerState<PhoneScreen> {
  final _controller = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isValid => _controller.text.replaceAll(' ', '').length >= 8;

  Future<void> _submit() async {
    final phone = _controller.text.trim();
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final result =
          await ref.read(authControllerProvider.notifier).requestOtp(phone);
      if (!mounted) return;
      context.push('/auth/otp', extra: {
        'phone': phone,
        'expiresIn': result.expiresInSeconds,
        'debugOtp': result.debugOtp,
        'demoMode': result.demoMode,
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(KoraSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              const Center(child: KoraLogo(size: 72)),
              const SizedBox(height: KoraSpacing.xxl),
              Text('Maîtrise ton argent.', style: KoraType.h1()),
              Text('Construis ton avenir.',
                  style: KoraType.h1(color: KoraColors.greenPrimary)),
              const SizedBox(height: KoraSpacing.md),
              Text(
                'Entre ton numéro Wave ou Orange Money. On t\'envoie un code par SMS.',
                style: KoraType.body(color: KoraColors.gray),
              ),
              const SizedBox(height: KoraSpacing.xl),
              TextField(
                controller: _controller,
                keyboardType: TextInputType.phone,
                autofocus: true,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9 +]')),
                ],
                style: KoraType.h2(),
                decoration: const InputDecoration(
                  labelText: 'Numéro de téléphone',
                  hintText: '07 12 34 56 78',
                  prefixText: '+225  ',
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _isValid ? _submit() : null,
              ),
              if (_error != null) ...[
                const SizedBox(height: KoraSpacing.sm),
                Text(_error!, style: KoraType.caption(color: KoraColors.red)),
              ],
              const SizedBox(height: KoraSpacing.md),
              Row(
                children: [
                  const Icon(Icons.lock_outline,
                      size: 16, color: KoraColors.gray),
                  const SizedBox(width: KoraSpacing.xs),
                  Expanded(
                    child: Text(
                      'KORA ne peut pas accéder à ton argent. Il lit uniquement pour t\'aider.',
                      style: KoraType.caption(),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              FilledButton(
                onPressed: (_isValid && !_submitting) ? _submit : null,
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: KoraColors.white),
                      )
                    : const Text('Recevoir mon code'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
