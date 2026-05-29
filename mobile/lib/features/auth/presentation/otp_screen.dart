import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/kora_colors.dart';
import '../../../core/theme/kora_spacing.dart';
import '../../../core/theme/kora_typography.dart';
import '../application/auth_controller.dart';

/// Écran 2 du flux auth : saisie du code OTP 6 chiffres — CDC F01.
class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({
    super.key,
    required this.phone,
    this.debugOtp,
  });

  final String phone;
  final String? debugOtp;

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _controller = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // En dev (DEBUG_OTP=true), on pré-remplit pour accélérer les tests.
    if (Env.showDebugOtp && widget.debugOtp != null) {
      _controller.text = widget.debugOtp!;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _controller.text.trim();
    if (code.length < 4) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).verifyOtp(
            phone: widget.phone,
            code: code,
          );
      // Le routeur redirige automatiquement vers /home quand authentifié.
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(leading: const BackButton()),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(KoraSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Ton code', style: KoraType.h1()),
              const SizedBox(height: KoraSpacing.xs),
              Text(
                'Code à 6 chiffres envoyé au ${widget.phone}.',
                style: KoraType.body(color: KoraColors.gray),
              ),
              if (Env.showDebugOtp && widget.debugOtp != null) ...[
                const SizedBox(height: KoraSpacing.sm),
                Container(
                  padding: const EdgeInsets.all(KoraSpacing.sm),
                  decoration: BoxDecoration(
                    color: KoraColors.goldPale,
                    borderRadius: BorderRadius.circular(KoraSpacing.radiusMd),
                  ),
                  child: Text('Mode dev — code : ${widget.debugOtp}',
                      style: KoraType.caption(color: KoraColors.night)),
                ),
              ],
              const SizedBox(height: KoraSpacing.xl),
              TextField(
                controller: _controller,
                keyboardType: TextInputType.number,
                autofocus: true,
                maxLength: 6,
                textAlign: TextAlign.center,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: KoraType.h1().copyWith(letterSpacing: 12),
                decoration: const InputDecoration(
                  counterText: '',
                  hintText: '••••••',
                ),
                onChanged: (v) {
                  setState(() {});
                  if (v.length == 6) _submit();
                },
              ),
              if (_error != null) ...[
                const SizedBox(height: KoraSpacing.sm),
                Text(_error!, style: KoraType.caption(color: KoraColors.red)),
              ],
              const Spacer(),
              FilledButton(
                onPressed: (_controller.text.length >= 4 && !_submitting)
                    ? _submit
                    : null,
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: KoraColors.white),
                      )
                    : const Text('Vérifier'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
