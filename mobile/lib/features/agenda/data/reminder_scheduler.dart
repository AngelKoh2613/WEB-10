import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:secureplan_mobile/features/agenda/domain/reminder_plan.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

class PluginReminderScheduler implements ReminderScheduler {
  PluginReminderScheduler({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  var _ready = false;
  var _granted = false;

  @override
  void replace(List<PlannedReminder> reminders) {
    unawaited(_replace(reminders));
  }

  Future<void> _replace(List<PlannedReminder> reminders) async {
    try {
      if (!_ready) {
        timezone_data.initializeTimeZones();
        await _plugin.initialize(
          settings: const InitializationSettings(
            android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          ),
        );
        final android = _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        _granted = await android?.requestNotificationsPermission() ?? false;
        _ready = true;
      }
      final allowed = gateReminders(
        permissionGranted: _granted,
        reminders: reminders,
      );
      await _plugin.cancelAll();
      for (final reminder in allowed) {
        await _plugin.zonedSchedule(
          id: reminder.id,
          title: 'SecurePlan',
          body: reminder.title,
          scheduledDate: timezone.TZDateTime.from(
            reminder.when.toLocal(),
            timezone.local,
          ),
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'agenda',
              'Agenda',
              channelDescription: 'Recordatorios de eventos',
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    } catch (_) {
      _granted = false;
    }
  }
}
