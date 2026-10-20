import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:secureplan_mobile/features/agenda/data/encrypted_database.dart';
import 'package:secureplan_mobile/features/agenda/data/event_api.dart';
import 'package:secureplan_mobile/features/agenda/data/local_agenda.dart';
import 'package:secureplan_mobile/features/agenda/data/local_database.dart';
import 'package:secureplan_mobile/features/agenda/domain/agenda_event.dart';
import 'package:secureplan_mobile/features/agenda/domain/agenda_observer.dart';
import 'package:secureplan_mobile/features/agenda/domain/reminder_plan.dart';
import 'package:secureplan_mobile/features/auth/domain/access_token.dart';

const _keyA = '00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff';
const _keyB = 'ffeeddccbbaa99887766554433221100ffeeddccbbaa99887766554433221100';

void main() {
  test('keeps the database encrypted and closed on a wrong key', () async {
    final file = File(
      '${Directory.systemTemp.path}${Platform.pathSeparator}secureplan-cipher-${DateTime.now().microsecondsSinceEpoch}.sqlite',
    );
    final database = openEncryptedDatabase(file, _keyA);
    await database.into(database.outboxItems).insert(
      OutboxItemsCompanion.insert(
        userId: 'user-a',
        operation: 'create',
        entityId: 'event-1',
        payload: '{"id":"event-1"}',
        status: 'pending',
        createdAt: DateTime.utc(2026, 10, 13),
      ),
    );
    await database.into(database.storedEvents).insert(
      StoredEventsCompanion.insert(
        id: 'event-1',
        userId: 'user-a',
        title: 'Secreto de prueba',
        startsAt: DateTime.utc(2026, 10, 13, 15),
        category: 'estudio',
        priority: 'high',
        version: 1,
        syncStatus: 'synced',
        updatedAt: DateTime.utc(2026, 10, 13),
      ),
    );
    await database.close();

    final stored = utf8.decode(await file.readAsBytes(), allowMalformed: true);
    expect(stored.contains('Secreto de prueba'), isFalse);
    expect(stored.contains(_keyA), isFalse);

    final wrong = openEncryptedDatabase(file, _keyB);
    await expectLater(wrong.select(wrong.storedEvents).get(), throwsA(isA<Object>()));
    expect(file.existsSync(), isTrue);
    await wrong.close();

    final again = openEncryptedDatabase(file, _keyA);
    final rows = await again.select(again.storedEvents).get();
    final pending = await again.select(again.outboxItems).get();
    expect(rows.single.title, 'Secreto de prueba');
    expect(pending.single.status, 'pending');
    await again.close();
    file.deleteSync();
  });

  test('creates offline, syncs once, and isolates users', () async {
    final file = File(
      '${Directory.systemTemp.path}${Platform.pathSeparator}secureplan-sync-${DateTime.now().microsecondsSinceEpoch}.sqlite',
    );
    final remote = _FakeRemote();
    final hub = AgendaChangeHub();
    final observer = _RecordingObserver();
    hub.watch(observer);

    LocalDatabase? cached;
    Future<LocalDatabase> open(String userId) async {
      return cached ??= openEncryptedDatabase(file, _keyA);
    }

    final agenda = LocalAgenda(remote: remote, openDatabase: open, hub: hub);
    remote.offline = true;
    final created = await agenda.create(_token('user-a'), _draft('Entrega'));
    expect(created.syncStatus, 'pending');
    expect(remote.creates, 0);
    expect(observer.calls, 1);

    final reopened = LocalAgenda(remote: remote, openDatabase: open, hub: hub);
    remote.offline = false;
    final synced = await reopened.list(
      _token('user-a'),
      from: DateTime.utc(2026, 10, 1),
      to: DateTime.utc(2026, 11, 1),
    );
    expect(synced.single.syncStatus, 'synced');
    expect(remote.creates, 1);

    await reopened.list(
      _token('user-a'),
      from: DateTime.utc(2026, 10, 1),
      to: DateTime.utc(2026, 11, 1),
    );
    expect(remote.creates, 1);
    expect(remote.eventsByUser['user-b'] ?? const [], isEmpty);
    final otherUser = await reopened.list(
      _token('user-b'),
      from: DateTime.utc(2026, 10, 1),
      to: DateTime.utc(2026, 11, 1),
    );
    expect(otherUser, isEmpty);
    final stored = await cached!.select(cached!.storedEvents).get();
    expect(stored.map((row) => row.userId).toSet(), {'user-a'});
    await cached?.close();
    try {
      if (file.existsSync()) {
        file.deleteSync();
      }
    } on FileSystemException {
      // Windows can keep the encrypted file open until the process releases it.
    }
  });

  test('keeps a conflict instead of overwriting the local change', () async {
    final file = File(
      '${Directory.systemTemp.path}${Platform.pathSeparator}secureplan-conflict-${DateTime.now().microsecondsSinceEpoch}.sqlite',
    );
    final remote = _FakeRemote();
    LocalDatabase? cached;
    final agenda = LocalAgenda(
      remote: remote,
      openDatabase: (userId) async => cached ??= openEncryptedDatabase(file, _keyA),
      hub: AgendaChangeHub(),
    );
    final created = await agenda.create(_token('user-a'), _draft('Original'));
    remote.events[created.id] = remote.events[created.id]!.copy(title: 'Servidor', version: 2);
    await agenda.update(
      _token('user-a'),
      created.id,
      _draft('Local', baseVersion: 1),
    );
    final visible = await agenda.list(
      _token('user-a'),
      from: DateTime.utc(2026, 10, 1),
      to: DateTime.utc(2026, 11, 1),
    );

    expect(visible.single.title, 'Local');
    expect(visible.single.syncStatus, 'conflict');
    await cached?.close();
    try {
      file.deleteSync();
    } on FileSystemException {
      // The assertion above is the behavior under test.
    }
  });
}

EventDraft _draft(String title, {int? baseVersion}) {
  return EventDraft(
    title: title,
    description: null,
    startsAt: DateTime.utc(2026, 10, 13, 15),
    endsAt: DateTime.utc(2026, 10, 13, 16),
    category: 'estudio',
    priority: 'high',
    baseVersion: baseVersion,
    reminderMinutes: 15,
  );
}

String _token(String userId) {
  final header = base64Url.encode(utf8.encode('{"alg":"none"}')).replaceAll('=', '');
  final payload = base64Url
      .encode(utf8.encode('{"sub":"$userId","exp":9999999999}'))
      .replaceAll('=', '');
  return '$header.$payload.sig';
}

class _RecordingObserver implements AgendaObserver {
  var calls = 0;

  @override
  void onAgendaChanged(AgendaChange change) {
    calls += 1;
    expect(change.reminders, isA<List<PlannedReminder>>());
  }
}

class _FakeRemote implements AgendaRemote {
  final events = <String, AgendaEvent>{};
  final owners = <String, String>{};
  var creates = 0;
  var offline = false;

  Map<String, List<AgendaEvent>> get eventsByUser {
    final grouped = <String, List<AgendaEvent>>{};
    for (final entry in owners.entries) {
      grouped.putIfAbsent(entry.value, () => []).add(events[entry.key]!);
    }
    return grouped;
  }

  @override
  Future<AgendaEvent> create(String accessToken, EventDraft draft) async {
    if (offline) {
      throw const AgendaNetworkFailure();
    }
    final userId = subjectOf(accessToken)!;
    creates += 1;
    final existing = events[draft.clientId];
    if (existing != null && owners[existing.id] == userId) {
      return existing;
    }
    final event = AgendaEvent(
      id: draft.clientId!,
      title: draft.title,
      description: draft.description,
      startsAt: draft.startsAt,
      endsAt: draft.endsAt,
      category: draft.category,
      priority: draft.priority,
      createdAt: DateTime.utc(2026, 10, 13),
      updatedAt: DateTime.utc(2026, 10, 13),
      version: 1,
      reminderMinutes: draft.reminderMinutes,
    );
    events[event.id] = event;
    owners[event.id] = userId;
    return event;
  }

  @override
  Future<AgendaEvent> update(String accessToken, String id, EventDraft draft) async {
    if (offline) {
      throw const AgendaNetworkFailure();
    }
    final current = events[id];
    if (current == null || owners[id] != subjectOf(accessToken)) {
      throw const AgendaNotFoundFailure();
    }
    if (draft.baseVersion != current.version) {
      throw AgendaConflictFailure(server: current);
    }
    final saved = current.copy(title: draft.title, version: current.version + 1);
    events[id] = saved;
    return saved;
  }

  @override
  Future<void> delete(
    String accessToken,
    String id, {
    String? scope,
    DateTime? occurrenceStart,
    int? baseVersion,
  }) async {
    events.remove(id);
    owners.remove(id);
  }

  @override
  Future<List<AgendaEvent>> list(
    String accessToken, {
    required DateTime from,
    required DateTime to,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Map<String, dynamic>> pull(String accessToken) async {
    if (offline) {
      throw const AgendaNetworkFailure();
    }
    final userId = subjectOf(accessToken);
    return {
      'events': [
        for (final event in events.values)
          if (owners[event.id] == userId) publicFields(event),
      ],
      'exceptions': const [],
      'tombstones': const [],
    };
  }
}

extension on AgendaEvent {
  AgendaEvent copy({String? title, int? version}) {
    return AgendaEvent(
      id: id,
      title: title ?? this.title,
      description: description,
      startsAt: startsAt,
      endsAt: endsAt,
      category: category,
      priority: priority,
      createdAt: createdAt,
      updatedAt: updatedAt,
      version: version ?? this.version,
      reminderMinutes: reminderMinutes,
      syncStatus: syncStatus,
    );
  }
}
