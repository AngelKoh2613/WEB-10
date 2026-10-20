import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secureplan_mobile/app/app_errors.dart';

void main() {
  final previousBuilder = ErrorWidget.builder;
  final previousHandler = FlutterError.onError;

  setUp(installFlutterErrorHandlers);

  tearDown(() {
    ErrorWidget.builder = previousBuilder;
    FlutterError.onError = previousHandler;
  });

  testWidgets('a broken screen shows a readable message without the exception', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: _BrokenScreen()));

    expect(tester.takeException(), isA<StateError>());
    expect(find.text('Ocurrió un error al mostrar esta pantalla.'), findsOneWidget);
    expect(find.textContaining('secret-token'), findsNothing);
  });
}

class _BrokenScreen extends StatelessWidget {
  const _BrokenScreen();

  @override
  Widget build(BuildContext context) {
    throw StateError('secret-token');
  }
}
