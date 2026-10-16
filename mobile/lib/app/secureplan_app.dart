import 'package:flutter/material.dart';
import 'package:secureplan_mobile/core/config/app_config.dart';
import 'package:secureplan_mobile/core/theme/app_theme.dart';
import 'package:secureplan_mobile/features/auth/presentation/auth_gate.dart';

class SecurePlanApp extends StatelessWidget {
  const SecurePlanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const AuthGate(),
    );
  }
}
