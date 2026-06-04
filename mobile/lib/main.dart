import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'features/notifications/application/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Donnees de localisation pour le formatage des dates en francais.
  await initializeDateFormatting('fr');

  final container = ProviderContainer();

  // IMPORTANT: l'init du plugin notifications NE DOIT JAMAIS bloquer le
  // lancement. Sur certains telephones, l'init du canal Android ou du
  // permission_handler peut hanger plusieurs minutes. On le lance en
  // background avec un timeout court.
  unawaited(
    container
        .read(notificationServiceProvider)
        .init()
        .timeout(const Duration(seconds: 8))
        .catchError((_) {}),
  );

  runApp(UncontrolledProviderScope(
    container: container,
    child: const KoraApp(),
  ));
}
