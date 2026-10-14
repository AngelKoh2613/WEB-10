import 'package:secureplan_mobile/features/agenda/domain/agenda_event.dart';

const _dayMs = 86400000;
const _maxSpanMs = 366 * _dayMs;

class SeriesException {
  const SeriesException({
    required this.originalStart,
    required this.excluded,
    this.startsAt,
    this.endsAt,
    this.title,
    this.description,
    this.category,
    this.priority,
  });

  final DateTime originalStart;
  final bool excluded;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final String? title;
  final String? description;
  final String? category;
  final String? priority;
}

DateTime _civilShift(DateTime instant, int offsetMinutes) {
  return instant.toUtc().add(Duration(minutes: offsetMinutes));
}

DateTime? _instantFromCivil({
  required int year,
  required int month,
  required int day,
  required int hour,
  required int minute,
  required int second,
  required int millisecond,
  required int offsetMinutes,
}) {
  final utc = DateTime.utc(year, month, day, hour, minute, second, millisecond);
  if (utc.year != year || utc.month != month || utc.day != day) {
    return null;
  }
  return utc.subtract(Duration(minutes: offsetMinutes));
}

({int year, int month}) _addMonths(int year, int month, int delta) {
  final index = year * 12 + (month - 1) + delta;
  return (year: index ~/ 12, month: index % 12 + 1);
}

int _weekIndex(int year, int month, int day) {
  final utc = DateTime.utc(year, month, day);
  final dayNumber = utc.millisecondsSinceEpoch ~/ _dayMs;
  final weekday = utc.weekday % 7;
  return (dayNumber - weekday) ~/ 7;
}

List<DateTime> seriesStarts(DateTime startsAt, EventRecurrence rule) {
  final shifted = _civilShift(startsAt, rule.offsetMinutes);
  final horizon = startsAt.toUtc().millisecondsSinceEpoch + _maxSpanMs;
  final starts = <DateTime>[];
  var stop = false;

  bool done(DateTime occurrence) {
    final millis = occurrence.toUtc().millisecondsSinceEpoch;
    if (millis > horizon) {
      return true;
    }
    if (rule.until != null &&
        millis > rule.until!.toUtc().millisecondsSinceEpoch) {
      return true;
    }
    starts.add(occurrence);
    return rule.count != null && starts.length >= rule.count!;
  }

  if (rule.frequency == 'daily') {
    for (var step = 0; step < 400 && !stop; step += 1) {
      final cursor = DateTime.utc(
        shifted.year,
        shifted.month,
        shifted.day,
      ).add(Duration(days: step * rule.interval));
      final occurrence = _instantFromCivil(
        year: cursor.year,
        month: cursor.month,
        day: cursor.day,
        hour: shifted.hour,
        minute: shifted.minute,
        second: shifted.second,
        millisecond: shifted.millisecond,
        offsetMinutes: rule.offsetMinutes,
      );
      if (occurrence == null || done(occurrence)) {
        stop = true;
      }
    }
  }

  if (rule.frequency == 'weekly') {
    final startWeek = _weekIndex(shifted.year, shifted.month, shifted.day);
    for (var offset = 0; offset <= 366 && !stop; offset += 1) {
      final cursor = DateTime.utc(
        shifted.year,
        shifted.month,
        shifted.day,
      ).add(Duration(days: offset));
      if (!rule.weekdays.contains(cursor.weekday % 7)) {
        continue;
      }
      if ((_weekIndex(cursor.year, cursor.month, cursor.day) - startWeek) %
              rule.interval !=
          0) {
        continue;
      }
      final occurrence = _instantFromCivil(
        year: cursor.year,
        month: cursor.month,
        day: cursor.day,
        hour: shifted.hour,
        minute: shifted.minute,
        second: shifted.second,
        millisecond: shifted.millisecond,
        offsetMinutes: rule.offsetMinutes,
      );
      if (occurrence == null || done(occurrence)) {
        stop = true;
      }
    }
  }

  if (rule.frequency == 'monthly') {
    for (var step = 0; step < 400 && !stop; step += 1) {
      final next = _addMonths(shifted.year, shifted.month, step * rule.interval);
      final occurrence = _instantFromCivil(
        year: next.year,
        month: next.month,
        day: shifted.day,
        hour: shifted.hour,
        minute: shifted.minute,
        second: shifted.second,
        millisecond: shifted.millisecond,
        offsetMinutes: rule.offsetMinutes,
      );
      if (occurrence == null) {
        final probe = _instantFromCivil(
          year: next.year,
          month: next.month,
          day: 1,
          hour: shifted.hour,
          minute: shifted.minute,
          second: shifted.second,
          millisecond: shifted.millisecond,
          offsetMinutes: rule.offsetMinutes,
        );
        if (probe == null ||
            probe.millisecondsSinceEpoch > horizon ||
            (rule.until != null &&
                probe.millisecondsSinceEpoch >
                    rule.until!.toUtc().millisecondsSinceEpoch)) {
          stop = true;
        }
        continue;
      }
      if (done(occurrence)) {
        stop = true;
      }
    }
  }

  return starts;
}

List<AgendaEvent> expandEvent({
  required AgendaEvent series,
  required List<SeriesException> exceptions,
  required DateTime rangeStart,
  required DateTime rangeEnd,
}) {
  final originals = series.recurrence == null
      ? [series.startsAt]
      : seriesStarts(series.startsAt, series.recurrence!);
  final duration = series.endsAt?.difference(series.startsAt);
  final byOriginal = {
    for (final item in exceptions) item.originalStart.toUtc().millisecondsSinceEpoch: item,
  };
  final visible = <AgendaEvent>[];
  for (final original in originals) {
    final exception = byOriginal[original.toUtc().millisecondsSinceEpoch];
    if (exception?.excluded == true) {
      continue;
    }
    final startsAt = exception?.startsAt ?? original;
    final endsAt = exception != null
        ? exception.endsAt
        : duration == null
        ? null
        : original.add(duration);
    final overlaps = endsAt == null
        ? !startsAt.isBefore(rangeStart) && startsAt.isBefore(rangeEnd)
        : startsAt.isBefore(rangeEnd) && endsAt.isAfter(rangeStart);
    if (!overlaps) {
      continue;
    }
    visible.add(
      AgendaEvent(
        id: series.id,
        title: exception?.title ?? series.title,
        description: exception != null ? exception.description : series.description,
        startsAt: startsAt,
        endsAt: endsAt,
        category: exception?.category ?? series.category,
        priority: exception?.priority ?? series.priority,
        createdAt: series.createdAt,
        updatedAt: series.updatedAt,
        occurrenceStart: original,
        recurrence: series.recurrence,
        version: series.version,
        reminderMinutes: series.reminderMinutes,
        syncStatus: series.syncStatus,
      ),
    );
  }
  return visible;
}
