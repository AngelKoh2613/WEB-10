import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:secureplan_mobile/features/auth/application/auth_controller.dart';
import 'package:secureplan_mobile/features/auth/presentation/login_screen.dart';
import 'package:secureplan_mobile/presentation/shell/app_shell.dart';
import 'package:secureplan_mobile/shared/widgets/error_view.dart';
import 'package:secureplan_mobile/shared/widgets/loading_view.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);

    return auth.when(
      loading: () =>
          const Scaffold(body: LoadingView(message: 'Comprobando sesión')),
      error: (_, _) => Scaffold(
        body: ErrorView(
          title: 'No se pudo comprobar la sesión',
          message: 'Inténtalo de nuevo.',
          onRetry: () => ref.invalidate(authControllerProvider),
        ),
      ),
      data: (session) {
        if (session == null) {
          return const LoginScreen();
        }
        return const AppShell();
      },
    );
  }
}
