import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'features/notifications/application/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Données de localisation pour le formatage des dates en français.
  await initializeDateFormatting('fr');

  final container = ProviderContainer();
  // Init notifications locales sans bloquer le lancement.
  // Le hook de session se chargera de programmer le rappel quand auth.
  await container.read(notificationServiceProvider).init();

  runApp(UncontrolledProviderScope(
    container: container,
    child: const KoraApp(),
  ));
}
