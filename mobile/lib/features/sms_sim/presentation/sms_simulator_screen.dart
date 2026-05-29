import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/kora_colors.dart';
import '../../../core/theme/kora_spacing.dart';
import '../../../core/theme/kora_typography.dart';
import '../../dashboard/application/dashboard_providers.dart';
import '../../transactions/application/transactions_providers.dart';
import '../data/sms_ingest_repository.dart';
import '../domain/ingest_result.dart';

/// Importeur de SMS manuel (CDC F03 — version coller-tester en attendant
/// le NotificationListener Android natif).
///
/// Le client demo en collant un vrai SMS Wave / OM / MoMo, ou pioche dans
/// les exemples : KORA fait tourner le meme pipeline d'ingestion que celui
/// qui sera branche sur les notifications systeme.
class SmsSimulatorScreen extends ConsumerStatefulWidget {
  const SmsSimulatorScreen({super.key});

  @override
  ConsumerState<SmsSimulatorScreen> createState() =>
      _SmsSimulatorScreenState();
}

enum _Provider {
  wave('wave', 'Wave', 'com.wave.personal'),
  orangeMoney('orange_money', 'Orange Money', 'com.orange.om'),
  mtnMomo('mtn_momo', 'MTN MoMo', 'com.mtn.momo');

  const _Provider(this.hint, this.label, this.packageSource);
  final String hint;
  final String label;
  final String packageSource;
}

class _Sample {
  const _Sample(this.label, this.provider, this.text);
  final String label;
  final _Provider provider;
  final String text;
}

const _samples = <_Sample>[
  _Sample(
    'Wave • reçu 5 000',
    _Provider.wave,
    'Vous avez reçu 5 000 FCFA de YEO SOULEYMANE.',
  ),
  _Sample(
    'Wave • envoyé 2 500',
    _Provider.wave,
    'Vous avez envoyé 2 500 FCFA à +2250707070707.',
  ),
  _Sample(
    'OM • reçu 25 000',
    _Provider.orangeMoney,
    'OM Recu 25000 FCFA de 0707070707 le 27/05/2026',
  ),
  _Sample(
    'OM • payé 1 500',
    _Provider.orangeMoney,
    'Vous avez paye 1500 FCFA a SHELL le 27/05/2026',
  ),
  _Sample(
    'MoMo • reçu 10 000',
    _Provider.mtnMomo,
    'Vous avez reçu 10 000 FCFA de +225 07 12 34 56 78. Nouveau solde: 12 500 FCFA.',
  ),
  _Sample(
    'MoMo • paiement 1 500',
    _Provider.mtnMomo,
    'Paiement de 1 500 FCFA chez MAQUIS DU CARREFOUR confirme.',
  ),
];

class _SmsSimulatorScreenState extends ConsumerState<SmsSimulatorScreen> {
  final _controller = TextEditingController();
  _Provider _provider = _Provider.wave;
  bool _busy = false;
  IngestResult? _result;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _applySample(_Sample s) {
    setState(() {
      _provider = s.provider;
      _controller.text = s.text;
      _result = null;
      _error = null;
    });
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Colle un SMS ou choisis un exemple.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _result = null;
      _error = null;
    });
    try {
      final res = await ref.read(smsIngestRepositoryProvider).ingest(
            packageSource: _provider.packageSource,
            rawText: text,
            capturedAt: DateTime.now(),
            parserHint: _provider.hint,
          );
      if (!mounted) return;
      setState(() {
        _result = res;
        _busy = false;
      });
      if (res.success && !res.duplicate) {
        ref.invalidate(transactionsListProvider);
        ref.invalidate(dashboardSummaryProvider);
        ref.invalidate(disciplineScoreProvider);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Importer un SMS')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(KoraSpacing.pagePadding),
          children: [
            const _IntroCard(),
            const SizedBox(height: KoraSpacing.lg),
            Text('1. Choisis l\'opérateur', style: KoraType.cardLabel()),
            const SizedBox(height: KoraSpacing.xs),
            SegmentedButton<_Provider>(
              segments: const [
                ButtonSegment(value: _Provider.wave, label: Text('Wave')),
                ButtonSegment(
                    value: _Provider.orangeMoney, label: Text('Orange')),
                ButtonSegment(value: _Provider.mtnMomo, label: Text('MoMo')),
              ],
              selected: {_provider},
              onSelectionChanged: (s) =>
                  setState(() => _provider = s.first),
            ),
            const SizedBox(height: KoraSpacing.lg),
            Text('2. Colle un vrai SMS — ou prends un exemple',
                style: KoraType.cardLabel()),
            const SizedBox(height: KoraSpacing.xs),
            Wrap(
              spacing: KoraSpacing.xs,
              runSpacing: KoraSpacing.xs,
              children: _samples
                  .map((s) => ActionChip(
                        label: Text(s.label),
                        onPressed: () => _applySample(s),
                      ))
                  .toList(),
            ),
            const SizedBox(height: KoraSpacing.sm),
            TextField(
              controller: _controller,
              maxLines: 6,
              minLines: 3,
              maxLength: 2000,
              keyboardType: TextInputType.multiline,
              decoration: const InputDecoration(
                hintText:
                    'Ex : Vous avez reçu 5 000 FCFA de YEO SOULEYMANE.',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              onChanged: (_) {
                if (_result != null || _error != null) {
                  setState(() {
                    _result = null;
                    _error = null;
                  });
                }
              },
            ),
            const SizedBox(height: KoraSpacing.md),
            SizedBox(
              height: KoraSpacing.buttonHeight,
              child: FilledButton.icon(
                onPressed: _busy ? null : _submit,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: KoraColors.white,
                        ),
                      )
                    : const Icon(Icons.sms_outlined),
                label: Text(_busy ? 'Lecture...' : 'Importer ce SMS'),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: KoraSpacing.md),
              _ErrorCard(message: _error!),
            ],
            if (_result != null) ...[
              const SizedBox(height: KoraSpacing.md),
              _ResultCard(result: _result!),
            ],
            const SizedBox(height: KoraSpacing.xl),
            const _PrivacyNote(),
          ],
        ),
      ),
    );
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: KoraColors.greenPale,
      child: Padding(
        padding: const EdgeInsets.all(KoraSpacing.cardPadding),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.bolt_rounded,
                color: KoraColors.greenPrimary, size: 28),
            const SizedBox(width: KoraSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Lecture automatique des SMS',
                      style: KoraType.bodyStrong(
                          color: KoraColors.greenPrimary)),
                  const SizedBox(height: 2),
                  Text(
                    'Colle un vrai SMS Wave, Orange Money ou MTN MoMo. '
                    'KORA détecte le montant et le sens (entrée / sortie) '
                    'puis crée la transaction toute seule.',
                    style: KoraType.caption(),
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

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});
  final IngestResult result;

  @override
  Widget build(BuildContext context) {
    if (!result.success) {
      return Card(
        color: KoraColors.goldPale,
        child: Padding(
          padding: const EdgeInsets.all(KoraSpacing.cardPadding),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline, color: KoraColors.gold),
              const SizedBox(width: KoraSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('SMS non reconnu', style: KoraType.bodyStrong()),
                    const SizedBox(height: 2),
                    Text(
                      result.reason ??
                          'Format inattendu. Vérifie l\'opérateur sélectionné ou ajoute la transaction manuellement.',
                      style: KoraType.caption(),
                    ),
                    const SizedBox(height: KoraSpacing.xs),
                    Text('Parseur testé : ${result.parserName}',
                        style: KoraType.caption(color: KoraColors.gray)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      color: KoraColors.greenPale,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KoraSpacing.radiusLg),
        side: const BorderSide(color: KoraColors.greenActive, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(KoraSpacing.cardPadding),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.check_circle_rounded,
                color: KoraColors.greenActive, size: 28),
            const SizedBox(width: KoraSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.duplicate
                        ? 'SMS déjà importé'
                        : 'Transaction créée',
                    style: KoraType.bodyStrong(
                        color: KoraColors.greenPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    result.duplicate
                        ? 'KORA détecte les doublons : un même SMS ne crée pas deux transactions.'
                        : 'Va voir ton dashboard ou l\'onglet Transactions : elle y est déjà.',
                    style: KoraType.caption(),
                  ),
                  const SizedBox(height: KoraSpacing.xs),
                  Text('Parseur : ${result.parserName}',
                      style: KoraType.caption(color: KoraColors.gray)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(KoraSpacing.cardPadding),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline, color: KoraColors.red),
            const SizedBox(width: KoraSpacing.sm),
            Expanded(child: Text(message, style: KoraType.body())),
          ],
        ),
      ),
    );
  }
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(KoraSpacing.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ce que KORA fait avec ce SMS',
                style: KoraType.cardLabel()),
            const SizedBox(height: KoraSpacing.xs),
            Text(
              '• Lit seulement le montant et le sens (entrée / sortie).\n'
              '• Anonymise les numéros tiers (SHA-256) avant tout stockage.\n'
              '• Garde le texte brut 7 jours maximum, puis le supprime.\n'
              '• Jamais d\'accès à ton argent ni à ton solde mobile money.',
              style: KoraType.body(),
            ),
          ],
        ),
      ),
    );
  }
}
