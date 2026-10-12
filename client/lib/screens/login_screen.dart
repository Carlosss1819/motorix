import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../utils/app_routes.dart';
import '../utils/app_theme.dart';
import '../utils/validators.dart';
import '../widgets/common_views.dart';

/// Pantalla de inicio de sesión (US1): un solo campo para usuario o correo,
/// más la contraseña.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _identifierController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final FormState? form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    final AuthProvider auth = context.read<AuthProvider>();
    final bool ok = await auth.login(
      identificador: _identifierController.text,
      contrasena: _passwordController.text,
    );

    if (!ok || !mounted) {
      return;
    }
    Navigator.pushNamedAndRemoveUntil(
      context,
      Routes.home,
      (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final MotorixColors colors = context.motorixColors;
    final AuthProvider auth = context.watch<AuthProvider>();
    final TextTheme textTheme = Theme.of(context).textTheme;
    final String? mensajeError = auth.error ?? auth.sessionMessage;

    return Scaffold(
      backgroundColor: colors.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppMetrics.loginPanelWidth,
            ),
            child: AppPanel(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Icon(LucideIcons.wrench, color: colors.primary),
                        const SizedBox(width: AppSpacing.sm),
                        Text('Motorix', style: textTheme.titleLarge),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Inicia sesión para continuar al sistema del taller.',
                      style: textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    if (mensajeError != null) ...<Widget>[
                      FormErrorBanner(mensaje: mensajeError),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                    TextFormField(
                      controller: _identifierController,
                      enabled: !auth.isLoading,
                      textInputAction: TextInputAction.next,
                      autofillHints: const <String>[AutofillHints.username],
                      onChanged: (_) => auth.clearError(),
                      decoration: const InputDecoration(
                        labelText: 'Usuario o correo',
                        hintText: 'Ej. admin o admin@motorix.local',
                        prefixIcon: Icon(
                          LucideIcons.userRound,
                          size: AppMetrics.iconSizeSmall,
                        ),
                      ),
                      validator: (String? value) =>
                          Validators.required(value, 'el usuario o correo'),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    TextFormField(
                      controller: _passwordController,
                      enabled: !auth.isLoading,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      autofillHints: const <String>[AutofillHints.password],
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: 'Contraseña',
                        prefixIcon: const Icon(
                          LucideIcons.lock,
                          size: AppMetrics.iconSizeSmall,
                        ),
                        suffixIcon: IconButton(
                          tooltip: _obscurePassword
                              ? 'Mostrar contraseña'
                              : 'Ocultar contraseña',
                          onPressed: () => setState(() {
                            _obscurePassword = !_obscurePassword;
                          }),
                          icon: Icon(
                            _obscurePassword
                                ? LucideIcons.eye
                                : LucideIcons.eyeOff,
                            size: AppMetrics.iconSizeSmall,
                          ),
                        ),
                      ),
                      validator: (String? value) =>
                          Validators.required(value, 'la contraseña'),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: auth.isLoading ? null : _submit,
                        icon: auth.isLoading
                            ? SizedBox(
                                width: AppMetrics.spinnerSize,
                                height: AppMetrics.spinnerSize,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: colors.surface,
                                ),
                              )
                            : const Icon(
                                LucideIcons.logIn,
                                size: AppMetrics.iconSizeSmall,
                              ),
                        label: Text(
                          auth.isLoading ? 'Ingresando…' : 'Ingresar',
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      '¿Olvidaste tu contraseña? Solicítala al administrador.',
                      style: textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
