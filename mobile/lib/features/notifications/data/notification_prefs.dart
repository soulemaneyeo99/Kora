import 'package:shared_preferences/shared_preferences.dart';

/// Preferences notifications persistees localement.
///
/// Pas de SecureStorage : ce sont des reglages utilisateur, non sensibles.
/// L'absence de valeur stockee = comportement par defaut (notifs activees a 9h).
class NotificationPrefs {
  static const _kEnabled = 'notif.enabled';
  static const _kHour = 'notif.hour';
  static const _kMinute = 'notif.minute';
  static const _kDeviceId = 'notif.device_id';

  static const defaultHour = 9;
  static const defaultMinute = 0;

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kEnabled) ?? true;
  }

  Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabled, value);
  }

  Future<({int hour, int minute})> dailyTipTime() async {
    final prefs = await SharedPreferences.getInstance();
    return (
      hour: prefs.getInt(_kHour) ?? defaultHour,
      minute: prefs.getInt(_kMinute) ?? defaultMinute,
    );
  }

  Future<void> setDailyTipTime({required int hour, required int minute}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kHour, hour);
    await prefs.setInt(_kMinute, minute);
  }

  /// Identifiant device stable (UUID v4-like) genere a la premiere ouverture.
  /// Utilise comme "push token" tant que FCM n'est pas branche : permet au
  /// backend de stocker une ligne par device meme sans token FCM reel.
  Future<String> deviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_kDeviceId);
    if (existing != null && existing.isNotEmpty) return existing;
    final id = _generateId();
    await prefs.setString(_kDeviceId, id);
    return id;
  }

  String _generateId() {
    // UUID v4 simplifie sans dependance externe.
    final now = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    final rand = (DateTime.now().millisecond * 7919).toRadixString(16);
    return 'local-$now-$rand';
  }
}
