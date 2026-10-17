import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:secureplan_mobile/features/agenda/domain/agenda_event.dart';

sealed class AgendaFailure implements Exception {
  const AgendaFailure(this.message);

  final String message;
}

class AgendaValidationFailure extends AgendaFailure {
  const AgendaValidationFailure()
    : super('Los datos del evento no son válidos');
}

class AgendaUnauthenticated extends AgendaFailure {
  const AgendaUnauthenticated() : super('La sesión ha caducado');
}

class AgendaNotFoundFailure extends AgendaFailure {
  const AgendaNotFoundFailure() : super('El evento no está disponible');
}

class AgendaNetworkFailure extends AgendaFailure {
  const AgendaNetworkFailure() : super('No hay conexión con el servidor');
}

class AgendaUnavailableFailure extends AgendaFailure {
  const AgendaUnavailableFailure() : super('La agenda no está disponible');
}

class AgendaUnexpectedFailure extends AgendaFailure {
  const AgendaUnexpectedFailure() : super('No se pudo completar la operación');
}

class AgendaConflictFailure extends AgendaFailure {
  const AgendaConflictFailure({this.server})
    : super(
        'Este evento cambió en el servidor. Conserva tu versión o usa la del servidor.',
      );

  final AgendaEvent? server;
}

abstract interface class AgendaRemote implements EventApi {
  Future<Map<String, dynamic>> pull(String accessToken);
}

abstract interface class EventApi {
  Future<List<AgendaEvent>> list(
    String accessToken, {
    required DateTime from,
    required DateTime to,
  });

  Future<AgendaEvent> create(String accessToken, EventDraft draft);

  Future<AgendaEvent> update(String accessToken, String id, EventDraft draft);

  Future<void> delete(
    String accessToken,
    String id, {
    String? scope,
    DateTime? occurrenceStart,
    int? baseVersion,
  });
}

class HttpEventApi implements AgendaRemote {
  HttpEventApi({required this.baseUrl, required this.client});

  final String baseUrl;
  final http.Client client;

  @override
  Future<List<AgendaEvent>> list(
    String accessToken, {
    required DateTime from,
    required DateTime to,
  }) async {
    final response = await _send(
      () => client.get(
        _uri('/api/events').replace(
          queryParameters: {
            'from': from.toUtc().toIso8601String(),
            'to': to.toUtc().toIso8601String(),
          },
        ),
        headers: _headers(accessToken),
      ),
    );
    if (response.statusCode != 200) {
      throw _failure(response);
    }
    final decoded = _jsonMap(response.body);
    final events = decoded['events'];
    if (events is! List) {
      throw const AgendaUnexpectedFailure();
    }
    return events.map(_event).toList();
  }

  @override
  Future<AgendaEvent> create(String accessToken, EventDraft draft) async {
    final response = await _send(
      () => client.post(
        _uri('/api/events'),
        headers: _headers(accessToken, json: true),
        body: jsonEncode(_body(draft)),
      ),
    );
    if (response.statusCode != 201 && response.statusCode != 200) {
      throw _failure(response);
    }
    return _event(response.body);
  }

  @override
  Future<AgendaEvent> update(
    String accessToken,
    String id,
    EventDraft draft,
  ) async {
    final response = await _send(
      () => client.patch(
        _uri('/api/events/$id'),
        headers: _headers(accessToken, json: true),
        body: jsonEncode(_body(draft)),
      ),
    );
    if (response.statusCode != 200) {
      throw _failure(response);
    }
    return _event(response.body);
  }

  @override
  Future<Map<String, dynamic>> pull(String accessToken) async {
    final response = await _send(
      () => client.get(_uri('/api/events/sync'), headers: _headers(accessToken)),
    );
    if (response.statusCode != 200) {
      throw _failure(response);
    }
    return _jsonMap(response.body);
  }

  @override
  Future<void> delete(
    String accessToken,
    String id, {
    String? scope,
    DateTime? occurrenceStart,
    int? baseVersion,
  }) async {
    final query = <String, String>{
      'scope': ?scope,
      'occurrenceStart': ?occurrenceStart?.toUtc().toIso8601String(),
      'baseVersion': ?baseVersion?.toString(),
    };
    final response = await _send(
      () => client.delete(
        _uri('/api/events/$id').replace(queryParameters: query),
        headers: _headers(accessToken),
      ),
    );
    if (response.statusCode != 204) {
      throw _failure(response);
    }
  }

  Map<String, String> _headers(String accessToken, {bool json = false}) {
    return {
      'accept': 'application/json',
      'authorization': 'Bearer $accessToken',
      if (json) 'content-type': 'application/json',
    };
  }

  Map<String, Object?> _body(EventDraft draft) {
    return {
      'title': draft.title.trim(),
      'description': draft.description,
      'startsAt': draft.startsAt.toUtc().toIso8601String(),
      'endsAt': draft.endsAt?.toUtc().toIso8601String(),
      'category': draft.category,
      'priority': draft.priority,
      if (draft.clientId != null) 'id': draft.clientId,
      if (draft.baseVersion != null) 'baseVersion': draft.baseVersion,
      'reminderMinutes': draft.reminderMinutes,
      if (draft.clearRecurrence) 'recurrence': null,
      if (draft.recurrence != null)
        'recurrence': _recurrenceBody(draft.recurrence!),
      if (draft.scope != null) 'scope': draft.scope,
      if (draft.occurrenceStart != null)
        'occurrenceStart': draft.occurrenceStart!.toUtc().toIso8601String(),
    };
  }

  Map<String, Object?> _recurrenceBody(EventRecurrence recurrence) {
    return {
      'frequency': recurrence.frequency,
      'interval': recurrence.interval,
      'weekdays': recurrence.weekdays,
      'offsetMinutes': recurrence.offsetMinutes,
      if (recurrence.until != null)
        'until': recurrence.until!.toUtc().toIso8601String(),
      if (recurrence.count != null) 'count': recurrence.count,
    };
  }

  AgendaEvent _event(Object? source) {
    final decoded = source is String ? _jsonMap(source) : source;
    if (decoded is! Map<String, dynamic>) {
      throw const AgendaUnexpectedFailure();
    }
    final id = decoded['id'];
    final title = decoded['title'];
    final startsAt = decoded['startsAt'];
    final category = decoded['category'];
    final priority = decoded['priority'];
    final createdAt = decoded['createdAt'];
    final updatedAt = decoded['updatedAt'];
    if (id is! String ||
        title is! String ||
        startsAt is! String ||
        category is! String ||
        priority is! String ||
        createdAt is! String ||
        updatedAt is! String) {
      throw const AgendaUnexpectedFailure();
    }
    final description = decoded['description'];
    final endsAt = decoded['endsAt'];
    final occurrenceStart = decoded['occurrenceStart'];
    return AgendaEvent(
      id: id,
      title: title,
      description: description is String ? description : null,
      startsAt: DateTime.parse(startsAt),
      endsAt: endsAt is String ? DateTime.parse(endsAt) : null,
      category: category,
      priority: priority,
      createdAt: DateTime.parse(createdAt),
      updatedAt: DateTime.parse(updatedAt),
      occurrenceStart: occurrenceStart is String
          ? DateTime.parse(occurrenceStart)
          : null,
      recurrence: _recurrence(decoded['recurrence']),
      version: decoded['version'] is int ? decoded['version'] as int : 1,
      reminderMinutes: decoded['reminderMinutes'] is int
          ? decoded['reminderMinutes'] as int
          : null,
    );
  }

  EventRecurrence? _recurrence(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is! Map<String, dynamic>) {
      throw const AgendaUnexpectedFailure();
    }
    final frequency = value['frequency'];
    final interval = value['interval'];
    final offsetMinutes = value['offsetMinutes'];
    final weekdays = value['weekdays'];
    if (frequency is! String || interval is! int || offsetMinutes is! int) {
      throw const AgendaUnexpectedFailure();
    }
    return EventRecurrence(
      frequency: frequency,
      interval: interval,
      weekdays: weekdays is List
          ? [for (final day in weekdays) if (day is int) day]
          : const [],
      until: value['until'] is String
          ? DateTime.parse(value['until'] as String)
          : null,
      count: value['count'] is int ? value['count'] as int : null,
      offsetMinutes: offsetMinutes,
    );
  }

  Map<String, dynamic> _jsonMap(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const AgendaUnexpectedFailure();
    }
    return decoded;
  }

  AgendaFailure _failure(http.Response response) {
    final statusCode = response.statusCode;
    if (statusCode == 409) {
      AgendaEvent? server;
      try {
        final decoded = _jsonMap(response.body);
        if (decoded['server'] is Map<String, dynamic>) {
          server = _event(decoded['server']);
        }
      } on AgendaFailure {
        server = null;
      } on FormatException {
        server = null;
      }
      return AgendaConflictFailure(server: server);
    }
    return switch (statusCode) {
      400 => const AgendaValidationFailure(),
      401 => const AgendaUnauthenticated(),
      404 => const AgendaNotFoundFailure(),
      503 => const AgendaUnavailableFailure(),
      _ => const AgendaUnexpectedFailure(),
    };
  }

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    try {
      return await request();
    } on http.ClientException {
      throw const AgendaNetworkFailure();
    }
  }

  Uri _uri(String path) {
    final root = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return Uri.parse('$root$path');
  }
}
