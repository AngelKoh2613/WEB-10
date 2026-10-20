import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secureplan_mobile/core/theme/app_theme.dart';
import 'package:secureplan_mobile/features/agenda/application/agenda_controller.dart';
import 'package:secureplan_mobile/features/agenda/data/event_api.dart';
import 'package:secureplan_mobile/features/agenda/domain/agenda_event.dart';
import 'package:secureplan_mobile/features/auth/application/auth_controller.dart';
import 'package:secureplan_mobile/presentation/shell/app_shell.dart';

import 'support/fake_event_api.dart';
import 'support/memory_token_store.dart';
import 'support/signed_in_auth.dart';

AgendaEvent sampleEvent({
  required String id,
  required String title,
  required DateTime startsAt,
  EventRecurrence? recurrence,
}) {
  return AgendaEvent(
    id: id,
    title: title,
    description: null,
    startsAt: startsAt,
    endsAt: null,
    category: 'estudio',
    priority: 'high',
    createdAt: DateTime.utc(2026, 10, 1),
    updatedAt: DateTime.utc(2026, 10, 1),
    occurrenceStart: startsAt,
    recurrence: recurrence,
  );
}

Future<void> pumpAgenda(
  WidgetTester tester, {
  required FakeEventApi api,
}) async {
  tester.view
    ..physicalSize = const Size(412, 915)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(SignedInAuth.new),
        tokenStoreProvider.overrideWithValue(MemoryTokenStore()),
        eventApiProvider.overrideWithValue(api),
        selectedDayProvider.overrideWith(FixedSelectedDay.new),
      ],
      child: MaterialApp(theme: AppTheme.light(), home: const AppShell()),
    ),
  );
}

void main() {
  testWidgets('shows a loading state and then an error that can be retried', (
    tester,
  ) async {
    final api = FakeEventApi()
      ..gate = Completer<void>()
      ..listFailure = const AgendaNetworkFailure();
    await pumpAgenda(tester, api: api);
    await tester.pump();

    expect(find.text('Cargando eventos'), findsOneWidget);

    api.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('No se pudieron cargar los eventos'), findsOneWidget);

    api.listFailure = null;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('No hay eventos este día'), findsOneWidget);
  });

  testWidgets('renders events for the selected day and moves between months', (
    tester,
  ) async {
    final api = FakeEventApi()
      ..items.addAll([
        sampleEvent(
          id: 'a',
          title: 'Clase de matemáticas',
          startsAt: DateTime(2026, 10, 13, 9),
        ),
        sampleEvent(
          id: 'b',
          title: 'Entrega del informe',
          startsAt: DateTime(2026, 10, 20, 11),
        ),
      ]);
    await pumpAgenda(tester, api: api);
    await tester.pumpAndSettle();

    expect(find.text('Octubre 2026'), findsOneWidget);
    expect(find.text('Martes, 13 de octubre'), findsOneWidget);
    expect(find.text('1 evento'), findsOneWidget);
    expect(find.text('Clase de matemáticas'), findsOneWidget);
    expect(find.text('Entrega del informe'), findsNothing);
    expect(find.byKey(const ValueKey('mark-2026-10-13')), findsOneWidget);
    expect(find.byKey(const ValueKey('mark-2026-10-20')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('day-2026-10-20')));
    await tester.pumpAndSettle();
    expect(find.text('Entrega del informe'), findsOneWidget);
    expect(find.text('Clase de matemáticas'), findsNothing);

    await tester.tap(find.byTooltip('Mes siguiente'));
    await tester.pumpAndSettle();
    expect(find.text('Noviembre 2026'), findsOneWidget);
    expect(find.text('No hay eventos este día'), findsOneWidget);
  });

  testWidgets('validates the form and creates, edits and deletes an event', (
    tester,
  ) async {
    final api = FakeEventApi();
    await pumpAgenda(tester, api: api);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nuevo evento'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pump();
    expect(
      find.text('El título debe tener entre 1 y 200 caracteres'),
      findsOneWidget,
    );

    await tester.enterText(find.byKey(const Key('event-title')), 'Tutoría');
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(find.text('Tutoría'), findsOneWidget);
    expect(api.items.single.startsAt, DateTime(2026, 10, 13, 9));

    await tester.tap(find.byTooltip('Editar evento'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('event-title')),
      'Tutoría revisada',
    );
    await tester.ensureVisible(
      find.widgetWithText(FilledButton, 'Guardar cambios'),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar cambios'));
    await tester.pumpAndSettle();
    expect(find.text('Tutoría revisada'), findsOneWidget);

    await tester.tap(find.byTooltip('Eliminar evento'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
    await tester.pumpAndSettle();
    expect(find.text('Tutoría revisada'), findsNothing);
    expect(find.text('No hay eventos este día'), findsOneWidget);
    expect(api.items, isEmpty);
  });

  testWidgets('shows a server validation error and keeps the form open', (
    tester,
  ) async {
    final api = FakeEventApi()..writeFailure = const AgendaValidationFailure();
    await pumpAgenda(tester, api: api);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nuevo evento'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('event-title')), 'Tutoría');
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(find.text('Los datos del evento no son válidos'), findsOneWidget);
    expect(find.text('Nuevo evento'), findsOneWidget);
    expect(api.items, isEmpty);
  });

  testWidgets('asks before editing or deleting one occurrence', (tester) async {
    final api = FakeEventApi()
      ..items.add(
        sampleEvent(
          id: 'series',
          title: 'Clase',
          startsAt: DateTime(2026, 10, 13, 9),
          recurrence: const EventRecurrence(
            frequency: 'daily',
            interval: 1,
            weekdays: [],
            until: null,
            count: 3,
            offsetMinutes: 0,
          ),
        ),
      );
    await pumpAgenda(tester, api: api);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Editar evento'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('event-title')),
      'Clase de hoy',
    );
    await tester.ensureVisible(
      find.widgetWithText(FilledButton, 'Guardar cambios'),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar cambios'));
    await tester.pumpAndSettle();
    expect(find.text('Solo este evento'), findsOneWidget);
    expect(find.text('Toda la serie'), findsOneWidget);

    await tester.tap(find.byKey(const Key('scope-occurrence')));
    await tester.pumpAndSettle();
    expect(api.lastScope, 'occurrence');
    expect(api.items.single.title, 'Clase de hoy');

    await tester.tap(find.byTooltip('Eliminar evento'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('scope-series')));
    await tester.pumpAndSettle();
    expect(api.lastScope, 'series');
    expect(api.items, isEmpty);
  });
}
