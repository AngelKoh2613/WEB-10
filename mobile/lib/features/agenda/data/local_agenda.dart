import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:secureplan_mobile/features/agenda/data/event_api.dart';
import 'package:secureplan_mobile/features/agenda/data/local_database.dart';
import 'package:secureplan_mobile/features/agenda/domain/agenda_event.dart';
import 'package:secureplan_mobile/features/agenda/domain/agenda_observer.dart';
import 'package:secureplan_mobile/features/agenda/domain/recurrence_expand.dart';
import 'package:secureplan_mobile/features/agenda/domain/reminder_plan.dart';
import 'package:secureplan_mobile/features/agenda/domain/sync_policy.dart';
import 'package:secureplan_mobile/features/auth/domain/access_token.dart';

class LocalAgenda implements EventApi {
  LocalAgenda({
    required this.remote,
    required this.openDatabase,
    required this.hub,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;

  final AgendaRemote remote;
  final Future<LocalDatabase> Function(String userId) openDatabase;
  final AgendaChangeHub hub;
  final DateTime Function() now;

  @override
  Future<List<AgendaEvent>> list(
    String accessToken, {
    required DateTime from,
    required DateTime to,
  }) async {
    final userId = _user(accessToken);
    final database = await openDatabase(userId);
    await _push(database, accessToken, userId);
    var pulled = false;
    try {
      await _pull(database, accessToken, userId);
      pulled = true;
    } on AgendaNetworkFailure {
      pulled = false;
    }
    final visible = await _visible(database, userId, from, to);
    if (!pulled && visible.isEmpty) {
      throw const AgendaNetworkFailure();
    }
    await _publish(database, userId);
    return visible;
  }

  @override
  Future<AgendaEvent> create(String accessToken, EventDraft draft) async {
    final userId = _user(accessToken);
    final database = await openDatabase(userId);
    final id = draft.clientId ?? _newId();
    final stored = _rowFromDraft(userId, id, draft, version: 0, status: 'pending');
    await database.into(database.storedEvents).insertOnConflictUpdate(stored);
    await _enqueue(
      database,
      userId: userId,
      operation: 'create',
      entityId: id,
      payload: _payload(draft, id),
    );
    await _push(database, accessToken, userId);
    await _publish(database, userId);
    final saved = await _require(database, id, userId);
    return _series(saved);
  }

  @override
  Future<AgendaEvent> update(
    String accessToken,
    String id,
    EventDraft draft,
  ) async {
    final userId = _user(accessToken);
    final database = await openDatabase(userId);
    final current = await _require(database, id, userId);
    if (draft.scope == 'occurrence') {
      await _saveException(database, current, draft, excluded: false);
    } else {
      await database.into(database.storedEvents).insertOnConflictUpdate(
        _rowFromDraft(
          userId,
          id,
          draft,
          version: current.version,
          status: 'pending',
          createdAt: current.updatedAt,
        ),
      );
      if (draft.scope == 'series' || draft.clearRecurrence) {
        await (database.delete(database.storedExceptions)
              ..where((row) => row.eventId.equals(id)))
            .go();
      }
    }
    await _enqueue(
      database,
      userId: userId,
      operation: current.version == 0 ? 'create' : 'update',
      entityId: id,
      payload: _payload(draft, id),
      baseVersion: current.version == 0 ? null : draft.baseVersion ?? current.version,
    );
    await _push(database, accessToken, userId);
    await _publish(database, userId);
    return _series(await _require(database, id, userId));
  }

  @override
  Future<void> delete(
    String accessToken,
    String id, {
    String? scope,
    DateTime? occurrenceStart,
    int? baseVersion,
  }) async {
    final userId = _user(accessToken);
    final database = await openDatabase(userId);
    final current = await _require(database, id, userId);
    if (current.version == 0) {
      await (database.delete(database.storedEvents)
            ..where((row) => row.id.equals(id) & row.userId.equals(userId)))
          .go();
      await _dropQueue(database, userId, id);
      await _publish(database, userId);
      return;
    }
    if (scope == 'occurrence' && occurrenceStart != null) {
      await _saveException(
        database,
        current,
        EventDraft(
          title: current.title,
          description: current.description,
          startsAt: occurrenceStart,
          endsAt: null,
          category: current.category,
          priority: current.priority,
          scope: 'occurrence',
          occurrenceStart: occurrenceStart,
        ),
        excluded: true,
      );
    } else {
      await (database.update(database.storedEvents)
            ..where((row) => row.id.equals(id) & row.userId.equals(userId)))
          .write(const StoredEventsCompanion(hidden: Value(true), syncStatus: Value('pending')));
    }
    await _enqueue(
      database,
      userId: userId,
      operation: 'delete',
      entityId: id,
      payload: jsonEncode({
        'scope': scope,
        'occurrenceStart': occurrenceStart?.toUtc().toIso8601String(),
      }),
      baseVersion: baseVersion ?? current.version,
    );
    await _push(database, accessToken, userId);
    await _publish(database, userId);
  }

  Future<void> keepServer(String accessToken, String id) async {
    final userId = _user(accessToken);
    final database = await openDatabase(userId);
    final current = await _require(database, id, userId);
    final snapshot = current.serverTitle;
    await _dropQueue(database, userId, id);
    if (snapshot == null) {
      await (database.delete(database.storedEvents)
            ..where((row) => row.id.equals(id) & row.userId.equals(userId)))
          .go();
    } else {
      final event = _eventFromJson(jsonDecode(snapshot));
      await database.into(database.storedEvents).insertOnConflictUpdate(
        _companionFromEvent(userId, event, status: 'synced'),
      );
    }
    await _publish(database, userId);
  }

  Future<void> keepMine(String accessToken, String id) async {
    final userId = _user(accessToken);
    final database = await openDatabase(userId);
    final current = await _require(database, id, userId);
    if (current.serverTitle == null) {
      final replacement = _newId();
      await (database.update(database.storedEvents)
            ..where((row) => row.id.equals(id) & row.userId.equals(userId)))
          .write(
            StoredEventsCompanion(
              id: Value(replacement),
              version: const Value(0),
              syncStatus: const Value('pending'),
              serverTitle: const Value(null),
            ),
          );
      await _dropQueue(database, userId, id);
      await _enqueue(
        database,
        userId: userId,
        operation: 'create',
        entityId: replacement,
        payload: _payload(_draftFromRow(current, clientId: replacement), replacement),
      );
    } else {
      final server = _eventFromJson(jsonDecode(current.serverTitle!));
      await _enqueue(
        database,
        userId: userId,
        operation: 'update',
        entityId: id,
        payload: _payload(_draftFromRow(current, baseVersion: server.version), id),
        baseVersion: server.version,
      );
    }
    await _push(database, accessToken, userId);
    await _publish(database, userId);
  }

  Future<void> _push(LocalDatabase database, String token, String userId) async {
    final pending = await (database.select(database.outboxItems)
          ..where((row) => row.userId.equals(userId) & row.status.equals('pending'))
          ..orderBy([(row) => OrderingTerm.asc(row.id)]))
        .get();
    for (final item in pending) {
      final decision = await _send(database, token, userId, item);
      if (decision == SyncDisposition.unauthenticated) {
        throw const AgendaUnauthenticated();
      }
    }
  }

  Future<SyncDisposition> _send(
    LocalDatabase database,
    String token,
    String userId,
    OutboxItem item,
  ) async {
    try {
      if (item.operation == 'create') {
        final row = await _find(database, item.entityId, userId);
        if (row == null) {
          await _removeItem(database, item.id);
          return SyncDisposition.synced;
        }
        final saved = await remote.create(token, _draftFromRow(row, clientId: row.id));
        await _markSynced(database, userId, row.id, saved);
        await _removeItem(database, item.id);
        return SyncDisposition.synced;
      }
      if (item.operation == 'update') {
        final row = await _find(database, item.entityId, userId);
        if (row == null) {
          await _removeItem(database, item.id);
          return SyncDisposition.synced;
        }
        final saved = await remote.update(
          token,
          row.id,
          _draftFromRow(row, baseVersion: item.baseVersion),
        );
        await _markSynced(database, userId, row.id, saved);
        await _removeItem(database, item.id);
        return SyncDisposition.synced;
      }
      final body = jsonDecode(item.payload);
      final scope = body is Map ? body['scope'] as String? : null;
      final occurrence = body is Map && body['occurrenceStart'] is String
          ? DateTime.parse(body['occurrenceStart'] as String)
          : null;
      await remote.delete(
        token,
        item.entityId,
        scope: scope,
        occurrenceStart: occurrence,
        baseVersion: item.baseVersion,
      );
      await (database.delete(database.storedEvents)
            ..where((row) => row.id.equals(item.entityId) & row.userId.equals(userId)))
          .go();
      await _removeItem(database, item.id);
      return SyncDisposition.synced;
    } on AgendaConflictFailure catch (error) {
      await (database.update(database.storedEvents)
            ..where((row) => row.id.equals(item.entityId) & row.userId.equals(userId)))
          .write(
            StoredEventsCompanion(
              syncStatus: const Value('conflict'),
              serverTitle: Value(
                error.server == null ? null : jsonEncode(publicFields(error.server!)),
              ),
            ),
          );
      await _updateItem(database, item, status: 'conflict', attempts: item.attempts + 1);
      return SyncDisposition.conflict;
    } on AgendaNetworkFailure {
      return _retry(database, item, network: true, statusCode: null);
    } on AgendaUnauthenticated {
      return SyncDisposition.unauthenticated;
    } on AgendaFailure {
      return _retry(database, item, network: false, statusCode: 400);
    }
  }

  Future<SyncDisposition> _retry(
    LocalDatabase database,
    OutboxItem item, {
    required bool network,
    required int? statusCode,
  }) async {
    final decision = decideSync(
      statusCode: statusCode,
      networkError: network,
      attempts: item.attempts,
    );
    await _updateItem(
      database,
      item,
      status: decision.disposition == SyncDisposition.retry ? 'pending' : 'failed',
      attempts: decision.attempts,
    );
    if (decision.disposition == SyncDisposition.failed) {
      await (database.update(database.storedEvents)
            ..where((row) => row.id.equals(item.entityId)))
          .write(const StoredEventsCompanion(syncStatus: Value('failed')));
    }
    return decision.disposition;
  }

  Future<void> _pull(LocalDatabase database, String token, String userId) async {
    final snapshot = await remote.pull(token);
    final events = snapshot['events'];
    final tombstones = snapshot['tombstones'];
    if (events is! List || tombstones is! List) {
      throw const AgendaUnexpectedFailure();
    }
    final pending = await (database.select(database.outboxItems)
          ..where((row) => row.userId.equals(userId) & row.status.isIn(['pending', 'conflict'])))
        .get();
    final blocked = pending.map((item) => item.entityId).toSet();
    for (final item in tombstones) {
      if (item is! Map || item['id'] is! String) {
        continue;
      }
      final id = item['id'] as String;
      if (blocked.contains(id)) {
        await (database.update(database.storedEvents)
              ..where((row) => row.id.equals(id) & row.userId.equals(userId)))
            .write(const StoredEventsCompanion(syncStatus: Value('conflict'), serverTitle: Value(null)));
        continue;
      }
      await (database.delete(database.storedEvents)
            ..where((row) => row.id.equals(id) & row.userId.equals(userId)))
          .go();
    }
    final seen = <String>{};
    for (final item in events) {
      if (item is! Map<String, dynamic>) {
        continue;
      }
      final event = _eventFromJson(item);
      seen.add(event.id);
      if (blocked.contains(event.id)) {
        continue;
      }
      await database.into(database.storedEvents).insertOnConflictUpdate(
        _companionFromEvent(userId, event, status: 'synced'),
      );
    }
    final local = await (database.select(database.storedEvents)
          ..where((row) => row.userId.equals(userId)))
        .get();
    for (final row in local) {
      if (!seen.contains(row.id) && !blocked.contains(row.id) && row.version != 0) {
        await (database.delete(database.storedEvents)..where((item) => item.id.equals(row.id))).go();
      }
    }
  }

  Future<List<AgendaEvent>> _visible(
    LocalDatabase database,
    String userId,
    DateTime from,
    DateTime to,
  ) async {
    final rows = await (database.select(database.storedEvents)
          ..where((row) => row.userId.equals(userId) & row.hidden.equals(false)))
        .get();
    final exceptions = await database.select(database.storedExceptions).get();
    final visible = <AgendaEvent>[];
    for (final row in rows) {
      final mine = exceptions.where((item) => item.eventId == row.id);
      visible.addAll(
        expandEvent(
          series: _series(row),
          exceptions: [
            for (final item in mine)
              SeriesException(
                originalStart: item.originalStart,
                excluded: item.excluded,
                startsAt: item.startsAt,
                endsAt: item.endsAt,
                title: item.title,
                description: item.description,
                category: item.category,
                priority: item.priority,
              ),
          ],
          rangeStart: from,
          rangeEnd: to,
        ),
      );
    }
    visible.sort((left, right) => left.startsAt.compareTo(right.startsAt));
    return visible;
  }

  Future<void> _publish(LocalDatabase database, String userId) async {
    final horizon = now().toUtc();
    final events = await _visible(
      database,
      userId,
      horizon.subtract(const Duration(minutes: 1)),
      horizon.add(const Duration(days: 14)),
    );
    hub.notify(
      AgendaChange(userId: userId, reminders: planReminders(events: events, now: horizon)),
    );
  }

  StoredEventsCompanion _rowFromDraft(
    String userId,
    String id,
    EventDraft draft, {
    required int version,
    required String status,
    DateTime? createdAt,
  }) {
    return StoredEventsCompanion.insert(
      id: id,
      userId: userId,
      title: draft.title.trim(),
      description: Value(draft.description),
      startsAt: draft.startsAt.toUtc(),
      endsAt: Value(draft.endsAt?.toUtc()),
      category: draft.category,
      priority: draft.priority,
      recurrenceJson: Value(
        draft.clearRecurrence || draft.recurrence == null
            ? null
            : jsonEncode({
                'frequency': draft.recurrence!.frequency,
                'interval': draft.recurrence!.interval,
                'weekdays': draft.recurrence!.weekdays,
                'until': draft.recurrence!.until?.toUtc().toIso8601String(),
                'count': draft.recurrence!.count,
                'offsetMinutes': draft.recurrence!.offsetMinutes,
              }),
      ),
      version: version,
      reminderMinutes: Value(draft.reminderMinutes),
      syncStatus: status,
      updatedAt: createdAt ?? now().toUtc(),
    );
  }

  StoredEventsCompanion _companionFromEvent(
    String userId,
    AgendaEvent event, {
    required String status,
  }) {
    return _rowFromDraft(
      userId,
      event.id,
      EventDraft(
        title: event.title,
        description: event.description,
        startsAt: event.startsAt,
        endsAt: event.endsAt,
        category: event.category,
        priority: event.priority,
        recurrence: event.recurrence,
        reminderMinutes: event.reminderMinutes,
      ),
      version: event.version,
      status: status,
    );
  }

  AgendaEvent _series(StoredEvent row) {
    return AgendaEvent(
      id: row.id,
      title: row.title,
      description: row.description,
      startsAt: row.startsAt.toUtc(),
      endsAt: row.endsAt?.toUtc(),
      category: row.category,
      priority: row.priority,
      createdAt: row.updatedAt,
      updatedAt: row.updatedAt,
      recurrence: _recurrence(row.recurrenceJson),
      version: row.version,
      reminderMinutes: row.reminderMinutes,
      syncStatus: row.syncStatus,
    );
  }

  EventRecurrence? _recurrence(String? raw) {
    if (raw == null) {
      return null;
    }
    final value = jsonDecode(raw);
    if (value is! Map) {
      return null;
    }
    return EventRecurrence(
      frequency: value['frequency'] as String,
      interval: value['interval'] as int,
      weekdays: [
        for (final day in value['weekdays'] as List? ?? const [])
          if (day is int) day,
      ],
      until: value['until'] is String ? DateTime.parse(value['until'] as String) : null,
      count: value['count'] as int?,
      offsetMinutes: value['offsetMinutes'] as int? ?? 0,
    );
  }

  EventDraft _draftFromRow(
    StoredEvent row, {
    String? clientId,
    int? baseVersion,
  }) {
    return EventDraft(
      title: row.title,
      description: row.description,
      startsAt: row.startsAt,
      endsAt: row.endsAt,
      category: row.category,
      priority: row.priority,
      recurrence: _recurrence(row.recurrenceJson),
      clientId: clientId,
      baseVersion: baseVersion,
      reminderMinutes: row.reminderMinutes,
    );
  }

  Future<void> _saveException(
    LocalDatabase database,
    StoredEvent current,
    EventDraft draft, {
    required bool excluded,
  }) async {
    final original = (draft.occurrenceStart ?? draft.startsAt).toUtc();
    await database.into(database.storedExceptions).insertOnConflictUpdate(
      StoredExceptionsCompanion.insert(
        id: '${current.id}-${original.millisecondsSinceEpoch}',
        eventId: current.id,
        originalStart: original,
        excluded: excluded,
        title: Value(excluded ? null : draft.title),
        description: Value(excluded ? null : draft.description),
        startsAt: Value(excluded ? null : draft.startsAt.toUtc()),
        endsAt: Value(excluded ? null : draft.endsAt?.toUtc()),
        category: Value(excluded ? null : draft.category),
        priority: Value(excluded ? null : draft.priority),
      ),
    );
  }

  Future<void> _enqueue(
    LocalDatabase database, {
    required String userId,
    required String operation,
    required String entityId,
    required String payload,
    int? baseVersion,
  }) async {
    final existing = await (database.select(database.outboxItems)
          ..where(
            (row) =>
                row.userId.equals(userId) &
                row.entityId.equals(entityId) &
                row.status.equals('pending'),
          ))
        .getSingleOrNull();
    if (existing != null) {
      await (database.update(database.outboxItems)..where((row) => row.id.equals(existing.id))).write(
        OutboxItemsCompanion(
          operation: Value(operation),
          payload: Value(payload),
          baseVersion: Value(baseVersion),
        ),
      );
      return;
    }
    await database.into(database.outboxItems).insert(
      OutboxItemsCompanion.insert(
        userId: userId,
        operation: operation,
        entityId: entityId,
        payload: payload,
        baseVersion: Value(baseVersion),
        status: 'pending',
        createdAt: now().toUtc(),
      ),
    );
  }

  Future<void> _markSynced(
    LocalDatabase database,
    String userId,
    String id,
    AgendaEvent saved,
  ) async {
    await (database.update(database.storedEvents)
          ..where((row) => row.id.equals(id) & row.userId.equals(userId)))
        .write(
          StoredEventsCompanion(
            version: Value(saved.version),
            syncStatus: const Value('synced'),
            serverTitle: const Value(null),
            hidden: const Value(false),
          ),
        );
  }

  Future<void> _updateItem(
    LocalDatabase database,
    OutboxItem item, {
    required String status,
    required int attempts,
  }) async {
    await (database.update(database.outboxItems)..where((row) => row.id.equals(item.id))).write(
      OutboxItemsCompanion(status: Value(status), attempts: Value(attempts)),
    );
  }

  Future<void> _removeItem(LocalDatabase database, int id) {
    return (database.delete(database.outboxItems)..where((row) => row.id.equals(id))).go();
  }

  Future<void> _dropQueue(LocalDatabase database, String userId, String entityId) {
    return (database.delete(database.outboxItems)
          ..where((row) => row.userId.equals(userId) & row.entityId.equals(entityId)))
        .go();
  }

  Future<StoredEvent?> _find(LocalDatabase database, String id, String userId) {
    return (database.select(database.storedEvents)
          ..where((row) => row.id.equals(id) & row.userId.equals(userId)))
        .getSingleOrNull();
  }

  Future<StoredEvent> _require(LocalDatabase database, String id, String userId) async {
    final row = await _find(database, id, userId);
    if (row == null) {
      throw const AgendaNotFoundFailure();
    }
    return row;
  }

  String _user(String token) {
    final userId = subjectOf(token);
    if (userId == null) {
      throw const AgendaUnauthenticated();
    }
    return userId;
  }

  String _payload(EventDraft draft, String id) {
    return jsonEncode({
      'id': id,
      'title': draft.title,
      'baseVersion': draft.baseVersion,
      'scope': draft.scope,
      'occurrenceStart': draft.occurrenceStart?.toUtc().toIso8601String(),
    });
  }
}

AgendaEvent _eventFromJson(Object? source) {
  if (source is! Map) {
    throw const AgendaUnexpectedFailure();
  }
  final map = source is Map<String, dynamic> ? source : Map<String, dynamic>.from(source);
  final recurrence = map['recurrence'];
  return AgendaEvent(
    id: map['id'] as String,
    title: map['title'] as String,
    description: map['description'] as String?,
    startsAt: DateTime.parse(map['startsAt'] as String),
    endsAt: map['endsAt'] is String ? DateTime.parse(map['endsAt'] as String) : null,
    category: map['category'] as String,
    priority: map['priority'] as String,
    createdAt: DateTime.parse(map['createdAt'] as String? ?? map['startsAt'] as String),
    updatedAt: DateTime.parse(map['updatedAt'] as String? ?? map['startsAt'] as String),
    version: map['version'] as int? ?? 1,
    reminderMinutes: map['reminderMinutes'] as int?,
    syncStatus: 'synced',
    recurrence: recurrence is Map
        ? EventRecurrence(
            frequency: recurrence['frequency'] as String,
            interval: recurrence['interval'] as int,
            weekdays: [
              for (final day in recurrence['weekdays'] as List? ?? const [])
                if (day is int) day,
            ],
            until: recurrence['until'] is String
                ? DateTime.parse(recurrence['until'] as String)
                : null,
            count: recurrence['count'] as int?,
            offsetMinutes: recurrence['offsetMinutes'] as int? ?? 0,
          )
        : null,
  );
}

Map<String, Object?> publicFields(AgendaEvent event) {
  return {
    'id': event.id,
    'title': event.title,
    'description': event.description,
    'startsAt': event.startsAt.toUtc().toIso8601String(),
    'endsAt': event.endsAt?.toUtc().toIso8601String(),
    'category': event.category,
    'priority': event.priority,
    'createdAt': event.createdAt.toUtc().toIso8601String(),
    'updatedAt': event.updatedAt.toUtc().toIso8601String(),
    'version': event.version,
    'reminderMinutes': event.reminderMinutes,
  };
}

String _newId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  String hex(int value) => value.toRadixString(16).padLeft(2, '0');
  final text = bytes.map(hex).join();
  return '${text.substring(0, 8)}-${text.substring(8, 12)}-${text.substring(12, 16)}-${text.substring(16, 20)}-${text.substring(20)}';
}
