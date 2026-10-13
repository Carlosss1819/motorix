import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../models/enums.dart';
import '../models/service_order.dart';
import '../providers/auth_provider.dart';
import '../providers/load_status.dart';
import '../providers/service_orders_provider.dart';
import '../services/api_client.dart';
import '../utils/app_routes.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/messages.dart';
import '../widgets/common_views.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/status_chip.dart';
import 'client_detail_screen.dart';
import 'vehicle_detail_screen.dart';

/// Argumento de la ruta de detalle de una orden.
class ServiceOrderDetailArgs {
  const ServiceOrderDetailArgs({required this.orderId});

  final int orderId;
}

/// Ficha de la orden de servicio con cliente, vehículo y estado (HU1,
/// escenario 3: cliente, vehículo, motivo, estado y fecha).
class ServiceOrderDetailScreen extends StatefulWidget {
  const ServiceOrderDetailScreen({super.key, required this.orderId});

  final int orderId;

  @override
  State<ServiceOrderDetailScreen> createState() =>
      _ServiceOrderDetailScreenState();
}

class _ServiceOrderDetailScreenState extends State<ServiceOrderDetailScreen> {
  late final ServiceOrdersProvider _orders;

  /// El selector de asignación es de recepción/administración (FR-009); el
  /// mecánico solo consulta su orden.
  late final bool _esMecanico;

  /// El contenido de la orden (diagnóstico, servicios, repuestos y
  /// recomendaciones) lo registran el mecánico y el administrador (FR-022).
  late final bool _esAdmin;

  List<MechanicOption> _mecanicos = const <MechanicOption>[];
  bool _cargandoMecanicos = false;
  String? _errorMecanicos;
  bool _guardandoAsignacion = false;

  // Campos del contenido de la orden (US4).
  final TextEditingController _diagnosticoController = TextEditingController();
  final TextEditingController _recomendacionesController =
      TextEditingController();
  final TextEditingController _servicioController = TextEditingController();
  final TextEditingController _duracionController = TextEditingController();
  final TextEditingController _precioController = TextEditingController();
  final TextEditingController _repuestoController = TextEditingController();
  final TextEditingController _cantidadController = TextEditingController();

  /// Los campos se precargan una sola vez cuando llega la ficha; lo que el
  /// usuario escriba y no guarde se descarta al salir (FR-019).
  bool _camposContenidoCargados = false;
  bool _guardandoDiagnostico = false;
  bool _guardandoRecomendaciones = false;
  bool _guardandoServicio = false;
  bool _guardandoRepuesto = false;

  @override
  void initState() {
    super.initState();
    _orders = context.read<ServiceOrdersProvider>();
    final String rol = context.read<AuthProvider>().user?.rol ?? '';
    _esMecanico = rol == Rol.mechanic;
    _esAdmin = rol == Rol.admin;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _orders.loadDetail(widget.orderId);
      if (!_esMecanico) {
        _cargarMecanicos();
      }
    });
  }

  @override
  void dispose() {
    _diagnosticoController.dispose();
    _recomendacionesController.dispose();
    _servicioController.dispose();
    _duracionController.dispose();
    _precioController.dispose();
    _repuestoController.dispose();
    _cantidadController.dispose();
    super.dispose();
  }

  Future<void> _cargarMecanicos() async {
    setState(() {
      _cargandoMecanicos = true;
      _errorMecanicos = null;
    });
    try {
      final List<MechanicOption> lista = await _orders.loadMechanics();
      if (!mounted) {
        return;
      }
      setState(() {
        _mecanicos = lista;
        _cargandoMecanicos = false;
      });
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMecanicos = e.mensaje;
        _cargandoMecanicos = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMecanicos = AppMessages.unexpectedError;
        _cargandoMecanicos = false;
      });
    }
  }

  /// Asigna o desasigna con confirmación previa (Principio VIII). El `409` del
  /// backend se muestra tal cual, explicando por qué no se pudo (FR-009).
  Future<void> _asignar(ServiceOrder order, int? mecanicoId) async {
    final bool confirmado = await showConfirmDialog(
      context,
      titulo:
          mecanicoId == null ? 'Desasignar mecánico' : 'Asignar mecánico',
      mensaje: mecanicoId == null
          ? 'La orden #${order.id} quedará sin mecánico asignado. ¿Continuar?'
          : 'Asignar la orden #${order.id} al mecánico elegido. Podrás '
              'reasignarla mientras no esté cerrada. ¿Continuar?',
      destructive: mecanicoId == null,
    );
    if (!confirmado || !mounted) {
      return;
    }

    setState(() => _guardandoAsignacion = true);
    try {
      await _orders.assign(id: order.id, mecanicoId: mecanicoId);
      if (!mounted) {
        return;
      }
      setState(() => _guardandoAsignacion = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            mecanicoId == null
                ? 'Mecánico desasignado correctamente.'
                : 'Mecánico asignado correctamente.',
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _guardandoAsignacion = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.mensaje)),
      );
    }
  }

  /// Muestra un aviso breve con un mensaje en español.
  void _mostrarAviso(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
  }

  /// El contenido lo registran el mecánico —sobre sus órdenes— y el
  /// administrador (FR-022); una orden entregada es inmutable (FR-016),
  /// donde el backend responde `409`.
  bool _puedeEditarContenido(ServiceOrder order) =>
      (_esMecanico || _esAdmin) && order.abierta;

  /// Guarda el diagnóstico como borrador o de forma definitiva (FR-011). Lo
  /// que no se guarda se descarta al salir de la pantalla (FR-019).
  Future<void> _guardarDiagnostico(
    ServiceOrder order, {
    required bool borrador,
  }) async {
    final String texto = _diagnosticoController.text.trim();
    if (texto.isEmpty) {
      _mostrarAviso('El diagnóstico no puede quedar vacío.');
      return;
    }

    setState(() => _guardandoDiagnostico = true);
    try {
      await _orders.saveDiagnosis(
        id: order.id,
        texto: texto,
        borrador: borrador,
      );
      if (!mounted) {
        return;
      }
      _diagnosticoController.text = texto;
      setState(() => _guardandoDiagnostico = false);
      _mostrarAviso(
        borrador
            ? 'Diagnóstico guardado como borrador.'
            : 'Diagnóstico guardado.',
      );
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _guardandoDiagnostico = false);
      _mostrarAviso(e.mensaje);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _guardandoDiagnostico = false);
      _mostrarAviso(AppMessages.unexpectedError);
    }
  }

  /// Agrega un servicio con su mano de obra (FR-012) tras validar en cliente.
  Future<void> _agregarServicio(ServiceOrder order) async {
    final String descripcion = _servicioController.text.trim();
    final String duracionTexto = _duracionController.text.trim();
    final String precioTexto = _precioController.text.trim();
    final int? duracion = int.tryParse(duracionTexto);
    final double? precio =
        precioTexto.isEmpty ? null : double.tryParse(precioTexto);

    if (descripcion.isEmpty ||
        duracion == null ||
        duracion <= 0 ||
        (precioTexto.isNotEmpty && (precio == null || precio < 0))) {
      _mostrarAviso(
        'Revisa la descripción, la duración (minutos mayores a cero) y el '
        'precio del servicio.',
      );
      return;
    }

    setState(() => _guardandoServicio = true);
    try {
      await _orders.addService(
        id: order.id,
        descripcion: descripcion,
        duracionMinutos: duracion,
        precio: precio,
      );
      if (!mounted) {
        return;
      }
      _servicioController.clear();
      _duracionController.clear();
      _precioController.clear();
      setState(() => _guardandoServicio = false);
      _mostrarAviso('Servicio agregado a la orden.');
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _guardandoServicio = false);
      _mostrarAviso(e.mensaje);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _guardandoServicio = false);
      _mostrarAviso(AppMessages.unexpectedError);
    }
  }

  /// Elimina un servicio con su mano de obra, con confirmación previa
  /// (Principio VIII).
  Future<void> _eliminarServicio(
    ServiceOrder order,
    OrderServiceItem servicio,
  ) async {
    final bool confirmado = await showConfirmDialog(
      context,
      titulo: 'Eliminar servicio',
      mensaje:
          'Se quitará "${servicio.descripcion}" y su mano de obra de la '
          'orden #${order.id}. Esta acción no se puede deshacer. ¿Continuar?',
      destructive: true,
    );
    if (!confirmado || !mounted) {
      return;
    }

    try {
      await _orders.removeService(id: order.id, servicioId: servicio.id);
      if (!mounted) {
        return;
      }
      _mostrarAviso('Servicio eliminado.');
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      _mostrarAviso(e.mensaje);
    } catch (_) {
      if (!mounted) {
        return;
      }
      _mostrarAviso(AppMessages.unexpectedError);
    }
  }

  /// Agrega un repuesto usado en la orden (RN-06: sin tocar el inventario).
  Future<void> _agregarRepuesto(ServiceOrder order) async {
    final String descripcion = _repuestoController.text.trim();
    final String cantidadTexto = _cantidadController.text.trim();
    final int? cantidad =
        cantidadTexto.isEmpty ? 1 : int.tryParse(cantidadTexto);

    if (descripcion.isEmpty || cantidad == null || cantidad < 1) {
      _mostrarAviso(
        'Revisa la descripción y la cantidad del repuesto (mínimo 1).',
      );
      return;
    }

    setState(() => _guardandoRepuesto = true);
    try {
      await _orders.addPart(
        id: order.id,
        descripcion: descripcion,
        cantidad: cantidad,
      );
      if (!mounted) {
        return;
      }
      _repuestoController.clear();
      _cantidadController.clear();
      setState(() => _guardandoRepuesto = false);
      _mostrarAviso('Repuesto registrado en la orden.');
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _guardandoRepuesto = false);
      _mostrarAviso(e.mensaje);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _guardandoRepuesto = false);
      _mostrarAviso(AppMessages.unexpectedError);
    }
  }

  /// Elimina un repuesto de la orden con confirmación previa.
  Future<void> _eliminarRepuesto(ServiceOrder order, OrderPart repuesto) async {
    final bool confirmado = await showConfirmDialog(
      context,
      titulo: 'Eliminar repuesto',
      mensaje:
          'Se quitará "${repuesto.descripcion}" de la orden #${order.id}. '
          '¿Continuar?',
      destructive: true,
    );
    if (!confirmado || !mounted) {
      return;
    }

    try {
      await _orders.removePart(id: order.id, repuestoId: repuesto.id);
      if (!mounted) {
        return;
      }
      _mostrarAviso('Repuesto eliminado.');
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      _mostrarAviso(e.mensaje);
    } catch (_) {
      if (!mounted) {
        return;
      }
      _mostrarAviso(AppMessages.unexpectedError);
    }
  }

  /// Guarda las recomendaciones para la entrega (FR-013).
  Future<void> _guardarRecomendaciones(ServiceOrder order) async {
    final String texto = _recomendacionesController.text.trim();
    if (texto.isEmpty) {
      _mostrarAviso('Las recomendaciones no pueden quedar vacías.');
      return;
    }

    setState(() => _guardandoRecomendaciones = true);
    try {
      await _orders.saveRecommendations(id: order.id, texto: texto);
      if (!mounted) {
        return;
      }
      _recomendacionesController.text = texto;
      setState(() => _guardandoRecomendaciones = false);
      _mostrarAviso('Recomendaciones guardadas.');
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _guardandoRecomendaciones = false);
      _mostrarAviso(e.mensaje);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _guardandoRecomendaciones = false);
      _mostrarAviso(AppMessages.unexpectedError);
    }
  }

  /// Panel de asignación (US3/FR-009): oculto para el mecánico y para las
  /// órdenes cerradas, donde el backend responde `409`.
  Widget _buildAsignacion(ServiceOrder order) {
    if (_esMecanico || !order.editable) {
      return const SizedBox.shrink();
    }
    final TextTheme textTheme = Theme.of(context).textTheme;
    final MotorixColors colors = context.motorixColors;
    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Asignación de mecánico', style: textTheme.titleMedium),
          const SizedBox(height: AppSpacing.md),
          if (_errorMecanicos != null)
            Text(
              _errorMecanicos!,
              style: textTheme.bodySmall?.copyWith(color: colors.danger),
            )
          else if (_cargandoMecanicos)
            const SizedBox(
              width: AppMetrics.spinnerSize,
              height: AppMetrics.spinnerSize,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            DropdownButtonFormField<int?>(
              // La clave reinicia el selector cuando cambia la asignación.
              key: ValueKey<String>('mecanico-${order.mecanicoId}'),
              initialValue: order.mecanicoId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Mecánico asignado',
                prefixIcon: Icon(
                  LucideIcons.userRound,
                  size: AppMetrics.iconSizeSmall,
                ),
              ),
              items: <DropdownMenuItem<int?>>[
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('Sin asignar'),
                ),
                // El mecánico actual puede estar inactivo: se muestra igual.
                if (order.mecanicoId != null &&
                    !_mecanicos.any(
                      (MechanicOption m) => m.id == order.mecanicoId,
                    ))
                  DropdownMenuItem<int?>(
                    value: order.mecanicoId,
                    child: Text(order.mecanico ?? ''),
                  ),
                for (final MechanicOption mechanic in _mecanicos)
                  DropdownMenuItem<int?>(
                    value: mechanic.id,
                    child: Text(mechanic.username),
                  ),
              ],
              onChanged: _guardandoAsignacion
                  ? null
                  : (int? value) {
                      if (value == order.mecanicoId) {
                        return;
                      }
                      _asignar(order, value);
                    },
            ),
        ],
      ),
    );
  }

  /// Sección de diagnóstico (HU4, FR-011): editable para el mecánico y el
  /// administrador mientras la orden no se entregue; un diagnóstico en
  /// borrador queda marcado visualmente hasta confirmarlo (FR-011).
  Widget _buildDiagnostico(ServiceOrder order) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final MotorixColors colors = context.motorixColors;
    final bool editable = _puedeEditarContenido(order);
    final String guardado = order.diagnostico ?? '';

    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text('Diagnóstico', style: textTheme.titleMedium),
              ),
              if (order.diagnosticoBorrador)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: colors.warningSoft,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(
                      color: colors.warning.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    'Borrador sin confirmar',
                    style: textTheme.labelSmall?.copyWith(
                      color: colors.warning,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (editable)
            TextField(
              key: const Key('campo-diagnostico'),
              controller: _diagnosticoController,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Diagnóstico del vehículo',
                hintText: 'Describe lo que encontraste en la revisión…',
              ),
            )
          else
            Text(
              guardado.isEmpty ? 'Sin diagnóstico registrado.' : guardado,
              style: textTheme.bodyMedium,
            ),
          if (editable) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                OutlinedButton(
                  onPressed: _guardandoDiagnostico
                      ? null
                      : () => _guardarDiagnostico(order, borrador: true),
                  child: const Text('Guardar borrador'),
                ),
                FilledButton(
                  onPressed: _guardandoDiagnostico
                      ? null
                      : () => _guardarDiagnostico(order, borrador: false),
                  child: const Text('Guardar y continuar'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Servicios con su mano de obra (FR-012, R-13): el mecánico da de alta y
  /// da de baja con confirmación; una orden entregada ya no admite cambios
  /// (FR-016), donde el backend responde `409`.
  Widget _buildServicios(ServiceOrder order) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final MotorixColors colors = context.motorixColors;
    final bool editable = _puedeEditarContenido(order);

    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Servicios y mano de obra', style: textTheme.titleMedium),
          const SizedBox(height: AppSpacing.md),
          if (order.servicios.isEmpty)
            Text('Sin servicios registrados.', style: textTheme.bodySmall)
          else
            for (final OrderServiceItem servicio in order.servicios)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            servicio.descripcion,
                            style: textTheme.bodyMedium,
                          ),
                          if (servicio.manoDeObra != null)
                            Text(
                              _etiquetaManoDeObra(servicio.manoDeObra!),
                              style: textTheme.bodySmall?.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (editable)
                      IconButton(
                        tooltip: 'Eliminar servicio',
                        icon: const Icon(
                          LucideIcons.trash2,
                          size: AppMetrics.iconSizeSmall,
                        ),
                        onPressed: () => _eliminarServicio(order, servicio),
                      ),
                  ],
                ),
              ),
          if (editable) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            TextField(
              key: const Key('campo-servicio'),
              controller: _servicioController,
              decoration: const InputDecoration(
                labelText: 'Descripción del servicio',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    key: const Key('campo-duracion'),
                    controller: _duracionController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Duración (min)',
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: TextField(
                    key: const Key('campo-precio'),
                    controller: _precioController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Precio (opcional)',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: _guardandoServicio
                    ? null
                    : () => _agregarServicio(order),
                icon: const Icon(
                  LucideIcons.plus,
                  size: AppMetrics.iconSizeSmall,
                ),
                label: const Text('Agregar servicio'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Etiqueta de la mano de obra: duración y precio cuando vino con precio.
  String _etiquetaManoDeObra(OrderLabor manoDeObra) {
    final String duracion = '${manoDeObra.duracionMinutos} min de mano de obra';
    final num? precio = manoDeObra.precio;
    if (precio == null) {
      return duracion;
    }
    return '$duracion · ${Formatters.money(precio)}';
  }

  /// Repuestos usados en la orden (RN-06): solo se registran junto a la
  /// orden; el control de stock es del Sprint 3.
  Widget _buildRepuestos(ServiceOrder order) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final bool editable = _puedeEditarContenido(order);

    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Repuestos utilizados', style: textTheme.titleMedium),
          const SizedBox(height: AppSpacing.md),
          if (order.repuestos.isEmpty)
            Text('Sin repuestos registrados.', style: textTheme.bodySmall)
          else
            for (final OrderPart repuesto in order.repuestos)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        '${repuesto.cantidad} × ${repuesto.descripcion}',
                        style: textTheme.bodyMedium,
                      ),
                    ),
                    if (editable)
                      IconButton(
                        tooltip: 'Eliminar repuesto',
                        icon: const Icon(
                          LucideIcons.trash2,
                          size: AppMetrics.iconSizeSmall,
                        ),
                        onPressed: () => _eliminarRepuesto(order, repuesto),
                      ),
                  ],
                ),
              ),
          if (editable) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    key: const Key('campo-repuesto'),
                    controller: _repuestoController,
                    decoration: const InputDecoration(
                      labelText: 'Descripción del repuesto',
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                SizedBox(
                  width: 120,
                  child: TextField(
                    key: const Key('campo-cantidad'),
                    controller: _cantidadController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Cantidad'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: _guardandoRepuesto
                    ? null
                    : () => _agregarRepuesto(order),
                icon: const Icon(
                  LucideIcons.plus,
                  size: AppMetrics.iconSizeSmall,
                ),
                label: const Text('Agregar repuesto'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Recomendaciones para la entrega (FR-013), visibles para todos y
  /// editables por el mecánico y el administrador.
  Widget _buildRecomendaciones(ServiceOrder order) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final bool editable = _puedeEditarContenido(order);
    final String guardadas = order.recomendaciones ?? '';

    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Recomendaciones para la entrega', style: textTheme.titleMedium),
          const SizedBox(height: AppSpacing.md),
          if (editable)
            TextField(
              key: const Key('campo-recomendaciones'),
              controller: _recomendacionesController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Recomendaciones',
                hintText: 'Indica qué debe revisar el cliente después…',
              ),
            )
          else
            Text(
              guardadas.isEmpty
                  ? 'Sin recomendaciones registradas.'
                  : guardadas,
              style: textTheme.bodyMedium,
            ),
          if (editable) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton(
                onPressed: _guardandoRecomendaciones
                    ? null
                    : () => _guardarRecomendaciones(order),
                child: const Text('Guardar recomendaciones'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _goToClient(int clienteId) {
    Navigator.pushNamed(
      context,
      Routes.clientDetail,
      arguments: ClientDetailArgs(clientId: clienteId),
    );
  }

  void _goToVehicle(int vehiculoId) {
    Navigator.pushNamed(
      context,
      Routes.vehicleDetail,
      arguments: VehicleDetailArgs(vehicleId: vehiculoId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ServiceOrdersProvider orders =
        context.watch<ServiceOrdersProvider>();

    switch (orders.detailStatus) {
      case LoadStatus.idle:
      case LoadStatus.loading:
        return const LoadingView(mensaje: 'Cargando orden…');
      case LoadStatus.error:
        return ErrorView(
          mensaje: orders.detailError ?? AppMessages.unexpectedError,
          onRetry: () => _orders.loadDetail(widget.orderId),
        );
      case LoadStatus.ready:
        final ServiceOrder? order = orders.selected;
        if (order == null) {
          return const ErrorView(mensaje: 'No se encontró la orden.');
        }
        return _buildContent(order);
    }
  }

  Widget _buildContent(ServiceOrder order) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    // Precarga una sola vez los campos con texto guardado; lo que el usuario
    // escriba y no guarde se descarta al salir de la pantalla (FR-019).
    if (!_camposContenidoCargados) {
      _diagnosticoController.text = order.diagnostico ?? '';
      _recomendacionesController.text = order.recomendaciones ?? '';
      _camposContenidoCargados = true;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppMetrics.contentMaxWidth),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const BackAction(),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Orden #${order.id}',
                    style: textTheme.titleLarge,
                  ),
                ),
                OrderStatusChip(estado: order.estado),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            AppPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Datos de la orden', style: textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.md),
                  DetailRow(label: 'Estado', value: orderStatusLabel(order.estado)),
                  DetailRow(label: 'Motivo de visita', value: order.motivoVisita),
                  DetailRow(
                    label: 'Fecha de ingreso',
                    value: Formatters.date(order.fechaIngreso),
                  ),
                  DetailRow(
                    label: 'Kilometraje',
                    value: Formatters.mileage(order.kilometrajeEntrada),
                  ),
                  DetailRow(
                    label: 'Mecánico',
                    value: order.mecanico ?? 'Sin asignar',
                  ),
                  if (order.fechaEntrega != null) ...<Widget>[
                    DetailRow(
                      label: 'Fecha de entrega',
                      value: Formatters.date(order.fechaEntrega),
                    ),
                  ],
                  if (order.notaCorreccionKilometraje.isNotEmpty) ...<Widget>[
                    DetailRow(
                      label: 'Corrección de kilometraje',
                      value: order.notaCorreccionKilometraje,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (!_esMecanico && order.editable) ...<Widget>[
              _buildAsignacion(order),
              const SizedBox(height: AppSpacing.lg),
            ],
            _buildDiagnostico(order),
            const SizedBox(height: AppSpacing.lg),
            _buildServicios(order),
            const SizedBox(height: AppSpacing.lg),
            _buildRepuestos(order),
            const SizedBox(height: AppSpacing.lg),
            _buildRecomendaciones(order),
            const SizedBox(height: AppSpacing.lg),
            AppPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Cliente', style: textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.md),
                  DetailRow(
                    label: 'Nombre',
                    value: order.cliente,
                    onTap: () => _goToClient(order.clienteId),
                  ),
                  DetailRow(
                    label: 'Teléfono',
                    value:
                        order.telefono.isEmpty
                            ? 'Sin teléfono registrado'
                            : order.telefono,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Vehículo', style: textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.md),
                  DetailRow(
                    label: 'Vehículo',
                    value: order.vehiculo,
                    onTap: () => _goToVehicle(order.vehiculoId),
                  ),
                  DetailRow(label: 'Placas', value: order.placas),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Selecciona el nombre del cliente o el vehículo para abrir su '
              'ficha.',
              style: textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
