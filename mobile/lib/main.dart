import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:secureplan_mobile/app/app_errors.dart';
import 'package:secureplan_mobile/app/secureplan_app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  installFlutterErrorHandlers();
  runApp(const ProviderScope(child: SecurePlanApp()));
}
