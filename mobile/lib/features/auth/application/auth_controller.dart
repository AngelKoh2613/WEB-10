import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:secureplan_mobile/core/config/app_config.dart';
import 'package:secureplan_mobile/features/auth/data/auth_api.dart';
import 'package:secureplan_mobile/features/auth/data/secure_token_store.dart';
import 'package:secureplan_mobile/features/auth/data/token_store.dart';
import 'package:secureplan_mobile/features/auth/domain/access_token.dart';

class AuthSession {
  const AuthSession(this.accessToken);

  final String accessToken;
}

final tokenStoreProvider = Provider<TokenStore>((ref) => SecureTokenStore());

final httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final authApiProvider = Provider<AuthApi>((ref) {
  return HttpAuthApi(
    baseUrl: AppConfig.apiBaseUrl,
    client: ref.watch(httpClientProvider),
  );
});

final authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthSession?>(AuthController.new);

class AuthController extends AsyncNotifier<AuthSession?> {
  @override
  Future<AuthSession?> build() => _restore();

  Future<String?> register({required String email, required String password}) {
    return _submit(
      () =>
          ref.read(authApiProvider).register(email: email, password: password),
    );
  }

  Future<String?> login({required String email, required String password}) {
    return _submit(
      () => ref.read(authApiProvider).login(email: email, password: password),
    );
  }

  Future<void> logout() async {
    final token = state.value?.accessToken;
    if (token != null) {
      try {
        await ref.read(authApiProvider).logout(token);
      } on AuthFailure {
        // The access token is not revoked on the server. Local deletion still happens.
      }
    }
    await ref.read(tokenStoreProvider).clear();
    state = const AsyncData(null);
  }

  Future<AuthSession?> _restore() async {
    final store = ref.read(tokenStoreProvider);
    final token = await store.read();
    if (token == null || token.isEmpty) {
      return null;
    }
    if (!isAccessTokenUsable(token, DateTime.now())) {
      await store.clear();
      return null;
    }

    try {
      await ref.read(authApiProvider).session(token);
      return AuthSession(token);
    } on AuthNetworkFailure {
      return AuthSession(token);
    } on AuthFailure {
      await store.clear();
      return null;
    }
  }

  Future<String?> _submit(Future<AuthSuccess> Function() action) async {
    try {
      final result = await action();
      await ref.read(tokenStoreProvider).write(result.accessToken);
      state = AsyncData(AuthSession(result.accessToken));
      return null;
    } on AuthFailure catch (error) {
      return error.message;
    }
  }
}
