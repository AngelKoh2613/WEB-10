import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class DatabaseKeyStore {
  Future<String> keyFor(String userId);
}

class SecureDatabaseKeyStore implements DatabaseKeyStore {
  SecureDatabaseKeyStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String> keyFor(String userId) async {
    final name = 'agenda-key-$userId';
    final existing = await _storage.read(key: name);
    if (existing != null && RegExp(r'^[0-9a-f]{64}$').hasMatch(existing)) {
      return existing;
    }
    final created = _randomKey();
    await _storage.write(key: name, value: created);
    return created;
  }
}

class MemoryDatabaseKeyStore implements DatabaseKeyStore {
  final keys = <String, String>{};

  @override
  Future<String> keyFor(String userId) async {
    return keys.putIfAbsent(userId, _randomKey);
  }
}

String _randomKey() {
  final random = Random.secure();
  final bytes = List<int>.generate(32, (_) => random.nextInt(256));
  return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
}
