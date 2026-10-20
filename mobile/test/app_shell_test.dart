import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secureplan_mobile/core/theme/app_theme.dart';
import 'package:secureplan_mobile/features/agenda/application/agenda_controller.dart';
import 'package:secureplan_mobile/features/auth/application/auth_controller.dart';
import 'package:secureplan_mobile/presentation/shell/app_shell.dart';

import 'support/fake_event_api.dart';
import 'support/memory_token_store.dart';

void main() {
  testWidgets('shows the architectural shell', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStoreProvider.overrideWithValue(MemoryTokenStore()),
          eventApiProvider.overrideWithValue(FakeEventApi()),
        ],
        child: MaterialApp(theme: AppTheme.light(), home: const AppShell()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('SecurePlan'), findsOneWidget);
    expect(find.text('No hay eventos este día'), findsOneWidget);
    expect(find.byTooltip('Cerrar sesión'), findsOneWidget);
  });
}
