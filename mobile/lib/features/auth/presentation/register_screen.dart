import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:secureplan_mobile/features/auth/application/auth_controller.dart';
import 'package:secureplan_mobile/features/auth/domain/password_policy.dart';
import 'package:secureplan_mobile/features/auth/presentation/auth_form.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
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
        .register(email: _email.text, password: _password.text);
    if (!mounted) {
      return;
    }
    if (message == null && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
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
      appBar: AppBar(
        title: const Text('Crear cuenta'),
        backgroundColor: Colors.transparent,
        shape: const Border(),
      ),
      body: SafeArea(
        child: AuthForm(
          title: 'Registro',
          subtitle: 'Tu agenda se guarda cifrada en este dispositivo.',
          passwordHelper: 'Mínimo 10 caracteres, con una letra y un dígito.',
          formKey: _formKey,
          email: _email,
          password: _password,
          submitting: _submitting,
          error: _error,
          submitLabel: 'Registrarme',
          passwordValidator: (value) => validateNewPassword(value, _email.text),
          onSubmit: _submit,
        ),
      ),
    );
  }
}
