class EventRecurrence {
  const EventRecurrence({
    required this.frequency,
    required this.interval,
    required this.weekdays,
    required this.until,
    required this.count,
    required this.offsetMinutes,
  });

  final String frequency;
  final int interval;
  final List<int> weekdays;
  final DateTime? until;
  final int? count;
  final int offsetMinutes;
}

class AgendaEvent {
  const AgendaEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.startsAt,
    required this.endsAt,
    required this.category,
    required this.priority,
    required this.createdAt,
    required this.updatedAt,
    this.occurrenceStart,
    this.recurrence,
    this.version = 1,
    this.reminderMinutes = 15,
    this.syncStatus = 'synced',
  });

  final String id;
  final String title;
  final String? description;
  final DateTime startsAt;
  final DateTime? endsAt;
  final String category;
  final String priority;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? occurrenceStart;
  final EventRecurrence? recurrence;
  final int version;
  final int? reminderMinutes;
  final String syncStatus;

  DateTime get occurrenceKey => occurrenceStart ?? startsAt;

  bool get repeats => recurrence != null;

  DateTime get localDay {
    final local = startsAt.toLocal();
    return DateTime(local.year, local.month, local.day);
  }
}

class EventDraft {
  const EventDraft({
    required this.title,
    required this.description,
    required this.startsAt,
    required this.endsAt,
    required this.category,
    required this.priority,
    this.recurrence,
    this.clearRecurrence = false,
    this.scope,
    this.occurrenceStart,
    this.baseVersion,
    this.clientId,
    this.reminderMinutes = 15,
  });

  final String title;
  final String? description;
  final DateTime startsAt;
  final DateTime? endsAt;
  final String category;
  final String priority;
  final EventRecurrence? recurrence;
  final bool clearRecurrence;
  final String? scope;
  final DateTime? occurrenceStart;
  final int? baseVersion;
  final String? clientId;
  final int? reminderMinutes;
}

const syncStatusLabels = {
  'pending': 'Pendiente',
  'synced': 'Sincronizado',
  'conflict': 'Conflicto',
  'failed': 'No sincronizado',
};

const eventCategories = ['personal', 'trabajo', 'estudio', 'otro'];
const eventPriorities = ['low', 'medium', 'high'];

const categoryLabels = {
  'personal': 'Personal',
  'trabajo': 'Trabajo',
  'estudio': 'Estudio',
  'otro': 'Otro',
};

const priorityLabels = {'low': 'Baja', 'medium': 'Media', 'high': 'Alta'};

String? validateEventTitle(String? value) {
  final title = value?.trim() ?? '';
  if (title.isEmpty || title.length > 200) {
    return 'El título debe tener entre 1 y 200 caracteres';
  }
  return null;
}

String? validateEventDescription(String? value) {
  if ((value?.trim().length ?? 0) > 4000) {
    return 'La descripción es demasiado larga';
  }
  return null;
}

DateTime? parseEventDateTime(String date, String time) {
  final dateMatch = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$')
      .firstMatch(date.trim());
  final timeMatch = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(time.trim());
  if (dateMatch == null || timeMatch == null) {
    return null;
  }

  final year = int.parse(dateMatch.group(1)!);
  final month = int.parse(dateMatch.group(2)!);
  final day = int.parse(dateMatch.group(3)!);
  final hour = int.parse(timeMatch.group(1)!);
  final minute = int.parse(timeMatch.group(2)!);
  final parsed = DateTime(year, month, day, hour, minute);
  final valid =
      parsed.year == year &&
      parsed.month == month &&
      parsed.day == day &&
      parsed.hour == hour &&
      parsed.minute == minute;
  return valid ? parsed : null;
}

const weekdayLabels = {
  1: 'Lunes',
  2: 'Martes',
  3: 'Miércoles',
  4: 'Jueves',
  5: 'Viernes',
  6: 'Sábado',
  0: 'Domingo',
};

int weekdayIndex(DateTime value) {
  return value.weekday == DateTime.sunday ? 0 : value.weekday;
}

bool eventOverlapsDay(AgendaEvent event, DateTime day) {
  final dayStart = DateTime(day.year, day.month, day.day);
  final dayEnd = dayStart.add(const Duration(days: 1));
  final start = event.startsAt.toLocal();
  final end = event.endsAt?.toLocal();
  if (end == null) {
    return !start.isBefore(dayStart) && start.isBefore(dayEnd);
  }
  return start.isBefore(dayEnd) && end.isAfter(dayStart);
}

String? validateRecurrence({
  required String frequency,
  required DateTime startsAt,
  required int? interval,
  required Set<int> weekdays,
  required bool untilLimit,
  required int? count,
  required DateTime? until,
}) {
  if (frequency == 'none') {
    return null;
  }
  if (interval == null || interval < 1 || interval > 99) {
    return 'El intervalo de repetición no es válido';
  }
  if (frequency == 'weekly' && !weekdays.contains(weekdayIndex(startsAt))) {
    return 'Elige un día de la semana que coincida con el inicio';
  }
  if (!untilLimit) {
    if (count == null || count < 1 || count > 366) {
      return 'El número de repeticiones no es válido';
    }
    return null;
  }
  if (until == null || !until.isAfter(startsAt)) {
    return 'La fecha límite debe ser posterior al inicio';
  }
  if (until.isAfter(startsAt.add(const Duration(days: 366)))) {
    return 'La serie supera el máximo de un año';
  }
  return null;
}

String? validateEventInterval(DateTime startsAt, DateTime? endsAt) {
  if (endsAt != null && !endsAt.isAfter(startsAt)) {
    return 'La hora de fin debe ser posterior al inicio';
  }
  return null;
}

String formatEventDate(DateTime value) {
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}-$month-$day';
}

String formatEventTime(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
