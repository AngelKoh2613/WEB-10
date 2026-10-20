import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secureplan_mobile/features/auth/application/auth_controller.dart';
import 'package:secureplan_mobile/features/auth/data/auth_api.dart';

import 'support/auth_token.dart';
import 'support/fake_auth_api.dart';
import 'support/memory_token_store.dart';

void main() {
  ProviderContainer containerFor({
    required MemoryTokenStore store,
    required FakeAuthApi api,
  }) {
    final container = ProviderContainer(
      overrides: [
        tokenStoreProvider.overrideWithValue(store),
        authApiProvider.overrideWithValue(api),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('starts signed out when no token is stored', () async {
    final container = containerFor(
      store: MemoryTokenStore(),
      api: FakeAuthApi(),
    );

    final session = await container.read(authControllerProvider.future);

    expect(session, isNull);
  });

  test('clears an expired token and stays signed out', () async {
    final store = MemoryTokenStore()
      ..token = accessTokenWithExpiry(
        DateTime.now()
                .subtract(const Duration(minutes: 1))
                .millisecondsSinceEpoch ~/
            1000,
      );
    final api = FakeAuthApi();
    final container = containerFor(store: store, api: api);

    final session = await container.read(authControllerProvider.future);

    expect(session, isNull);
    expect(store.token, isNull);
    expect(api.calls, isEmpty);
  });

  test('keeps a usable token when the server cannot be reached', () async {
    final token = accessTokenWithExpiry(
      DateTime.now().add(const Duration(minutes: 10)).millisecondsSinceEpoch ~/
          1000,
    );
    final store = MemoryTokenStore()..token = token;
    final api = FakeAuthApi()..failure = const AuthNetworkFailure();
    final container = containerFor(store: store, api: api);

    final session = await container.read(authControllerProvider.future);

    expect(session?.accessToken, token);
    expect(store.token, token);
  });

  test('clears a token rejected by the server', () async {
    final store = MemoryTokenStore()
      ..token = accessTokenWithExpiry(
        DateTime.now()
                .add(const Duration(minutes: 10))
                .millisecondsSinceEpoch ~/
            1000,
      );
    final api = FakeAuthApi()..failure = const AuthCredentialsFailure();
    final container = containerFor(store: store, api: api);

    final session = await container.read(authControllerProvider.future);

    expect(session, isNull);
    expect(store.token, isNull);
  });

  test('stores the token after login and removes it on logout', () async {
    final store = MemoryTokenStore();
    final api = FakeAuthApi(accessToken: 'fresh-token');
    final container = containerFor(store: store, api: api);
    await container.read(authControllerProvider.future);

    final message = await container
        .read(authControllerProvider.notifier)
        .login(email: 'ana@example.com', password: 'CorrectHorse1');
    expect(message, isNull);
    expect(store.token, 'fresh-token');

    api.failure = const AuthNetworkFailure();
    await container.read(authControllerProvider.notifier).logout();

    expect(store.token, isNull);
    expect(container.read(authControllerProvider).value, isNull);
  });
}
