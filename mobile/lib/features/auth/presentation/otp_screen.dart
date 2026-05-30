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
    this.demoMode = false,
  });

  final String phone;
  final String? debugOtp;

  /// Backend en AUTH_DEMO_MODE : pré-remplit et soumet automatiquement
  /// pour une connexion en un clic, même en build release.
  final bool demoMode;

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _controller = TextEditingController();
  bool _submitting = false;
  String? _error;

  bool get _showDebugBanner =>
      widget.demoMode || (Env.showDebugOtp && widget.debugOtp != null);

  @override
  void initState() {
    super.initState();
    // Mode démo (backend) OU dev (DEBUG_OTP=true) : pré-remplit.
    if (widget.debugOtp != null && (widget.demoMode || Env.showDebugOtp)) {
      _controller.text = widget.debugOtp!;
    }
    // Mode démo : on soumet tout seul pour éviter toute friction.
    if (widget.demoMode && _controller.text.length >= 4) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _submit());
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
              if (_showDebugBanner) ...[
                const SizedBox(height: KoraSpacing.sm),
                Container(
                  padding: const EdgeInsets.all(KoraSpacing.sm),
                  decoration: BoxDecoration(
                    color: KoraColors.goldPale,
                    borderRadius: BorderRadius.circular(KoraSpacing.radiusMd),
                  ),
                  child: Text(
                    widget.demoMode
                        ? 'Mode démo — connexion automatique (code ${widget.debugOtp ?? "000000"})'
                        : 'Mode dev — code : ${widget.debugOtp}',
                    style: KoraType.caption(color: KoraColors.night),
                  ),
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
