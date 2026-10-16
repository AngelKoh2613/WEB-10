import 'package:flutter/material.dart';
import 'package:secureplan_mobile/core/theme/app_theme.dart';
import 'package:secureplan_mobile/features/auth/domain/password_policy.dart';
import 'package:secureplan_mobile/shared/widgets/brand_mark.dart';
import 'package:secureplan_mobile/shared/widgets/inline_message.dart';

class AuthForm extends StatefulWidget {
  const AuthForm({
    super.key,
    required this.title,
    required this.subtitle,
    required this.formKey,
    required this.email,
    required this.password,
    required this.submitting,
    required this.error,
    required this.submitLabel,
    required this.passwordValidator,
    required this.onSubmit,
    this.passwordHelper,
    this.footer,
  });

  final String title;
  final String subtitle;
  final GlobalKey<FormState> formKey;
  final TextEditingController email;
  final TextEditingController password;
  final bool submitting;
  final String? error;
  final String submitLabel;
  final FormFieldValidator<String> passwordValidator;
  final VoidCallback onSubmit;
  final String? passwordHelper;
  final Widget? footer;

  @override
  State<AuthForm> createState() => _AuthFormState();
}

class _AuthFormState extends State<AuthForm> {
  var _obscure = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.xxl,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Form(
            key: widget.formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: BrandMark(),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(widget.title, style: theme.textTheme.headlineSmall),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  widget.subtitle,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                TextFormField(
                  controller: widget.email,
                  enabled: !widget.submitting,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(
                    labelText: 'Correo',
                    prefixIcon: Icon(Icons.mail_outline),
                  ),
                  validator: validateEmail,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: AppSpacing.lg),
                TextFormField(
                  controller: widget.password,
                  enabled: !widget.submitting,
                  obscureText: _obscure,
                  autofillHints: const [AutofillHints.password],
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    helperText: widget.passwordHelper,
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      tooltip: _obscure
                          ? 'Mostrar contraseña'
                          : 'Ocultar contraseña',
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  validator: widget.passwordValidator,
                  onFieldSubmitted: (_) => widget.onSubmit(),
                ),
                if (widget.error != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  InlineMessage.error(widget.error!),
                ],
                const SizedBox(height: AppSpacing.xl),
                FilledButton(
                  onPressed: widget.submitting ? null : widget.onSubmit,
                  child: widget.submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(widget.submitLabel),
                ),
                if (widget.footer != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  widget.footer!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
