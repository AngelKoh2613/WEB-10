import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:secureplan_mobile/features/agenda/data/encrypted_database.dart';
import 'package:secureplan_mobile/features/agenda/data/local_database.dart';
import 'package:secureplan_mobile/main.dart' as app;

const _keyA =
    '00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff';
const _keyB =
    'ffeeddccbbaa99887766554433221100ffeeddccbbaa99887766554433221100';
const _accentTitle = 'ReuniÃ³n acadÃ©mica â€” revisiÃ³n de programaciÃ³n';
const _accentDescription = 'Nota "Ã¡Ã©Ã­Ã³ÃºÃ±Ã¼", segunda lÃ­nea';
const _password = 'CorrectHorse1';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a wrong key fails and leaves the temporary database intact', (
    tester,
  ) async {
    await _proveWrongKeyLeavesTheFile();
  });

  testWidgets('pending Android checks on the event form', (tester) async {
    final errorBuilder = ErrorWidget.builder;
    app.main();
    await _waitUntil(
      tester,
      () =>
          find.text('Crear cuenta').evaluate().isNotEmpty ||
          find.text('Nuevo evento').evaluate().isNotEmpty,
    );
    if (find.text('Crear cuenta').evaluate().isNotEmpty) {
      await tester.tap(find.text('Crear cuenta'));
      await _waitFor(tester, find.text('Registrarme'));
      final email = const String.fromEnvironment('PROBE_EMAIL');
      expect(email.contains('@'), isTrue);
      final fields = find.byType(TextFormField);
      final count = fields.evaluate().length;
      await tester.enterText(fields.at(count - 2), email);
      await tester.enterText(fields.at(count - 1), _password);
      await tester.tap(find.text('Registrarme'));
      await _waitFor(tester, find.text('Nuevo evento'));
    }

    if (find.text(_accentTitle).evaluate().isEmpty) {
      await _createEvent(
        tester,
        title: _accentTitle,
        description: _accentDescription,
      );
      for (final title in ['=1+1', '+mÃ¡s', '-resta', '@menciÃ³n']) {
        await _createEvent(tester, title: title);
      }
    }

    await _exportAndRead(tester, 'JSON', '.json');
    await _exportAndRead(tester, 'CSV', '.csv');
    debugPrint('SECUREPLAN_PROBE ui=pass');
    ErrorWidget.builder = errorBuilder;
  });
}

Future<void> _proveWrongKeyLeavesTheFile() async {
  final root = await getTemporaryDirectory();
  final directory = Directory(
    '${root.path}${Platform.pathSeparator}secureplan-probe-${DateTime.now().microsecondsSinceEpoch}',
  );
  directory.createSync(recursive: true);
  final file = File(
    '${directory.path}${Platform.pathSeparator}agenda-copy.sqlite',
  );

  final created = openEncryptedDatabase(file, _keyA);
  await created
      .into(created.storedEvents)
      .insert(
        StoredEventsCompanion.insert(
          id: 'probe-1',
          userId: 'probe-user',
          title: 'Secreto de prueba',
          startsAt: DateTime.utc(2026, 10, 14, 15),
          category: 'estudio',
          priority: 'high',
          version: 1,
          syncStatus: 'synced',
          updatedAt: DateTime.utc(2026, 10, 14),
        ),
      );
  await created.close();

  final before = await file.readAsBytes();
  expect(before.length, greaterThan(16));
  expect(
    String.fromCharCodes(before.take(16)).contains('SQLite format 3'),
    isFalse,
  );
  expect(String.fromCharCodes(before).contains('Secreto de prueba'), isFalse);
  expect(String.fromCharCodes(before).contains(_keyA), isFalse);

  Object? failure;
  final wrong = openEncryptedDatabase(file, _keyB);
  try {
    await wrong.select(wrong.storedEvents).get();
  } catch (error) {
    failure = error;
  } finally {
    await wrong.close();
  }
  expect(failure, isNotNull);
  final reported = failure.toString();
  expect(reported.contains(_keyA), isFalse);
  expect(reported.contains(_keyB), isFalse);
  expect(await file.readAsBytes(), before);

  final names = directory
      .listSync()
      .map((entity) => entity.uri.pathSegments.last)
      .where((name) => name.isNotEmpty)
      .toList();
  expect(names.where((name) => name.endsWith('.sqlite')).length, 1);

  final again = openEncryptedDatabase(file, _keyA);
  final rows = await again.select(again.storedEvents).get();
  expect(rows.single.title, 'Secreto de prueba');
  await again.close();
  directory.deleteSync(recursive: true);
  debugPrint('SECUREPLAN_PROBE wrong_key=pass');
}

Future<void> _createEvent(
  WidgetTester tester, {
  required String title,
  String? description,
}) async {
  await tester.pump(const Duration(milliseconds: 800));
  await _activate(tester, find.byType(FloatingActionButton));
  await _waitFor(tester, find.byKey(const Key('event-title')));
  await tester.enterText(find.byKey(const Key('event-title')), title);
  if (description != null) {
    await tester.enterText(
      find.byKey(const Key('event-description')),
      description,
    );
  }
  await _activate(tester, find.widgetWithText(FilledButton, 'Guardar'));
  await _waitUntil(
    tester,
    () =>
        find.byKey(const Key('event-title')).evaluate().isEmpty &&
        find.text(title).evaluate().isNotEmpty,
  );
}

Future<void> _exportAndRead(
  WidgetTester tester,
  String choice,
  String extension,
) async {
  final exportButton = tester
      .widgetList<IconButton>(find.byType(IconButton))
      .firstWhere((button) => button.tooltip == 'Exportar');
  expect(exportButton.onPressed, isNotNull);
  exportButton.onPressed!();
  await tester.pump();
  await _waitFor(tester, find.text(choice));
  await _activate(tester, find.widgetWithText(ListTile, choice));
  await tester.pump(const Duration(seconds: 2));

  final directory = await getTemporaryDirectory();
  final matches =
      directory
          .listSync(recursive: true)
          .whereType<File>()
          .where(
            (file) =>
                file.path.contains('secureplan-eventos') &&
                file.path.endsWith(extension),
          )
          .toList()
        ..sort(
          (left, right) =>
              right.lastModifiedSync().compareTo(left.lastModifiedSync()),
        );
  expect(matches, isNotEmpty);
  final bytes = await matches.first.readAsBytes();
  final text = utf8.decode(bytes);
  expect(text.contains(_accentTitle), isTrue);
  expect(text.contains('Ã¡Ã©Ã­Ã³ÃºÃ±Ã¼'), isTrue);
  expect(text.contains(_keyA), isFalse);
  expect(text.contains('accessToken'), isFalse);
  if (extension == '.json') {
    expect(text.contains('"format": "secureplan-events"'), isTrue);
    expect(text.contains('"title": "=1+1"'), isTrue);
    expect(text.contains('"title": "+mÃ¡s"'), isTrue);
    expect(text.contains('"title": "-resta"'), isTrue);
    expect(text.contains('"title": "@menciÃ³n"'), isTrue);
  } else {
    expect(text.contains("'=1+1"), isTrue);
    expect(text.contains("'+mÃ¡s"), isTrue);
    expect(text.contains("'-resta"), isTrue);
    expect(text.contains("'@menciÃ³n"), isTrue);
    expect(text.contains('"Nota ""Ã¡Ã©Ã­Ã³ÃºÃ±Ã¼"", segunda lÃ­nea"'), isTrue);
  }
  debugPrint('SECUREPLAN_PROBE export=$extension bytes=${bytes.length}');
}

Future<void> _activate(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump(const Duration(milliseconds: 200));
  final widget = tester.widget(finder);
  final VoidCallback? pressed = switch (widget) {
    ButtonStyleButton button => button.onPressed,
    IconButton button => button.onPressed,
    FloatingActionButton button => button.onPressed,
    ListTile tile => tile.onTap,
    _ => null,
  };
  expect(pressed, isNotNull);
  pressed!();
  await tester.pump();
}

Future<void> _waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 45),
}) {
  return _waitUntil(
    tester,
    () => finder.evaluate().isNotEmpty,
    timeout: timeout,
  );
}

Future<void> _waitUntil(
  WidgetTester tester,
  bool Function() ready, {
  Duration timeout = const Duration(seconds: 45),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (ready()) {
      return;
    }
  }
  fail(
    'La interfaz no llegÃ³ al estado esperado. Visible: ${_debugTexts(tester)}',
  );
}

String _debugTexts(WidgetTester tester) {
  final texts = tester
      .widgetList<Text>(find.byType(Text))
      .map((widget) => widget.data ?? '')
      .where((value) => value.trim().length > 2)
      .toList();
  final tail = texts.length <= 12 ? texts : texts.sublist(texts.length - 12);
  return tail.join(' | ');
}
