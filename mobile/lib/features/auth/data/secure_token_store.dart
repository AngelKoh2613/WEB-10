import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:secureplan_mobile/features/auth/data/token_store.dart';

class SecureTokenStore implements TokenStore {
  SecureTokenStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  static const storageKey = 'secureplan.access_token';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() => _storage.read(key: storageKey);

  @override
  Future<void> write(String token) {
    return _storage.write(key: storageKey, value: token);
  }

  @override
  Future<void> clear() => _storage.delete(key: storageKey);
}
