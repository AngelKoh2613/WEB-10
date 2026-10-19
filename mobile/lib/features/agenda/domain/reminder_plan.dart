import 'package:secureplan_mobile/features/agenda/domain/agenda_event.dart';

class PlannedReminder {
  const PlannedReminder({
    required this.id,
    required this.title,
    required this.when,
  });

  final int id;
  final String title;
  final DateTime when;
}

abstract interface class ReminderScheduler {
  void replace(List<PlannedReminder> reminders);
}

const reminderChoices = <int?>[null, 5, 15, 60, 1440];

const reminderLabels = <int?, String>{
  null: 'Sin recordatorio',
  5: '5 minutos antes',
  15: '15 minutos antes',
  60: '1 hora antes',
  1440: '1 día antes',
};

List<PlannedReminder> planReminders({
  required List<AgendaEvent> events,
  required DateTime now,
  int horizonDays = 14,
  int limit = 20,
}) {
  final until = now.add(Duration(days: horizonDays));
  final planned = <PlannedReminder>[];
  final seen = <int>{};
  for (final event in events) {
    final minutes = event.reminderMinutes;
    if (minutes == null || event.syncStatus == 'hidden') {
      continue;
    }
    final when = event.startsAt.subtract(Duration(minutes: minutes));
    if (!when.isAfter(now) || !event.startsAt.isBefore(until)) {
      continue;
    }
    final id = reminderId(event.id, event.occurrenceKey);
    if (!seen.add(id)) {
      continue;
    }
    planned.add(PlannedReminder(id: id, title: event.title, when: when));
    if (planned.length >= limit) {
      break;
    }
  }
  return planned;
}

int reminderId(String eventId, DateTime occurrence) {
  final raw = Object.hash(eventId, occurrence.toUtc().millisecondsSinceEpoch);
  return raw & 0x7fffffff;
}

List<PlannedReminder> gateReminders({
  required bool permissionGranted,
  required List<PlannedReminder> reminders,
}) {
  if (!permissionGranted) {
    return const [];
  }
  return reminders;
}
