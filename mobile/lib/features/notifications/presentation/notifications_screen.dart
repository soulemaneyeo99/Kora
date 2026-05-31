import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/kora_colors.dart';
import '../../../core/theme/kora_spacing.dart';
import '../../../core/theme/kora_typography.dart';
import '../application/notification_service.dart';
import '../data/notification_prefs.dart';

/// Reglages notifications : ON/OFF + heure du conseil + bouton test.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  bool? _enabled;
  int _hour = NotificationPrefs.defaultHour;
  int _minute = NotificationPrefs.defaultMinute;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = ref.read(notificationPrefsProvider);
    final enabled = await prefs.isEnabled();
    final time = await prefs.dailyTipTime();
    if (!mounted) return;
    setState(() {
      _enabled = enabled;
      _hour = time.hour;
      _minute = time.minute;
    });
  }

  Future<void> _toggle(bool value) async {
    setState(() {
      _enabled = value;
      _saving = true;
    });
    final prefs = ref.read(notificationPrefsProvider);
    final svc = ref.read(notificationServiceProvider);
    await prefs.setEnabled(value);
    if (value) {
      await svc.requestPermissionIfNeeded();
      await svc.rescheduleDailyTip();
    } else {
      await svc.cancelAll();
    }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _hour, minute: _minute),
    );
    if (picked == null) return;
    setState(() {
      _hour = picked.hour;
      _minute = picked.minute;
      _saving = true;
    });
    final prefs = ref.read(notificationPrefsProvider);
    await prefs.setDailyTipTime(hour: picked.hour, minute: picked.minute);
    if (_enabled == true) {
      await ref.read(notificationServiceProvider).rescheduleDailyTip();
    }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _sendTest() async {
    await ref.read(notificationServiceProvider).showImmediateTest();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Notification de test envoyée.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final enabled = _enabled;
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: enabled == null
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(KoraSpacing.pagePadding),
                children: [
                  Card(
                    child: SwitchListTile(
                      value: enabled,
                      onChanged: _saving ? null : _toggle,
                      title: Text('Conseil du jour', style: KoraType.cardLabel()),
                      subtitle: Text(
                        'Un rappel quotidien pour mieux gérer ton argent.',
                        style: KoraType.caption(),
                      ),
                      activeThumbColor: KoraColors.greenPrimary,
                    ),
                  ),
                  const SizedBox(height: KoraSpacing.sm),
                  Card(
                    child: ListTile(
                      enabled: enabled && !_saving,
                      leading: const Icon(Icons.schedule_rounded,
                          color: KoraColors.greenPrimary),
                      title: Text('Heure du rappel', style: KoraType.cardLabel()),
                      subtitle: Text(
                        '${_hour.toString().padLeft(2, '0')}:${_minute.toString().padLeft(2, '0')}',
                        style: KoraType.caption(),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded,
                          color: KoraColors.gray),
                      onTap: _pickTime,
                    ),
                  ),
                  const SizedBox(height: KoraSpacing.lg),
                  OutlinedButton.icon(
                    onPressed: _saving ? null : _sendTest,
                    icon: const Icon(Icons.notifications_active_outlined),
                    label: const Text('Envoyer un test maintenant'),
                  ),
                  const SizedBox(height: KoraSpacing.lg),
                  Text(
                    'Les notifications fonctionnent même hors connexion. '
                    'Tu peux les couper à tout moment.',
                    style: KoraType.caption(color: KoraColors.gray),
                  ),
                ],
              ),
            ),
    );
  }
}
