import 'package:intl/intl.dart';

/// Formatage des montants en FCFA (XOF) — espace comme séparateur de milliers,
/// pas de décimales (le backend stocke des entiers de francs).
///
/// Exemple : 150000 -> "150 000 FCFA".
class Money {
  Money._();

  static final NumberFormat _fmt = NumberFormat.decimalPattern('fr')
    ..maximumFractionDigits = 0;

  /// "150 000 FCFA"
  static String format(int amountXof) => '${_fmt.format(amountXof)} FCFA';

  /// "150 000" (sans suffixe, pour les gros chiffres du dashboard)
  static String compact(int amountXof) => _fmt.format(amountXof);

  /// Préfixe signé pour un flux net : "+22 500 FCFA" / "-8 000 FCFA".
  static String signed(int amountXof) {
    final sign = amountXof >= 0 ? '+' : '-';
    return '$sign${format(amountXof.abs())}';
  }
}
