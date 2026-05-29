import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/kora_colors.dart';
import '../../../core/theme/kora_spacing.dart';
import '../../../core/theme/kora_typography.dart';
import '../application/transactions_providers.dart';
import '../data/transactions_repository.dart';
import '../domain/transaction.dart';

/// Feuille de saisie d'une transaction (depense ou entree).
/// Ouvre depuis le FAB du dashboard ou l'ecran liste des transactions.
class AddTransactionSheet extends ConsumerStatefulWidget {
  const AddTransactionSheet({super.key, this.initialKind = TxKind.expense});

  final TxKind initialKind;

  @override
  ConsumerState<AddTransactionSheet> createState() =>
      _AddTransactionSheetState();
}

class _AddTransactionSheetState extends ConsumerState<AddTransactionSheet> {
  late TxKind _kind = widget.initialKind;
  final _amount = TextEditingController();
  final _description = TextEditingController();
  Category? _category;
  DateTime _date = DateTime.now();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    super.dispose();
  }

  CategoryKind get _categoryKind =>
      _kind == TxKind.income ? CategoryKind.income : CategoryKind.expense;

  bool get _isValid => (int.tryParse(_amount.text) ?? 0) > 0;

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(transactionsRepositoryProvider).create(
            amountXof: int.parse(_amount.text),
            kind: _kind,
            occurredAt: _date,
            categoryId: _category?.id,
            description: _description.text.trim().isEmpty
                ? null
                : _description.text.trim(),
          );
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Erreur : $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final categories = ref.watch(categoriesProvider(_categoryKind));

    return Padding(
      padding: EdgeInsets.only(
        left: KoraSpacing.xl,
        right: KoraSpacing.xl,
        top: KoraSpacing.lg,
        bottom: KoraSpacing.xl + bottomInset,
      ),
      // Scroll obligatoire : sur un ecran 5-6" CI avec clavier ouvert, le bouton
      // Enregistrer passe sous le clavier si on ne scroll pas. C'est pour ca que
      // l'ajout d'une depense "ne marche pas" : le bouton est inaccessible.
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: KoraColors.borderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: KoraSpacing.md),
            Text('Nouvelle transaction', style: KoraType.h2()),
            const SizedBox(height: KoraSpacing.md),
            _KindToggle(
              value: _kind,
              onChanged: (k) => setState(() {
                _kind = k;
                _category = null;
              }),
            ),
            const SizedBox(height: KoraSpacing.md),
            TextField(
              controller: _amount,
              autofocus: true,
              keyboardType: TextInputType.number,
              style: KoraType.moneyMedium(),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Montant',
                hintText: '0',
                suffixText: 'FCFA',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: KoraSpacing.sm),
            categories.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => Text(
                'Categories indisponibles — on continue sans.',
                style: KoraType.caption(color: KoraColors.gray),
              ),
              data: (list) => _CategoryPicker(
                categories: list,
                selected: _category,
                onChanged: (c) => setState(() => _category = c),
              ),
            ),
            const SizedBox(height: KoraSpacing.sm),
            TextField(
              controller: _description,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Note (optionnel)',
                hintText: 'Ex: dejeuner avec Aya',
              ),
            ),
            const SizedBox(height: KoraSpacing.sm),
            OutlinedButton.icon(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime.now().subtract(const Duration(days: 365)),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _date = picked);
              },
              icon: const Icon(Icons.event_rounded, size: 18),
              label: Text(DateFormat('d MMM yyyy', 'fr').format(_date)),
            ),
            if (_error != null) ...[
              const SizedBox(height: KoraSpacing.sm),
              Text(_error!, style: KoraType.caption(color: KoraColors.red)),
            ],
            const SizedBox(height: KoraSpacing.md),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: (_isValid && !_submitting) ? _submit : null,
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: KoraColors.white),
                      )
                    : Text(_kind == TxKind.income
                        ? 'Enregistrer l\'entree'
                        : 'Enregistrer la depense'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KindToggle extends StatelessWidget {
  const _KindToggle({required this.value, required this.onChanged});
  final TxKind value;
  final ValueChanged<TxKind> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<TxKind>(
      segments: const [
        ButtonSegment(
          value: TxKind.expense,
          icon: Icon(Icons.north_east_rounded),
          label: Text('Depense'),
        ),
        ButtonSegment(
          value: TxKind.income,
          icon: Icon(Icons.south_west_rounded),
          label: Text('Entree'),
        ),
      ],
      selected: {value},
      onSelectionChanged: (s) => onChanged(s.first),
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: KoraColors.greenPale,
        selectedForegroundColor: KoraColors.greenPrimary,
      ),
    );
  }
}

class _CategoryPicker extends StatelessWidget {
  const _CategoryPicker({
    required this.categories,
    required this.selected,
    required this.onChanged,
  });
  final List<Category> categories;
  final Category? selected;
  final ValueChanged<Category?> onChanged;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Categorie', style: KoraType.fieldLabel()),
        const SizedBox(height: KoraSpacing.xs),
        Wrap(
          spacing: KoraSpacing.xs,
          runSpacing: KoraSpacing.xs,
          children: categories.map((c) {
            final sel = selected?.id == c.id;
            return ChoiceChip(
              label: Text(c.name),
              selected: sel,
              onSelected: (_) => onChanged(sel ? null : c),
              selectedColor: KoraColors.greenPale,
            );
          }).toList(),
        ),
      ],
    );
  }
}
