import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:secureplan_mobile/core/config/app_config.dart';
import 'package:secureplan_mobile/features/agenda/data/encrypted_database.dart';
import 'package:secureplan_mobile/features/agenda/data/event_api.dart';
import 'package:secureplan_mobile/features/agenda/data/local_agenda.dart';
import 'package:secureplan_mobile/features/agenda/data/local_database.dart';
import 'package:secureplan_mobile/features/agenda/data/database_key_store.dart';
import 'package:secureplan_mobile/features/agenda/domain/agenda_event.dart';
import 'package:secureplan_mobile/features/agenda/domain/agenda_observer.dart';
import 'package:secureplan_mobile/features/agenda/domain/reminder_plan.dart';
import 'package:secureplan_mobile/features/agenda/data/reminder_scheduler.dart';
import 'package:secureplan_mobile/features/auth/application/auth_controller.dart';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

final agendaHubProvider = Provider<AgendaChangeHub>((ref) {
  final hub = AgendaChangeHub();
  final observer = ReminderObserver(ref.watch(reminderSchedulerProvider));
  hub.watch(observer);
  ref.onDispose(() => hub.unwatch(observer));
  return hub;
});

final reminderSchedulerProvider = Provider<ReminderScheduler>(
  (ref) => PluginReminderScheduler(),
);

final databaseCacheProvider = Provider<EncryptedDatabaseCache>((ref) {
  final cache = EncryptedDatabaseCache();
  ref.onDispose(cache.close);
  return cache;
});

final eventApiProvider = Provider<EventApi>((ref) {
  return LocalAgenda(
    remote: HttpEventApi(
      baseUrl: AppConfig.apiBaseUrl,
      client: ref.watch(httpClientProvider),
    ),
    hub: ref.watch(agendaHubProvider),
    openDatabase: (userId) => ref.read(databaseCacheProvider).open(userId),
  );
});

class EncryptedDatabaseCache {
  EncryptedDatabaseCache({DatabaseKeyStore? keys})
    : _keys = keys ?? SecureDatabaseKeyStore();

  final DatabaseKeyStore _keys;
  LocalDatabase? _database;
  String? _userId;

  Future<LocalDatabase> open(String userId) async {
    if (_userId == userId && _database != null) {
      return _database!;
    }
    await _database?.close();
    _database = null;
    final key = await _keys.keyFor(userId);
    final directory = await getApplicationSupportDirectory();
    final file = File(
      '${directory.path}${Platform.pathSeparator}agenda-$userId.sqlite',
    );
    _database = openEncryptedDatabase(file, key);
    _userId = userId;
    return _database!;
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
    _userId = null;
  }
}

final selectedDayProvider = NotifierProvider<SelectedDay, DateTime>(
  SelectedDay.new,
);

final agendaControllerProvider =
    AsyncNotifierProvider<AgendaController, List<AgendaEvent>>(
      AgendaController.new,
    );

class SelectedDay extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  void select(DateTime day) {
    state = DateTime(day.year, day.month, day.day);
  }

  void shiftMonth(int delta) {
    final month = DateTime(state.year, state.month + delta, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0).day;
    final day = state.day > lastDay ? lastDay : state.day;
    state = DateTime(month.year, month.month, day);
  }
}

class AgendaController extends AsyncNotifier<List<AgendaEvent>> {
  @override
  Future<List<AgendaEvent>> build() async {
    final month = ref.watch(
      selectedDayProvider.select((day) => (year: day.year, month: day.month)),
    );
    final session = await ref.watch(authControllerProvider.future);
    if (session == null) {
      return const [];
    }
    try {
      return await ref
          .read(eventApiProvider)
          .list(
            session.accessToken,
            from: _rangeStart(month.year, month.month),
            to: _rangeEnd(month.year, month.month),
          );
    } on AgendaUnauthenticated {
      _endSession();
      return const [];
    }
  }

  Future<String?> create(EventDraft draft) {
    return _write((api, token) => api.create(token, draft));
  }

  Future<String?> save(String id, EventDraft draft) {
    return _write((api, token) => api.update(token, id, draft));
  }

  Future<String?> resolveConflict(String id, {required bool keepMine}) async {
    final session = await ref.read(authControllerProvider.future);
    final api = ref.read(eventApiProvider);
    if (session == null || api is! LocalAgenda) {
      return 'La sesión ha caducado';
    }
    try {
      if (keepMine) {
        await api.keepMine(session.accessToken, id);
      } else {
        await api.keepServer(session.accessToken, id);
      }
      await _reload(session.accessToken);
      return null;
    } on AgendaUnauthenticated {
      _endSession();
      return 'La sesión ha caducado';
    } on AgendaFailure catch (error) {
      return error.message;
    }
  }

  Future<String?> delete(
    String id, {
    String? scope,
    DateTime? occurrenceStart,
    int? baseVersion,
  }) async {
    final session = await ref.read(authControllerProvider.future);
    if (session == null) {
      return 'La sesión ha caducado';
    }
    try {
      await ref
          .read(eventApiProvider)
          .delete(
            session.accessToken,
            id,
            scope: scope,
            occurrenceStart: occurrenceStart,
            baseVersion: baseVersion,
          );
      await _reload(session.accessToken);
      return null;
    } on AgendaUnauthenticated {
      _endSession();
      return 'La sesión ha caducado';
    } on AgendaFailure catch (error) {
      return error.message;
    }
  }

  Future<String?> _write(
    Future<AgendaEvent> Function(EventApi api, String token) action,
  ) async {
    final session = await ref.read(authControllerProvider.future);
    if (session == null) {
      return 'La sesión ha caducado';
    }
    try {
      await action(ref.read(eventApiProvider), session.accessToken);
      await _reload(session.accessToken);
      return null;
    } on AgendaUnauthenticated {
      _endSession();
      return 'La sesión ha caducado';
    } on AgendaFailure catch (error) {
      return error.message;
    }
  }

  Future<void> _reload(String accessToken) async {
    final month = ref.read(selectedDayProvider);
    final events = await ref
        .read(eventApiProvider)
        .list(
          accessToken,
          from: _rangeStart(month.year, month.month),
          to: _rangeEnd(month.year, month.month),
        );
    state = AsyncData(events);
  }

  DateTime _rangeStart(int year, int month) {
    return DateTime(year, month, 1).subtract(const Duration(days: 1));
  }

  DateTime _rangeEnd(int year, int month) {
    return DateTime(year, month + 1, 1).add(const Duration(days: 1));
  }

  void _endSession() {
    Future<void>(() => ref.read(authControllerProvider.notifier).logout());
  }
}
