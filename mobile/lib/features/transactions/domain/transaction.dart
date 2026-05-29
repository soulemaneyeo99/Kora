/// Modeles transactions et categories — miroir des schemas Pydantic du
/// backend (`app/schemas/transaction.py`, `app/schemas/category.py`).
library;

enum TxKind {
  income,
  expense,
  transfer;

  String get apiValue => name;

  static TxKind fromApi(String v) => TxKind.values
      .firstWhere((k) => k.apiValue == v, orElse: () => TxKind.expense);
}

enum CategoryKind {
  income,
  expense;

  String get apiValue => name;

  static CategoryKind fromApi(String v) => CategoryKind.values
      .firstWhere((k) => k.apiValue == v, orElse: () => CategoryKind.expense);
}

class Category {
  const Category({
    required this.id,
    required this.name,
    required this.kind,
    this.icon,
    this.color,
    required this.isDefault,
  });

  final String id;
  final String name;
  final CategoryKind kind;
  final String? icon;
  final String? color;
  final bool isDefault;

  factory Category.fromJson(Map<String, dynamic> j) => Category(
        id: j['id'] as String,
        name: j['name'] as String,
        kind: CategoryKind.fromApi(j['kind'] as String),
        icon: j['icon'] as String?,
        color: j['color'] as String?,
        isDefault: j['is_default'] as bool? ?? false,
      );
}

class Transaction {
  const Transaction({
    required this.id,
    required this.amountXof,
    required this.kind,
    required this.occurredAt,
    this.categoryId,
    this.description,
    this.counterparty,
  });

  final String id;
  final int amountXof;
  final TxKind kind;
  final DateTime occurredAt;
  final String? categoryId;
  final String? description;
  final String? counterparty;

  factory Transaction.fromJson(Map<String, dynamic> j) => Transaction(
        id: j['id'] as String,
        amountXof: (j['amount_xof'] as num).toInt(),
        kind: TxKind.fromApi(j['kind'] as String),
        occurredAt: DateTime.parse(j['occurred_at'] as String),
        categoryId: j['category_id'] as String?,
        description: j['description'] as String?,
        counterparty: j['counterparty'] as String?,
      );
}
