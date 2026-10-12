import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../models/enums.dart';
import '../models/user_record.dart';
import '../providers/load_status.dart';
import '../providers/shell_provider.dart';
import '../providers/users_provider.dart';
import '../services/api_client.dart';
import '../services/users_service.dart';
import '../utils/app_theme.dart';
import '../utils/messages.dart';
import '../utils/validators.dart';
import '../widgets/common_views.dart';
import '../widgets/confirm_dialog.dart';

/// Lista de usuarios (US2): solo el administrador la puede abrir; el backend
/// vuelve a validar cada operación.
class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  late final ShellProvider _shell;
  late final UsersProvider _users;
  String _lastQuery = '';

  @override
  void initState() {
    super.initState();
    _shell = context.read<ShellProvider>();
    _users = context.read<UsersProvider>();
    _lastQuery = _shell.queryFor(SearchHints.users);
    _shell.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _users.load();
    });
  }

  void _onSearchChanged() {
    final String query = _shell.queryFor(SearchHints.users);
    if (query == _lastQuery) {
      return;
    }
    setState(() => _lastQuery = query);
  }

  @override
  void dispose() {
    _shell.removeListener(_onSearchChanged);
    super.dispose();
  }

  List<UserRecord> _filtrados(List<UserRecord> items) {
    final String query = _lastQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return items;
    }
    return items
        .where((UserRecord user) =>
            user.username.toLowerCase().contains(query) ||
            user.email.toLowerCase().contains(query))
        .toList();
  }

  Future<void> _showCreateDialog() async {
    final UserRecord? creado = await showAppDialog<UserRecord>(
      context: context,
      builder: (BuildContext dialogContext) => const _CreateUserDialog(),
    );
    if (creado == null || !mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Usuario "${creado.username}" creado correctamente.'),
      ),
    );
  }

  Future<void> _showRoleDialog(UserRecord user) async {
    final String? nuevoRol = await showAppDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => _ChangeRoleDialog(
        rolInicial: user.rol,
        username: user.username,
      ),
    );
    if (nuevoRol == null || !mounted) {
      return;
    }
    try {
      await _users.changeRole(user.id, nuevoRol);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Rol de ${user.username} cambiado a ${Rol.label(nuevoRol)}.',
          ),
        ),
      );
    } on ApiException catch (e) {
      _mostrarError(e.mensaje);
    } catch (_) {
      _mostrarError(AppMessages.unexpectedError);
    }
  }

  Future<void> _deactivate(UserRecord user) async {
    final bool ok = await showConfirmDialog(
      context,
      titulo: 'Desactivar usuario',
      mensaje: '¿Seguro que quieres desactivar a ${user.username}? '
          'Su sesión se cerrará de inmediato y no podrá iniciar sesión '
          'hasta que vuelvas a activarlo.',
      confirmarLabel: 'Confirmar',
      cancelarLabel: 'Cancelar',
      destructive: true,
    );
    if (!ok || !mounted) {
      return;
    }
    try {
      await _users.setStatus(user.id, activo: false);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Usuario ${user.username} desactivado.')),
      );
    } on ApiException catch (e) {
      _mostrarError(e.mensaje);
    } catch (_) {
      _mostrarError(AppMessages.unexpectedError);
    }
  }

  Future<void> _activate(UserRecord user) async {
    try {
      await _users.setStatus(user.id, activo: true);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Usuario ${user.username} activado.')),
      );
    } on ApiException catch (e) {
      _mostrarError(e.mensaje);
    } catch (_) {
      _mostrarError(AppMessages.unexpectedError);
    }
  }

  void _mostrarError(String mensaje) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final UsersProvider users = context.watch<UsersProvider>();
    final TextTheme textTheme = Theme.of(context).textTheme;
    final List<UserRecord> visibles = _filtrados(users.items);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              FilledButton.icon(
                onPressed: _showCreateDialog,
                icon: const Icon(
                  LucideIcons.userPlus,
                  size: AppMetrics.iconSizeSmall,
                ),
                label: const Text('Crear usuario'),
              ),
              const Spacer(),
              Text(_counterText(users, visibles), style: textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(child: _buildBody(users, visibles)),
        ],
      ),
    );
  }

  String _counterText(UsersProvider users, List<UserRecord> visibles) {
    if (users.status != LoadStatus.ready) {
      return '';
    }
    final int total = visibles.length;
    return total == 1 ? '1 usuario' : '$total usuarios';
  }

  Widget _buildBody(UsersProvider users, List<UserRecord> visibles) {
    switch (users.status) {
      case LoadStatus.idle:
      case LoadStatus.loading:
        return const LoadingView(mensaje: 'Cargando usuarios…');
      case LoadStatus.error:
        return ErrorView(
          mensaje: users.error ?? AppMessages.unexpectedError,
          onRetry: _users.reload,
        );
      case LoadStatus.ready:
        if (visibles.isEmpty) {
          return EmptyView(
            mensaje: _lastQuery.isEmpty
                ? 'Todavía no hay usuarios registrados.'
                : 'No se encontraron usuarios que coincidan con '
                      '"$_lastQuery".',
            actionLabel: 'Crear usuario',
            onAction: _showCreateDialog,
          );
        }
        return _buildTable(visibles);
    }
  }

  Widget _buildTable(List<UserRecord> items) {
    final MotorixColors colors = context.motorixColors;
    return AppPanel(
      padding: EdgeInsets.zero,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const <DataColumn>[
            DataColumn(label: Text('Usuario')),
            DataColumn(label: Text('Correo')),
            DataColumn(label: Text('Rol')),
            DataColumn(label: Text('Estado')),
            DataColumn(label: Text('Acciones')),
          ],
          rows: <DataRow>[
            for (final UserRecord user in items) _buildRow(user, colors),
          ],
        ),
      ),
    );
  }

  DataRow _buildRow(UserRecord user, MotorixColors colors) {
    return DataRow(
      color: WidgetStateProperty.resolveWith<Color?>(
        (Set<WidgetState> states) =>
            states.contains(WidgetState.hovered) ? colors.primarySoft : null,
      ),
      cells: <DataCell>[
        DataCell(Text(user.username)),
        DataCell(Text(user.email)),
        DataCell(Text(user.rolLabel)),
        DataCell(StatusChip(activo: user.isActive)),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              IconButton(
                tooltip: 'Cambiar rol',
                onPressed: () => _showRoleDialog(user),
                icon: const Icon(
                  LucideIcons.userCog,
                  size: AppMetrics.iconSizeSmall,
                ),
              ),
              user.isActive
                  ? IconButton(
                      tooltip: 'Desactivar usuario',
                      onPressed: () => _deactivate(user),
                      icon: Icon(
                        LucideIcons.ban,
                        size: AppMetrics.iconSizeSmall,
                        color: colors.danger,
                      ),
                    )
                  : IconButton(
                      tooltip: 'Activar usuario',
                      onPressed: () => _activate(user),
                      icon: const Icon(
                        LucideIcons.userCheck,
                        size: AppMetrics.iconSizeSmall,
                      ),
                    ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Diálogo de alta de usuario con rol asignado.
class _CreateUserDialog extends StatefulWidget {
  const _CreateUserDialog();

  @override
  State<_CreateUserDialog> createState() => _CreateUserDialogState();
}

class _CreateUserDialogState extends State<_CreateUserDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  String _rol = Rol.receptionist;
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final FormState? form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final UserRecord creado = await context.read<UsersProvider>().create(
            NewUser(
              username: _usernameController.text.trim(),
              email: _emailController.text.trim(),
              rol: _rol,
              contrasena: _passwordController.text,
            ),
          );
      if (!mounted) {
        return;
      }
      Navigator.pop(context, creado);
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
    return AlertDialog(
      title: const Text('Crear usuario'),
      content: SizedBox(
        width: AppMetrics.formDialogWidth,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (_error != null) ...<Widget>[
                FormErrorBanner(mensaje: _error!),
                const SizedBox(height: AppSpacing.md),
              ],
              TextFormField(
                controller: _usernameController,
                enabled: !_saving,
                textCapitalization: TextCapitalization.none,
                decoration: const InputDecoration(
                  labelText: 'Nombre de usuario *',
                  hintText: 'Ej. recepcion2',
                  prefixIcon: Icon(
                    LucideIcons.userRound,
                    size: AppMetrics.iconSizeSmall,
                  ),
                ),
                validator: (String? value) =>
                    Validators.required(value, 'el nombre de usuario'),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _emailController,
                enabled: !_saving,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Correo electrónico *',
                  hintText: 'Ej. recepcion2@motorix.local',
                  prefixIcon: Icon(
                    LucideIcons.mail,
                    size: AppMetrics.iconSizeSmall,
                  ),
                ),
                validator: (String? value) {
                  final String? requerido =
                      Validators.required(value, 'el correo electrónico');
                  if (requerido != null) {
                    return requerido;
                  }
                  return Validators.email(value);
                },
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _passwordController,
                enabled: !_saving,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Contraseña inicial *',
                  hintText: 'Mínimo 8 caracteres con mayúscula, minúscula y número',
                  prefixIcon: Icon(
                    LucideIcons.keyRound,
                    size: AppMetrics.iconSizeSmall,
                  ),
                ),
                validator: Validators.password,
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String>(
                initialValue: _rol,
                decoration: const InputDecoration(
                  labelText: 'Rol *',
                  prefixIcon: Icon(
                    LucideIcons.shieldCheck,
                    size: AppMetrics.iconSizeSmall,
                  ),
                ),
                items: <DropdownMenuItem<String>>[
                  for (final String rol in Rol.values)
                    DropdownMenuItem<String>(
                      value: rol,
                      child: Text(Rol.label(rol)),
                    ),
                ],
                onChanged: _saving
                    ? null
                    : (String? value) => setState(() => _rol = value ?? _rol),
              ),
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.sm,
        AppSpacing.xl,
        AppSpacing.lg,
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: const Text('Crear usuario'),
        ),
      ],
    );
  }
}

/// Diálogo para cambiar el rol de un usuario.
class _ChangeRoleDialog extends StatefulWidget {
  const _ChangeRoleDialog({required this.rolInicial, required this.username});

  final String rolInicial;
  final String username;

  @override
  State<_ChangeRoleDialog> createState() => _ChangeRoleDialogState();
}

class _ChangeRoleDialogState extends State<_ChangeRoleDialog> {
  late String _rol;

  @override
  void initState() {
    super.initState();
    _rol = widget.rolInicial;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Cambiar rol'),
      content: SizedBox(
        width: AppMetrics.formDialogWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Selecciona el nuevo rol de ${widget.username}. El cambio se '
              'aplica en su siguiente operación.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.lg),
            DropdownButtonFormField<String>(
              initialValue: _rol,
              decoration: const InputDecoration(labelText: 'Rol'),
              items: <DropdownMenuItem<String>>[
                for (final String rol in Rol.values)
                  DropdownMenuItem<String>(
                    value: rol,
                    child: Text(Rol.label(rol)),
                  ),
              ],
              onChanged: (String? value) =>
                  setState(() => _rol = value ?? _rol),
            ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.sm,
        AppSpacing.xl,
        AppSpacing.lg,
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _rol),
          child: const Text('Confirmar'),
        ),
      ],
    );
  }
}
