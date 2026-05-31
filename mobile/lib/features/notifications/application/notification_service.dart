import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../insights/data/insights_repository.dart';
import '../data/notification_prefs.dart';

/// Service notifications LOCALES (pas de Firebase requis).
///
/// Responsabilites :
///   - init du plugin + demande de permission (Android 13+ / iOS)
///   - programmer le conseil du jour quotidien
///   - annuler / reprogrammer si l'user change l'heure ou desactive
class NotificationService {
  NotificationService({
    required FlutterLocalNotificationsPlugin plugin,
    required NotificationPrefs prefs,
    required InsightsRepository insights,
  })  : _plugin = plugin,
        _prefs = prefs,
        _insights = insights;

  final FlutterLocalNotificationsPlugin _plugin;
  final NotificationPrefs _prefs;
  final InsightsRepository _insights;

  static const _dailyTipId = 1001;
  static const _channelId = 'kora_daily_tips';
  static const _channelName = 'Conseils du jour';
  static const _channelDescription =
      'Une astuce KORA chaque matin pour mieux gerer ton argent.';

  bool _initialized = false;

  /// A appeler une seule fois au demarrage de l'app (idempotent).
  Future<void> init() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );

    // Cree le canal Android explicitement pour controler l'importance.
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.high,
      ),
    );

    _initialized = true;
  }

  /// Demande la permission notifications (Android 13+ ou iOS).
  /// Retourne true si l'user a accepte (ou si pas necessaire).
  Future<bool> requestPermissionIfNeeded() async {
    if (kIsWeb) return false;
    if (Platform.isIOS) {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      final granted = await ios?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
      return granted;
    }
    if (Platform.isAndroid) {
      // Android 13+ : POST_NOTIFICATIONS runtime permission.
      final status = await Permission.notification.request();
      return status.isGranted;
    }
    return true;
  }

  /// Reprogramme la notif quotidienne selon les prefs (ou annule si OFF).
  ///
  /// Appele :
  ///   - apres init au demarrage
  ///   - apres changement de prefs (toggle ou heure)
  ///   - apres login (pour utiliser le conseil personnalise du user)
  Future<void> rescheduleDailyTip() async {
    await _plugin.cancel(_dailyTipId);
    if (!await _prefs.isEnabled()) return;

    final time = await _prefs.dailyTipTime();
    final next = _nextDailyOccurrence(hour: time.hour, minute: time.minute);

    // Recupere le conseil du jour pour afficher un texte plus riche que
    // "ouvre KORA". Si l'API echoue, on tombe sur un message generique mais
    // on programme quand meme la notif (utile hors-ligne).
    String title = 'Ton conseil KORA';
    String body = 'Ouvre l\'app pour decouvrir le conseil du jour.';
    try {
      final tip = await _insights.fetchDailyTip();
      title = '💡 ${tip.title}';
      body = tip.body;
    } catch (_) {
      // pas reseau / pas authentifie -> message fallback.
    }

    await _plugin.zonedSchedule(
      _dailyTipId,
      title,
      body,
      next,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// Annule tous les rappels KORA (logout).
  Future<void> cancelAll() => _plugin.cancelAll();

  /// Push immediat pour tester la chaine en local.
  Future<void> showImmediateTest({
    String title = '🎉 KORA — Notifications OK',
    String body = 'Les notifications locales fonctionnent.',
  }) async {
    await _plugin.show(
      9999,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  /// Calcule la prochaine occurrence de hh:mm dans la timezone locale.
  /// Si l'heure est deja passee aujourd'hui -> demain.
  tz.TZDateTime _nextDailyOccurrence({
    required int hour,
    required int minute,
  }) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}

/// Plugin singleton.
final flutterLocalNotificationsProvider =
    Provider<FlutterLocalNotificationsPlugin>(
  (ref) => FlutterLocalNotificationsPlugin(),
);

final notificationPrefsProvider =
    Provider<NotificationPrefs>((ref) => NotificationPrefs());

final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService(
    plugin: ref.watch(flutterLocalNotificationsProvider),
    prefs: ref.watch(notificationPrefsProvider),
    insights: ref.watch(insightsRepositoryProvider),
  ),
);
