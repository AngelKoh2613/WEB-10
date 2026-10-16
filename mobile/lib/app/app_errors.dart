import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

void installFlutterErrorHandlers() {
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    previous?.call(details);
  };
  ErrorWidget.builder = (details) {
    return const Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: Text('Ocurrió un error al mostrar esta pantalla.'),
      ),
    );
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    FlutterError.reportError(
      FlutterErrorDetails(exception: error, stack: stack),
    );
    return true;
  };
}
