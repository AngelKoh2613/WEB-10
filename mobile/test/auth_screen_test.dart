import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secureplan_mobile/app/secureplan_app.dart';
import 'package:secureplan_mobile/features/agenda/application/agenda_controller.dart';
import 'package:secureplan_mobile/features/auth/application/auth_controller.dart';
import 'package:secureplan_mobile/features/auth/data/auth_api.dart';
import 'package:secureplan_mobile/features/auth/presentation/register_screen.dart';

import 'support/fake_auth_api.dart';
import 'support/fake_event_api.dart';
import 'support/memory_token_store.dart';

Future<void> pumpSecurePlan(
  WidgetTester tester, {
  required MemoryTokenStore store,
  required FakeAuthApi api,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        tokenStoreProvider.overrideWithValue(store),
        authApiProvider.overrideWithValue(api),
        eventApiProvider.overrideWithValue(FakeEventApi()),
      ],
      child: const SecurePlanApp(),
    ),
  );
}

void main() {
  testWidgets('shows login instead of the agenda while signed out', (
    tester,
  ) async {
    await pumpSecurePlan(tester, store: MemoryTokenStore(), api: FakeAuthApi());
    await tester.pumpAndSettle();

    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(find.text('Sin módulos activos'), findsNothing);
  });

  testWidgets('validates the login form before calling the API', (
    tester,
  ) async {
    final api = FakeAuthApi();
    await pumpSecurePlan(tester, store: MemoryTokenStore(), api: api);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Iniciar sesión'));
    await tester.pump();

    expect(find.text('El correo no es válido'), findsOneWidget);
    expect(api.calls, isEmpty);
  });

  testWidgets('shows a loading indicator and then an API error', (
    tester,
  ) async {
    final api = FakeAuthApi()
      ..gate = Completer<void>()
      ..failure = const AuthCredentialsFailure();
    await pumpSecurePlan(tester, store: MemoryTokenStore(), api: api);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'ana@example.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'CorrectHorse1');
    await tester.tap(find.widgetWithText(FilledButton, 'Iniciar sesión'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    api.gate!.complete();
    await tester.pumpAndSettle();

    expect(find.text('Correo o contraseña incorrectos'), findsOneWidget);
    expect(find.text('Sin módulos activos'), findsNothing);
  });

  testWidgets(
    'opens the agenda after a successful login and returns after logout',
    (tester) async {
      final store = MemoryTokenStore();
      final api = FakeAuthApi(accessToken: 'fresh-token');
      await pumpSecurePlan(tester, store: store, api: api);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextFormField).at(0),
        'ana@example.com',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'CorrectHorse1');
      await tester.tap(find.widgetWithText(FilledButton, 'Iniciar sesión'));
      await tester.pumpAndSettle();

      expect(store.token, 'fresh-token');
      expect(find.text('No hay eventos este día'), findsOneWidget);

      await tester.tap(find.byTooltip('Cerrar sesión'));
      await tester.pumpAndSettle();

      expect(store.token, isNull);
      expect(find.text('Iniciar sesión'), findsOneWidget);
    },
  );

  testWidgets('navigates to registration and validates the password policy', (
    tester,
  ) async {
    await pumpSecurePlan(tester, store: MemoryTokenStore(), api: FakeAuthApi());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Crear cuenta'));
    await tester.pumpAndSettle();

    expect(find.text('Registro'), findsOneWidget);
    final fields = find.descendant(
      of: find.byType(RegisterScreen),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(fields.at(0), 'ana@example.com');
    await tester.enterText(fields.at(1), 'short');
    await tester.tap(find.widgetWithText(FilledButton, 'Registrarme'));
    await tester.pump();

    expect(find.text('La contraseña no cumple la política'), findsOneWidget);
  });

  testWidgets('leaves registration and opens the agenda after success', (
    tester,
  ) async {
    final api = FakeAuthApi(accessToken: 'fresh-token');
    await pumpSecurePlan(tester, store: MemoryTokenStore(), api: api);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Crear cuenta'));
    await tester.pumpAndSettle();
    final fields = find.descendant(
      of: find.byType(RegisterScreen),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(fields.at(0), 'ana@example.com');
    await tester.enterText(fields.at(1), 'CorrectHorse1');
    await tester.tap(find.widgetWithText(FilledButton, 'Registrarme'));
    await tester.pumpAndSettle();

    expect(find.text('Registro'), findsNothing);
    expect(find.text('No hay eventos este día'), findsOneWidget);
  });
}
