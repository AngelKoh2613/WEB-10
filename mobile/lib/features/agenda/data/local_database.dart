import 'package:drift/drift.dart';

part 'local_database.g.dart';

class StoredEvents extends Table {
  @override
  String get tableName => 'stored_events';

  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  DateTimeColumn get startsAt => dateTime()();
  DateTimeColumn get endsAt => dateTime().nullable()();
  TextColumn get category => text()();
  TextColumn get priority => text()();
  TextColumn get recurrenceJson => text().nullable()();
  IntColumn get version => integer()();
  IntColumn get reminderMinutes => integer().nullable()();
  TextColumn get syncStatus => text()();
  TextColumn get serverTitle => text().nullable()();
  BoolColumn get hidden => boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class StoredExceptions extends Table {
  @override
  String get tableName => 'stored_exceptions';

  TextColumn get id => text()();
  TextColumn get eventId => text()();
  DateTimeColumn get originalStart => dateTime()();
  BoolColumn get excluded => boolean()();
  TextColumn get title => text().nullable()();
  TextColumn get description => text().nullable()();
  DateTimeColumn get startsAt => dateTime().nullable()();
  DateTimeColumn get endsAt => dateTime().nullable()();
  TextColumn get category => text().nullable()();
  TextColumn get priority => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class OutboxItems extends Table {
  @override
  String get tableName => 'outbox_items';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get userId => text()();
  TextColumn get operation => text()();
  TextColumn get entityId => text()();
  TextColumn get payload => text()();
  IntColumn get baseVersion => integer().nullable()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get status => text()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get lastError => text().nullable()();
}

@DriftDatabase(tables: [StoredEvents, StoredExceptions, OutboxItems])
class LocalDatabase extends _$LocalDatabase {
  LocalDatabase(super.executor);

  @override
  int get schemaVersion => 1;
}
