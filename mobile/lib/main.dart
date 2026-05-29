import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Données de localisation pour le formatage des dates en français.
  await initializeDateFormatting('fr');
  runApp(const ProviderScope(child: KoraApp()));
}
