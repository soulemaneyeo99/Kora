import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/format/money.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/kora_colors.dart';
import '../../../core/theme/kora_spacing.dart';
import '../../../core/theme/kora_typography.dart';
import '../../../shared/widgets/async_value_view.dart';
import '../../../shared/widgets/kora_progress_bar.dart';
import '../application/goals_providers.dart';
import '../data/goals_repository.dart';
import '../domain/goal.dart';

/// Onglet Objectifs (CDC F12/F13) : liste des pots d'épargne + création.
class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(goalsListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mes objectifs')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: KoraColors.greenPrimary,
        foregroundColor: KoraColors.white,
        onPressed: () => _openCreateSheet(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Objectif'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: KoraColors.greenActive,
          onRefresh: () async {
            ref.invalidate(goalsListProvider);
            await ref.read(goalsListProvider.future);
          },
          child: AsyncValueView(
            value: goals,
            onRetry: () => ref.invalidate(goalsListProvider),
            data: (list) => list.isEmpty
                ? const _EmptyGoals()
                : ListView.separated(
                    padding: const EdgeInsets.all(KoraSpacing.pagePadding),
                    itemCount: list.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: KoraSpacing.sm),
                    itemBuilder: (_, i) => _GoalCard(goal: list[i], ref: ref),
                  ),
          ),
        ),
      ),
    );
  }

  Future<void> _openCreateSheet(BuildContext context, WidgetRef ref) async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(KoraSpacing.radiusXl)),
      ),
      builder: (_) => const _CreateGoalSheet(),
    );
    if (created == true) ref.invalidate(goalsListProvider);
  }
}

class _EmptyGoals extends StatelessWidget {
  const _EmptyGoals();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(KoraSpacing.xl),
      children: [
        const SizedBox(height: KoraSpacing.huge),
        Text('🎯', style: KoraType.h1(), textAlign: TextAlign.center),
        const SizedBox(height: KoraSpacing.md),
        Text('Ton premier objectif t\'attend',
            style: KoraType.h2(), textAlign: TextAlign.center),
        const SizedBox(height: KoraSpacing.xs),
        Text(
          'Un Samsung, un loyer, un business... Donne un but à ton épargne. '
          'KORA calcule combien mettre de côté chaque mois.',
          style: KoraType.body(color: KoraColors.gray),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.goal, required this.ref});
  final Goal goal;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(KoraSpacing.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(goal.title, style: KoraType.cardLabel()),
                ),
                if (goal.isReached)
                  const Icon(Icons.verified_rounded, color: KoraColors.gold),
              ],
            ),
            const SizedBox(height: KoraSpacing.xs),
            Text(
              '${Money.compact(goal.currentAmountXof)} / ${Money.format(goal.targetAmountXof)}',
              style: KoraType.moneyMedium(),
            ),
            const SizedBox(height: KoraSpacing.sm),
            KoraProgressBar(value: goal.progress),
            if (goal.targetDate != null) ...[
              const SizedBox(height: KoraSpacing.xs),
              Text(
                'Échéance : ${DateFormat('d MMM yyyy', 'fr').format(goal.targetDate!)}',
                style: KoraType.caption(),
              ),
            ],
            const SizedBox(height: KoraSpacing.sm),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: () => _contribute(context),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  padding:
                      const EdgeInsets.symmetric(horizontal: KoraSpacing.md),
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Alimenter'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _contribute(BuildContext context) async {
    final controller = TextEditingController();
    final amount = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Alimenter "${goal.title}"', style: KoraType.h2()),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: 'Montant',
            suffixText: 'FCFA',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: () {
              final v = int.tryParse(controller.text);
              Navigator.pop(ctx, (v != null && v > 0) ? v : null);
            },
            child: const Text('Valider'),
          ),
        ],
      ),
    );
    if (amount == null || !context.mounted) return;
    try {
      await ref
          .read(goalsRepositoryProvider)
          .contribute(goalId: goal.id, amountXof: amount);
      ref.invalidate(goalsListProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bien joué ! +${Money.format(amount)} 💪')),
        );
      }
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }
}

/// Feuille de création d'objectif (CDC F12 : nom, montant, date).
class _CreateGoalSheet extends ConsumerStatefulWidget {
  const _CreateGoalSheet();

  @override
  ConsumerState<_CreateGoalSheet> createState() => _CreateGoalSheetState();
}

class _CreateGoalSheetState extends ConsumerState<_CreateGoalSheet> {
  final _title = TextEditingController();
  final _amount = TextEditingController();
  DateTime? _date;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    super.dispose();
  }

  bool get _isValid =>
      _title.text.trim().isNotEmpty && (int.tryParse(_amount.text) ?? 0) > 0;

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(goalsRepositoryProvider).create(
            title: _title.text.trim(),
            targetAmountXof: int.parse(_amount.text),
            targetDate: _date,
          );
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(
        left: KoraSpacing.xl,
        right: KoraSpacing.xl,
        top: KoraSpacing.xl,
        bottom: KoraSpacing.xl + bottomInset,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Nouvel objectif', style: KoraType.h2()),
          const SizedBox(height: KoraSpacing.md),
          TextField(
            controller: _title,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Nom',
              hintText: 'Mon Samsung A55',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: KoraSpacing.sm),
          TextField(
            controller: _amount,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Montant cible',
              suffixText: 'FCFA',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: KoraSpacing.sm),
          OutlinedButton.icon(
            onPressed: () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                firstDate: now,
                lastDate: DateTime(now.year + 10),
                initialDate: now.add(const Duration(days: 90)),
              );
              if (picked != null) setState(() => _date = picked);
            },
            icon: const Icon(Icons.event_rounded, size: 18),
            label: Text(
              _date == null
                  ? 'Date souhaitée (optionnel)'
                  : DateFormat('d MMM yyyy', 'fr').format(_date!),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: KoraSpacing.sm),
            Text(_error!, style: KoraType.caption(color: KoraColors.red)),
          ],
          const SizedBox(height: KoraSpacing.md),
          FilledButton(
            onPressed: (_isValid && !_submitting) ? _submit : null,
            child: _submitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: KoraColors.white),
                  )
                : const Text('Créer mon objectif'),
          ),
        ],
      ),
    );
  }
}
