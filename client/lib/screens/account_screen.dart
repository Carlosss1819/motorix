import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/api_client.dart';
import '../utils/app_theme.dart';
import '../utils/messages.dart';
import '../utils/validators.dart';
import '../widgets/common_views.dart';
import '../widgets/confirm_dialog.dart';

/// Mi cuenta (FR-008): datos de la sesión y cambio de contraseña con la
/// política mínima de 8 caracteres, mayúscula, minúscula y número.
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _actualController = TextEditingController();
  final TextEditingController _nuevaController = TextEditingController();
  final TextEditingController _confirmarController = TextEditingController();

  String? _error;
  bool _saving = false;

  bool get _dirty =>
      _actualController.text.isNotEmpty ||
      _nuevaController.text.isNotEmpty ||
      _confirmarController.text.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _actualController.addListener(_onChanged);
    _nuevaController.addListener(_onChanged);
    _confirmarController.addListener(_onChanged);
  }

  void _onChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _actualController.dispose();
    _nuevaController.dispose();
    _confirmarController.dispose();
    super.dispose();
  }

  void _clear() {
    _actualController.clear();
    _nuevaController.clear();
    _confirmarController.clear();
  }

  /// Salir pidiendo confirmación si hay cambios sin guardar (8.5).
  Future<void> _confirmExit() async {
    if (!_dirty) {
      Navigator.maybePop(context);
      return;
    }
    final bool ok = await confirmDiscardChanges(context);
    if (!ok || !mounted) {
      return;
    }
    _clear();
    Navigator.pop(context);
  }

  Future<void> _save() async {
    final FormState? form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final AuthProvider auth = context.read<AuthProvider>();
    try {
      await auth.changePassword(
        actual: _actualController.text,
        nueva: _nuevaController.text,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contraseña actualizada correctamente.')),
      );
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _error = e.mensaje;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _error = AppMessages.unexpectedError;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final AuthProvider auth = context.watch<AuthProvider>();
    final TextTheme textTheme = Theme.of(context).textTheme;
    final Map<String, bool> requisitos =
        Validators.passwordRequirements(_nuevaController.text);

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) {
          return;
        }
        _confirmExit();
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(maxWidth: AppMetrics.contentMaxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Mi cuenta', style: textTheme.titleLarge),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Consulta tus datos y cambia tu contraseña cuando la '
                'necesites.',
                style: textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.xl),
              AppPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Datos de la cuenta', style: textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.md),
                    DetailRow(
                      label: 'Usuario',
                      value: auth.user?.username ?? 'Sin datos',
                    ),
                    DetailRow(
                      label: 'Correo',
                      value: auth.user?.email ?? 'Sin datos',
                    ),
                    DetailRow(
                      label: 'Rol',
                      value: auth.user?.rolLabel ?? 'Sin datos',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppPanel(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('Cambiar contraseña',
                          style: textTheme.titleMedium),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'La nueva contraseña debe tener al menos 8 caracteres, '
                        'una mayúscula, una minúscula y un número.',
                        style: textTheme.bodySmall,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      if (_error != null) ...<Widget>[
                        FormErrorBanner(mensaje: _error!),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                      TextFormField(
                        controller: _actualController,
                        enabled: !_saving,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Contraseña actual',
                          prefixIcon: Icon(
                            LucideIcons.lock,
                            size: AppMetrics.iconSizeSmall,
                          ),
                        ),
                        validator: (String? value) =>
                            Validators.required(value, 'la contraseña actual'),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      TextFormField(
                        controller: _nuevaController,
                        enabled: !_saving,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Nueva contraseña',
                          prefixIcon: Icon(
                            LucideIcons.keyRound,
                            size: AppMetrics.iconSizeSmall,
                          ),
                        ),
                        validator: Validators.password,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _PasswordRequirements(requirements: requisitos),
                      const SizedBox(height: AppSpacing.lg),
                      TextFormField(
                        controller: _confirmarController,
                        enabled: !_saving,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Repetir nueva contraseña',
                          prefixIcon: Icon(
                            LucideIcons.keyRound,
                            size: AppMetrics.iconSizeSmall,
                          ),
                        ),
                        validator: (String? value) {
                          if (value == null || value.isEmpty) {
                            return 'Repite la nueva contraseña.';
                          }
                          if (value != _nuevaController.text) {
                            return 'Las contraseñas no coinciden.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      FormActions(
                        onCancel: _clear,
                        onSave: _save,
                        saveLabel: 'Guardar contraseña',
                        saving: _saving,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lista viva de los requisitos de la política de contraseña.
class _PasswordRequirements extends StatelessWidget {
  const _PasswordRequirements({required this.requirements});

  final Map<String, bool> requirements;

  @override
  Widget build(BuildContext context) {
    final MotorixColors colors = context.motorixColors;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final MapEntry<String, bool> entry in requirements.entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Row(
              children: <Widget>[
                Icon(
                  entry.value
                      ? LucideIcons.circleCheck
                      : LucideIcons.circleX,
                  size: AppMetrics.iconSizeSmall,
                  color: entry.value ? colors.success : colors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  entry.key,
                  style: textTheme.bodySmall?.copyWith(
                    color: entry.value ? colors.success : colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
