import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:secureplan_mobile/features/agenda/domain/agenda_event.dart';
import 'package:secureplan_mobile/features/agenda/domain/agenda_observer.dart';
import 'package:secureplan_mobile/features/agenda/domain/export_strategy.dart';
import 'package:secureplan_mobile/features/agenda/domain/recurrence_expand.dart';
import 'package:secureplan_mobile/features/agenda/domain/reminder_plan.dart';
import 'package:secureplan_mobile/features/agenda/domain/sync_policy.dart';

void main() {
  test('skips short months and keeps the monthly day', () {
    final starts = seriesStarts(
      DateTime.utc(2024, 1, 31, 15),
      const EventRecurrence(
        frequency: 'monthly',
        interval: 1,
        weekdays: [],
        until: null,
        count: 4,
        offsetMinutes: 0,
      ),
    );

    expect(starts, [
      DateTime.utc(2024, 1, 31, 15),
      DateTime.utc(2024, 3, 31, 15),
      DateTime.utc(2024, 5, 31, 15),
      DateTime.utc(2024, 7, 31, 15),
    ]);
  });

  test('exports json and escaped csv without secrets', () {
    final event = AgendaEvent(
      id: 'event-1',
      title: 'Revisión, "final"',
      description: 'Línea 1\nLínea 2',
      startsAt: DateTime.utc(2026, 10, 13, 15),
      endsAt: null,
      category: 'estudio',
      priority: 'high',
      createdAt: DateTime.utc(2026, 10, 1),
      updatedAt: DateTime.utc(2026, 10, 1),
      reminderMinutes: 15,
    );

    final jsonText = utf8.decode(const JsonEventExporter().export([event]));
    final document = jsonDecode(jsonText) as Map<String, dynamic>;
    expect(document['format'], 'secureplan-events');
    expect(jsonText.contains('accessToken'), isFalse);
    expect(jsonText.contains('password'), isFalse);

    final csv = utf8.decode(const CsvEventExporter().export([event]));
    expect(csv.startsWith('id,title,'), isTrue);
    expect(csv.contains('"Revisión, ""final"""'), isTrue);
    expect(csv.contains('"Línea 1\nLínea 2"'), isTrue);

    final formula = utf8.decode(
      const CsvEventExporter().export([
        AgendaEvent(
          id: 'event-2',
          title: '=1+1',
          description: null,
          startsAt: DateTime.utc(2026, 10, 13, 15),
          endsAt: null,
          category: 'estudio',
          priority: 'high',
          createdAt: DateTime.utc(2026, 10, 1),
          updatedAt: DateTime.utc(2026, 10, 1),
        ),
      ]),
    );
    expect(formula.contains(",'=1+1,"), isTrue);
    expect(utf8.decode(const CsvEventExporter().export(const [])).trim(), 'id,title,description,startsAt,endsAt,category,priority,occurrenceStart,frequency,interval,reminderMinutes');
  });

  test('reports a write failure and does not claim success', () async {
    expect(
      writeExport(
        strategy: const JsonEventExporter(),
        events: const [],
        write: (bytes, fileName) async => throw StateError('disk'),
      ),
      throwsA(isA<ExportWriteFailure>()),
    );
  });

  test('notifies observers and stops after they are removed', () {
    final hub = AgendaChangeHub();
    final scheduler = _RecordingScheduler();
    final observer = ReminderObserver(scheduler);
    const change = AgendaChange(userId: 'user-a', reminders: []);
    hub.watch(observer);
    hub.notify(change);
    hub.unwatch(observer);
    hub.notify(change);

    expect(scheduler.calls, 1);
  });

  test('plans one reminder and skips duplicates and denied permission', () {
    final event = AgendaEvent(
      id: 'event-1',
      title: 'Entrega',
      description: null,
      startsAt: DateTime.utc(2026, 10, 14, 15),
      endsAt: null,
      category: 'estudio',
      priority: 'high',
      createdAt: DateTime.utc(2026, 10, 1),
      updatedAt: DateTime.utc(2026, 10, 1),
      occurrenceStart: DateTime.utc(2026, 10, 14, 15),
      reminderMinutes: 15,
    );
    final planned = planReminders(
      events: [event, event],
      now: DateTime.utc(2026, 10, 14, 14),
    );

    expect(planned, hasLength(1));
    expect(planned.single.when, DateTime.utc(2026, 10, 14, 14, 45));
    expect(gateReminders(permissionGranted: false, reminders: planned), isEmpty);
  });

  test('retries network failures a limited number of times', () {
    expect(
      decideSync(statusCode: null, networkError: true, attempts: 0).disposition,
      SyncDisposition.retry,
    );
    expect(
      decideSync(statusCode: 503, networkError: false, attempts: 4).disposition,
      SyncDisposition.failed,
    );
    expect(
      decideSync(statusCode: 409, networkError: false, attempts: 0).disposition,
      SyncDisposition.conflict,
    );
    expect(
      decideSync(statusCode: 201, networkError: false, attempts: 1).disposition,
      SyncDisposition.synced,
    );
  });
}

class _RecordingScheduler implements ReminderScheduler {
  var calls = 0;

  @override
  void replace(List<PlannedReminder> reminders) {
    calls += 1;
  }
}
