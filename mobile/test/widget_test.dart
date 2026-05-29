// Tests Flutter — squelette minimal. Les vrais tests d'écran utiliseront
// ProviderScope.overrideWith(...) pour stubber le TokenStore et Dio.
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:kora/core/format/money.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr');
  });

  group('Money', () {
    // L'intl francais moderne utilise U+202F (NARROW NO-BREAK SPACE) comme
    // separateur de milliers, plus etroit que NBSP et resistant au retour
    // a la ligne entre 150 et 000.
    const narrowNbsp = ' ';

    test('format ajoute la devise FCFA', () {
      expect(Money.format(150000), '150${narrowNbsp}000 FCFA');
    });

    test('compact omet le suffixe FCFA', () {
      expect(Money.compact(150000), '150${narrowNbsp}000');
    });

    test('signed prefixe + pour un montant positif', () {
      expect(Money.signed(22500), '+22${narrowNbsp}500 FCFA');
    });

    test('signed prefixe - pour un montant negatif', () {
      expect(Money.signed(-8000), '-8${narrowNbsp}000 FCFA');
    });
  });
}
