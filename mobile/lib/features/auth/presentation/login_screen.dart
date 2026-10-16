import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:secureplan_mobile/core/config/app_config.dart';
import 'package:secureplan_mobile/features/auth/application/auth_controller.dart';
import 'package:secureplan_mobile/features/auth/domain/password_policy.dart';
import 'package:secureplan_mobile/features/auth/presentation/auth_form.dart';
import 'package:secureplan_mobile/features/auth/presentation/register_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  var _submitting = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final message = await ref
        .read(authControllerProvider.notifier)
        .login(email: _email.text, password: _password.text);
    if (!mounted) {
      return;
    }
    setState(() {
      _submitting = false;
      _error = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: AuthForm(
          title: AppConfig.appName,
          subtitle: 'Inicia sesión para continuar',
          formKey: _formKey,
          email: _email,
          password: _password,
          submitting: _submitting,
          error: _error,
          submitLabel: 'Iniciar sesión',
          passwordValidator: validateLoginPassword,
          onSubmit: _submit,
          footer: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  '¿Aún no tienes cuenta?',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              TextButton(
                onPressed: _submitting
                    ? null
                    : () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const RegisterScreen(),
                          ),
                        );
                      },
                child: const Text('Crear cuenta'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
