import 'dart:convert';

import 'package:secureplan_mobile/features/agenda/domain/agenda_event.dart';

abstract interface class EventExportStrategy {
  String get extensionName;
  List<int> export(List<AgendaEvent> events);
}

class JsonEventExporter implements EventExportStrategy {
  const JsonEventExporter();

  @override
  String get extensionName => 'json';

  @override
  List<int> export(List<AgendaEvent> events) {
    final document = {
      'format': 'secureplan-events',
      'version': 1,
      'events': [for (final event in events) publicEventJson(event)],
    };
    return utf8.encode(const JsonEncoder.withIndent('  ').convert(document));
  }
}

class CsvEventExporter implements EventExportStrategy {
  const CsvEventExporter();

  static const columns = [
    'id',
    'title',
    'description',
    'startsAt',
    'endsAt',
    'category',
    'priority',
    'occurrenceStart',
    'frequency',
    'interval',
    'reminderMinutes',
  ];

  @override
  String get extensionName => 'csv';

  @override
  List<int> export(List<AgendaEvent> events) {
    final lines = <String>[
      columns.join(','),
      for (final event in events)
        [
          event.id,
          event.title,
          event.description ?? '',
          event.startsAt.toUtc().toIso8601String(),
          event.endsAt?.toUtc().toIso8601String() ?? '',
          event.category,
          event.priority,
          (event.occurrenceStart ?? event.startsAt).toUtc().toIso8601String(),
          event.recurrence?.frequency ?? '',
          event.recurrence?.interval.toString() ?? '',
          event.reminderMinutes?.toString() ?? '',
        ].map(csvField).join(','),
    ];
    return utf8.encode('${lines.join('\n')}\n');
  }
}

Map<String, Object?> publicEventJson(AgendaEvent event) {
  return {
    'id': event.id,
    'title': event.title,
    'description': event.description,
    'startsAt': event.startsAt.toUtc().toIso8601String(),
    'endsAt': event.endsAt?.toUtc().toIso8601String(),
    'category': event.category,
    'priority': event.priority,
    'occurrenceStart': (event.occurrenceStart ?? event.startsAt)
        .toUtc()
        .toIso8601String(),
    'reminderMinutes': event.reminderMinutes,
    'recurrence': event.recurrence == null
        ? null
        : {
            'frequency': event.recurrence!.frequency,
            'interval': event.recurrence!.interval,
            'weekdays': event.recurrence!.weekdays,
            'until': event.recurrence!.until?.toUtc().toIso8601String(),
            'count': event.recurrence!.count,
            'offsetMinutes': event.recurrence!.offsetMinutes,
          },
  };
}

String csvField(String value) {
  final neutral = RegExp(r'^[=+\-@\t\r]').hasMatch(value) ? "'$value" : value;
  if (neutral.contains('"') ||
      neutral.contains(',') ||
      neutral.contains('\n') ||
      neutral.contains('\r')) {
    return '"${neutral.replaceAll('"', '""')}"';
  }
  return neutral;
}

class ExportWriteFailure implements Exception {
  const ExportWriteFailure();
}

Future<void> writeExport({
  required EventExportStrategy strategy,
  required List<AgendaEvent> events,
  required Future<void> Function(List<int> bytes, String fileName) write,
}) async {
  final bytes = strategy.export(events);
  final fileName =
      'secureplan-eventos-${DateTime.now().toUtc().toIso8601String().substring(0, 10)}.${strategy.extensionName}';
  try {
    await write(bytes, fileName);
  } catch (_) {
    throw const ExportWriteFailure();
  }
}
