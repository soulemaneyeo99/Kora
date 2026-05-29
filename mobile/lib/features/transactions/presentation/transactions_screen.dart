import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/format/money.dart';
import '../../../core/theme/kora_colors.dart';
import '../../../core/theme/kora_spacing.dart';
import '../../../core/theme/kora_typography.dart';
import '../../../shared/widgets/async_value_view.dart';
import '../../dashboard/application/dashboard_providers.dart';
import '../application/transactions_providers.dart';
import '../domain/transaction.dart';
import 'add_transaction_sheet.dart';

/// Liste de toutes les transactions, regroupees par jour, filtrables
/// par sens (Tout / Depenses / Entrees).
class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key, this.initialFilter});

  /// Filtre initial : null = Tout, [TxKind.expense] = depenses, etc.
  final TxKind? initialFilter;

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  late TxKind? _filter = widget.initialFilter;

  Future<void> _openCreateSheet({TxKind initialKind = TxKind.expense}) async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(KoraSpacing.radiusXl)),
      ),
      builder: (_) => AddTransactionSheet(initialKind: initialKind),
    );
    if (created == true) {
      ref.invalidate(transactionsListProvider);
      ref.invalidate(dashboardSummaryProvider);
      ref.invalidate(disciplineScoreProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final txs = ref.watch(transactionsListProvider(_filter));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                KoraSpacing.md, 0, KoraSpacing.md, KoraSpacing.sm),
            child: SegmentedButton<TxKind?>(
              segments: const [
                ButtonSegment(value: null, label: Text('Tout')),
                ButtonSegment(value: TxKind.expense, label: Text('Depenses')),
                ButtonSegment(value: TxKind.income, label: Text('Entrees')),
              ],
              selected: {_filter},
              onSelectionChanged: (s) => setState(() => _filter = s.first),
              showSelectedIcon: false,
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: KoraColors.greenPrimary,
        foregroundColor: KoraColors.white,
        onPressed: () => _openCreateSheet(
          initialKind:
              _filter == TxKind.income ? TxKind.income : TxKind.expense,
        ),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Ajouter'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: KoraColors.greenActive,
          onRefresh: () async {
            ref.invalidate(transactionsListProvider);
            await ref.read(transactionsListProvider(_filter).future);
          },
          child: AsyncValueView(
            value: txs,
            onRetry: () => ref.invalidate(transactionsListProvider),
            data: (list) => list.isEmpty
                ? _Empty(onAdd: _openCreateSheet)
                : _List(items: list),
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(KoraSpacing.xl),
      children: [
        const SizedBox(height: KoraSpacing.huge),
        Text('💸', style: KoraType.h1(), textAlign: TextAlign.center),
        const SizedBox(height: KoraSpacing.md),
        Text('Aucune transaction',
            style: KoraType.h2(), textAlign: TextAlign.center),
        const SizedBox(height: KoraSpacing.xs),
        Text(
          'Note ta premiere depense ou ta premiere entree d\'argent. '
          'KORA s\'occupe du reste : categories, score, conseil du jour.',
          style: KoraType.body(color: KoraColors.gray),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: KoraSpacing.lg),
        Center(
          child: FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Ajouter ma premiere transaction'),
          ),
        ),
      ],
    );
  }
}

class _List extends StatelessWidget {
  const _List({required this.items});
  final List<Transaction> items;

  @override
  Widget build(BuildContext context) {
    final groups = _groupByDay(items);
    final keys = groups.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
          KoraSpacing.md, KoraSpacing.sm, KoraSpacing.md, 96),
      itemCount: keys.length,
      itemBuilder: (_, i) {
        final day = keys[i];
        final dayTxs = groups[day]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: KoraSpacing.xs),
              child: Text(_humanDay(day), style: KoraType.fieldLabel()),
            ),
            Card(
              child: Column(
                children: [
                  for (var j = 0; j < dayTxs.length; j++) ...[
                    _TxTile(tx: dayTxs[j]),
                    if (j < dayTxs.length - 1)
                      const Divider(height: 1, indent: 56),
                  ],
                ],
              ),
            ),
            const SizedBox(height: KoraSpacing.sm),
          ],
        );
      },
    );
  }

  static Map<DateTime, List<Transaction>> _groupByDay(List<Transaction> items) {
    final out = <DateTime, List<Transaction>>{};
    for (final t in items) {
      final d = t.occurredAt.toLocal();
      final key = DateTime(d.year, d.month, d.day);
      out.putIfAbsent(key, () => []).add(t);
    }
    return out;
  }

  static String _humanDay(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    if (d == today) return 'Aujourd\'hui';
    if (d == yesterday) return 'Hier';
    return DateFormat('EEEE d MMM', 'fr').format(d);
  }
}

class _TxTile extends StatelessWidget {
  const _TxTile({required this.tx});
  final Transaction tx;

  @override
  Widget build(BuildContext context) {
    final isIncome = tx.kind == TxKind.income;
    final color = isIncome ? KoraColors.greenActive : KoraColors.charcoal;
    final icon = isIncome ? Icons.south_west_rounded : Icons.north_east_rounded;
    final amount = isIncome
        ? '+${Money.format(tx.amountXof)}'
        : '-${Money.format(tx.amountXof)}';

    return ListTile(
      leading: CircleAvatar(
        radius: 18,
        backgroundColor:
            isIncome ? KoraColors.greenPale : KoraColors.surfaceLight,
        child: Icon(icon, size: 18, color: color),
      ),
      title: Text(
        tx.description?.isNotEmpty == true
            ? tx.description!
            : (isIncome ? 'Entree' : 'Depense'),
        style: KoraType.bodyStrong(),
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        DateFormat('HH:mm', 'fr').format(tx.occurredAt.toLocal()),
        style: KoraType.caption(),
      ),
      trailing: Text(
        amount,
        style: KoraType.moneyMedium(
            color: isIncome ? KoraColors.greenActive : KoraColors.charcoal),
      ),
    );
  }
}
