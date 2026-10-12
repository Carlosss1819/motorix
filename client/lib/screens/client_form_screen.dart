import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../models/client.dart';
import '../providers/clients_provider.dart';
import '../services/api_client.dart';
import '../services/clients_service.dart';
import '../utils/app_theme.dart';
import '../utils/messages.dart';
import '../utils/validators.dart';
import '../widgets/common_views.dart';
import '../widgets/confirm_dialog.dart';

/// Argumento de la ruta de alta o edición de cliente.
class ClientFormArgs {
  const ClientFormArgs({this.client});

  /// Si se pasa un cliente, el formulario entra en modo edición (US4).
  final Client? client;
}

/// Formulario de cliente: alta (US3) y edición (US4).
///
/// Nombre y teléfono son obligatorios; el correo es opcional.
class ClientFormScreen extends StatefulWidget {
  const ClientFormScreen({super.key, this.client});

  final Client? client;

  @override
  State<ClientFormScreen> createState() => _ClientFormScreenState();
}

class _ClientFormScreenState extends State<ClientFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombreController;
  late final TextEditingController _telefonoController;
  late final TextEditingController _emailController;

  String _nombreInicial = '';
  String _telefonoInicial = '';
  String _emailInicial = '';

  String? _error;
  bool _saving = false;

  bool get _esEdicion => widget.client != null;

  bool get _dirty =>
      _nombreController.text != _nombreInicial ||
      _telefonoController.text != _telefonoInicial ||
      _emailController.text != _emailInicial;

  @override
  void initState() {
    super.initState();
    final Client? client = widget.client;
    _nombreController = TextEditingController(text: client?.nombre ?? '');
    _telefonoController = TextEditingController(text: client?.telefono ?? '');
    _emailController = TextEditingController(text: client?.email ?? '');
    _nombreInicial = _nombreController.text;
    _telefonoInicial = _telefonoController.text;
    _emailInicial = _emailController.text;
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _telefonoController.dispose();
    _emailController.dispose();
    super.dispose();
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
    Navigator.pop(context);
  }

  Future<void> _save({bool confirmar = false}) async {
    final FormState? form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final String nombre = _nombreController.text.trim();
    final String telefono = _telefonoController.text.trim();
    final String email = _emailController.text.trim();
    final String? emailOrNull = email.isEmpty ? null : email;
    final ClientsProvider provider = context.read<ClientsProvider>();

    try {
      if (_esEdicion) {
        await provider.update(
          id: widget.client!.id,
          nombre: nombre,
          telefono: telefono,
          email: emailOrNull,
        );
        if (!mounted) {
          return;
        }
        setState(() => _saving = false);
        _finalizar('Cliente actualizado correctamente.');
      } else {
        final ClientCreateResult resultado = await provider.create(
          nombre: nombre,
          telefono: telefono,
          email: emailOrNull,
          confirmar: confirmar,
        );

        if (resultado.needsConfirmation) {
          if (!mounted) {
            return;
          }
          setState(() => _saving = false);
          final bool aceptar = await showConfirmDialog(
            context,
            titulo: 'Teléfono repetido',
            mensaje: '${resultado.aviso} '
                '¿Quieres registrar el cliente de todos modos?',
            confirmarLabel: 'Confirmar',
          );
          if (!aceptar || !mounted) {
            return;
          }
          await _save(confirmar: true);
          return;
        }

        if (!mounted) {
          return;
        }
        setState(() => _saving = false);
        _finalizar('Cliente registrado correctamente.');
      }
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

  void _finalizar(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje)),
    );
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

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
              const BackAction(),
              const SizedBox(height: AppSpacing.lg),
              Text(
                _esEdicion ? 'Editar cliente' : 'Registrar cliente',
                style: textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                _esEdicion
                    ? 'Actualiza los datos del cliente. Sus vehículos '
                      'asociados se conservan.'
                    : 'Nombre y teléfono son obligatorios; el correo es '
                      'opcional.',
                style: textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.xl),
              AppPanel(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (_error != null) ...<Widget>[
                        FormErrorBanner(mensaje: _error!),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                      TextFormField(
                        controller: _nombreController,
                        enabled: !_saving,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Nombre completo *',
                          prefixIcon: Icon(
                            LucideIcons.userRound,
                            size: AppMetrics.iconSizeSmall,
                          ),
                        ),
                        validator: (String? value) =>
                            Validators.required(value, 'el nombre'),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      TextFormField(
                        controller: _telefonoController,
                        enabled: !_saving,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Teléfono *',
                          hintText: 'Ej. 5512345678',
                          prefixIcon: Icon(
                            LucideIcons.phone,
                            size: AppMetrics.iconSizeSmall,
                          ),
                        ),
                        validator: (String? value) =>
                            Validators.required(value, 'el teléfono'),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      TextFormField(
                        controller: _emailController,
                        enabled: !_saving,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Correo electrónico (opcional)',
                          hintText: 'Ej. cliente@correo.com',
                          prefixIcon: Icon(
                            LucideIcons.mail,
                            size: AppMetrics.iconSizeSmall,
                          ),
                        ),
                        validator: Validators.email,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      FormActions(
                        onCancel: _confirmExit,
                        onSave: _save,
                        saveLabel:
                            _esEdicion ? 'Guardar cambios' : 'Registrar cliente',
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
