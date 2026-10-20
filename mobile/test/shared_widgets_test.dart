import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secureplan_mobile/shared/widgets/empty_view.dart';
import 'package:secureplan_mobile/shared/widgets/error_view.dart';
import 'package:secureplan_mobile/shared/widgets/loading_view.dart';

void main() {
  testWidgets('EmptyView shows its copy', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: EmptyView(title: 'Vacío', message: 'No hay datos'),
      ),
    );

    expect(find.text('Vacío'), findsOneWidget);
    expect(find.text('No hay datos'), findsOneWidget);
  });

  testWidgets('ErrorView invokes retry', (tester) async {
    var taps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: ErrorView(
          title: 'Error',
          message: 'No se pudo cargar',
          onRetry: () => taps++,
        ),
      ),
    );

    await tester.tap(find.text('Reintentar'));
    expect(taps, 1);
  });

  testWidgets('LoadingView exposes its message', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: LoadingView(message: 'Cargando agenda')),
    );

    expect(find.text('Cargando agenda'), findsOneWidget);
  });
}
