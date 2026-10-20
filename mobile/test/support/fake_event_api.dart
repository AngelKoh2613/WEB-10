import 'dart:async';

import 'package:secureplan_mobile/features/agenda/data/event_api.dart';
import 'package:secureplan_mobile/features/agenda/domain/agenda_event.dart';

class FakeEventApi implements EventApi {
  final items = <AgendaEvent>[];
  AgendaFailure? listFailure;
  AgendaFailure? writeFailure;
  Completer<void>? gate;
  String? lastScope;

  @override
  Future<List<AgendaEvent>> list(
    String accessToken, {
    required DateTime from,
    required DateTime to,
  }) async {
    await _pause();
    final failure = listFailure;
    if (failure != null) {
      throw failure;
    }
    return List<AgendaEvent>.of(items);
  }

  @override
  Future<AgendaEvent> create(String accessToken, EventDraft draft) async {
    await _pause();
    final failure = writeFailure;
    if (failure != null) {
      throw failure;
    }
    final now = DateTime.utc(2026, 10, 13, 12);
    final event = AgendaEvent(
      id: 'event-${items.length + 1}',
      title: draft.title,
      description: draft.description,
      startsAt: draft.startsAt,
      endsAt: draft.endsAt,
      category: draft.category,
      priority: draft.priority,
      createdAt: now,
      updatedAt: now,
      occurrenceStart: draft.startsAt,
      recurrence: draft.recurrence,
    );
    items.add(event);
    return event;
  }

  @override
  Future<AgendaEvent> update(
    String accessToken,
    String id,
    EventDraft draft,
  ) async {
    await _pause();
    final failure = writeFailure;
    if (failure != null) {
      throw failure;
    }
    lastScope = draft.scope;
    final index = items.indexWhere((event) {
      if (event.id != id) {
        return false;
      }
      if (draft.scope == 'occurrence' && draft.occurrenceStart != null) {
        return event.occurrenceKey == draft.occurrenceStart;
      }
      return true;
    });
    final current = index < 0 ? null : items[index];
    if (current == null) {
      throw const AgendaNotFoundFailure();
    }
    final updated = AgendaEvent(
      id: current.id,
      title: draft.title,
      description: draft.description,
      startsAt: draft.startsAt,
      endsAt: draft.endsAt,
      category: draft.category,
      priority: draft.priority,
      createdAt: current.createdAt,
      updatedAt: DateTime.utc(2026, 10, 13, 13),
      occurrenceStart: current.occurrenceStart,
      recurrence: draft.clearRecurrence ? null : draft.recurrence ?? current.recurrence,
    );
    items[index] = updated;
    return updated;
  }

  @override
  Future<void> delete(
    String accessToken,
    String id, {
    String? scope,
    DateTime? occurrenceStart,
    int? baseVersion,
  }) async {
    await _pause();
    final failure = writeFailure;
    if (failure != null) {
      throw failure;
    }
    lastScope = scope;
    items.removeWhere((event) {
      if (event.id != id) {
        return false;
      }
      if (scope == 'occurrence' && occurrenceStart != null) {
        return event.occurrenceKey == occurrenceStart;
      }
      return true;
    });
  }

  Future<void> _pause() async {
    final pending = gate;
    if (pending != null) {
      await pending.future;
    }
  }
}
