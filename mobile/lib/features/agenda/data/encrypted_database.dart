import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:secureplan_mobile/features/agenda/data/local_database.dart';

class EncryptedDatabaseException implements Exception {
  const EncryptedDatabaseException(this.message);

  final String message;

  @override
  String toString() => message;
}

QueryExecutor openEncryptedExecutor(File file, String hexKey) {
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(hexKey)) {
    throw const EncryptedDatabaseException('La clave de la agenda no es válida');
  }
  return NativeDatabase(
    file,
    setup: (raw) {
      _requireCipher(raw);
      raw.execute("PRAGMA key = \"x'$hexKey'\"");
    },
  );
}

void _requireCipher(Database raw) {
  try {
    final rows = raw.select('PRAGMA cipher');
    final name = rows.isEmpty ? null : rows.first.columnAt(0);
    if (name == null || name.toString().isEmpty) {
      throw const EncryptedDatabaseException(
        'SQLite no está compilado con cifrado',
      );
    }
  } on SqliteException {
    throw const EncryptedDatabaseException(
      'SQLite no está compilado con cifrado',
    );
  }
}

LocalDatabase openEncryptedDatabase(File file, String hexKey) {
  return LocalDatabase(openEncryptedExecutor(file, hexKey));
}
