import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../models/app_user.dart';
import '../models/enums.dart';
import '../models/part.dart';
import '../models/payment.dart';
import '../models/service_order.dart';
import '../providers/auth_provider.dart';
import '../providers/load_status.dart';
import '../providers/parts_provider.dart';
import '../providers/payment_provider.dart';
import '../providers/service_orders_provider.dart';
import '../services/api_client.dart';
import '../utils/app_routes.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/messages.dart';
import '../widgets/common_views.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/payment_status_chip.dart';
import '../widgets/status_chip.dart';
import 'client_detail_screen.dart';
import 'payment_form_screen.dart';
import 'vehicle_detail_screen.dart';
import 'vehicle_history_screen.dart';

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

  /// Catálogo de refacciones del selector del panel de inventario (US7).
  late final PartsProvider _parts;

  /// Pagos y total de la orden para el bloque de cobro (HU1, Sprint 4); solo
  /// lo usan recepción y administración (FR-003, RN-15).
  late final PaymentsProvider _pagos;

  /// El selector de asignación es de recepción/administración (FR-009); el
  /// mecánico solo consulta su orden.
  late final bool _esMecanico;

  /// El contenido de la orden (diagnóstico, servicios, refacciones y
  /// recomendaciones) lo registran el mecánico y el administrador (FR-022);
  /// las refacciones, además, las manejan los tres roles (FR-027).
  late final bool _esAdmin;

  /// Identificador de la sesión actual: el bloque medio de transiciones de
  /// estado solo lo mueve el mecánico asignado a la orden (US5, R-03).
  late final int? _usuarioId;

  List<MechanicOption> _mecanicos = const <MechanicOption>[];
  bool _cargandoMecanicos = false;
  String? _errorMecanicos;
  bool _guardandoAsignacion = false;
  bool _cambiandoEstado = false;

  // Campos del contenido de la orden (US4).
  final TextEditingController _diagnosticoController = TextEditingController();
  final TextEditingController _recomendacionesController =
      TextEditingController();
  final TextEditingController _servicioController = TextEditingController();
  final TextEditingController _duracionController = TextEditingController();
  final TextEditingController _precioController = TextEditingController();
  final TextEditingController _cantidadController = TextEditingController();

  /// Refacción elegida en el selector del catálogo (US7, RN-6): el alta ya
  /// no acepta texto libre.
  int? _refaccionId;

  /// Los campos se precargan una sola vez cuando llega la ficha; lo que el
  /// usuario escriba y no guarde se descarta al salir (FR-019).
  bool _camposContenidoCargados = false;
  bool _guardandoDiagnostico = false;
  bool _guardandoRecomendaciones = false;
  bool _guardandoServicio = false;
  bool _guardandoRefaccion = false;

  @override
  void initState() {
    super.initState();
    _orders = context.read<ServiceOrdersProvider>();
    _parts = context.read<PartsProvider>();
    _pagos = context.read<PaymentsProvider>();
    final AppUser? usuario = context.read<AuthProvider>().user;
    final String rol = usuario?.rol ?? '';
    _esMecanico = rol == Rol.mechanic;
    _esAdmin = rol == Rol.admin;
    _usuarioId = usuario?.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _orders.loadDetail(widget.orderId);
      // El selector de refacciones (US7) muestra el stock vigente del
      // catálogo, que se refresca además después de cada alta o baja.
      _parts.loadCatalog();
      if (!_esMecanico) {
        _cargarMecanicos();
        // Historial de pagos y total vigente del bloque de cobro (HU1).
        _pagos.load(widget.orderId);
        _pagos.loadTotal(widget.orderId);
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

  /// Las refacciones de la orden las manejan los TRES roles sobre una orden
  /// abierta (FR-027): a diferencia del contenido, recepción también puede
  /// darlas de alta y de baja. El `403` de un mecánico en orden ajena y el
  /// `409` de una orden cerrada los resuelve el backend (RN-15, FR-026).
  bool _puedeEditarRefacciones(ServiceOrder order) => order.editable;

  /// Agrega una refacción del catálogo a la orden (FR-023): el stock se
  /// descuenta en el backend dentro de su transacción (RN-7, R-08).
  Future<void> _agregarRefaccion(ServiceOrder order) async {
    final String cantidadTexto = _cantidadController.text.trim();
    final int? cantidad =
        cantidadTexto.isEmpty ? 1 : int.tryParse(cantidadTexto);

    if (_refaccionId == null || cantidad == null || cantidad < 1) {
      _mostrarAviso(
        'Selecciona una refacción del catálogo y una cantidad de al menos 1.',
      );
      return;
    }

    setState(() => _guardandoRefaccion = true);
    try {
      await _orders.addPart(
        id: order.id,
        partId: _refaccionId!,
        cantidad: cantidad,
      );
      if (!mounted) {
        return;
      }
      _refaccionId = null;
      _cantidadController.clear();
      setState(() => _guardandoRefaccion = false);
      _mostrarAviso('Refacción registrada en la orden.');
      // El stock visible del selector cambió con la salida.
      _parts.loadCatalog();
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _guardandoRefaccion = false);
      _mostrarAviso(e.mensaje);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _guardandoRefaccion = false);
      _mostrarAviso(AppMessages.unexpectedError);
    }
  }

  /// Retira una refacción de la orden con confirmación obligatoria (Principio
  /// VIII): el backend repone el stock con una ENTRADA (FR-026, R-09).
  Future<void> _eliminarRefaccion(
    ServiceOrder order,
    OrderPart refaccion,
  ) async {
    final bool confirmado = await showConfirmDialog(
      context,
      titulo: 'Eliminar refacción',
      mensaje:
          'Se quitará "${refaccion.descripcion}" de la orden #${order.id} y se '
          'repondrá su stock. ¿Continuar?',
      destructive: true,
    );
    if (!confirmado || !mounted) {
      return;
    }

    try {
      await _orders.removePart(id: order.id, repuestoId: refaccion.id);
      if (!mounted) {
        return;
      }
      _mostrarAviso('Refacción retirada de la orden.');
      // El stock visible del selector cambió con la reposición.
      _parts.loadCatalog();
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

  /// Aplica la matriz de permisos R-03 / FR-022 del contrato: la entrega es
  /// de recepción o administración; el bloque medio, del mecánico asignado
  /// o administración.
  bool _puedeTransicionar(ServiceOrder order, String destino) {
    if (destino == 'ENTREGADO') {
      return !_esMecanico;
    }
    if (_esAdmin) {
      return true;
    }
    if (!_esMecanico) {
      return false;
    }
    return order.mecanicoId != null && order.mecanicoId == _usuarioId;
  }

  /// Cambia el estado de la orden (US5). Cerrar y entregar exigen
  /// confirmación previa (Principio VIII) y los errores del backend (`403`
  /// fuera de rol, `409` transición inválida) se muestran tal cual.
  Future<void> _cambiarEstado(ServiceOrder order, String destino) async {
    if (destino == 'ENTREGADO' || destino == 'TERMINADO') {
      final bool confirmado = await showConfirmDialog(
        context,
        titulo: destino == 'ENTREGADO' ? 'Entregar orden' : 'Cerrar orden',
        mensaje: destino == 'ENTREGADO'
            ? 'La orden #${order.id} se marcará como entregada y se '
                'registrará la fecha de entrega. ¿Continuar?'
            : 'La orden #${order.id} se cerrará como terminada y solo '
                'recepción podrá entregarla. ¿Continuar?',
        destructive: destino == 'ENTREGADO',
      );
      if (!confirmado || !mounted) {
        return;
      }
    }

    setState(() => _cambiandoEstado = true);
    try {
      await _orders.changeStatus(id: order.id, estado: destino);
      if (!mounted) {
        return;
      }
      setState(() => _cambiandoEstado = false);
      _mostrarAviso('La orden ahora está en ${orderStatusLabel(destino)}.');
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _cambiandoEstado = false);
      _mostrarAviso(e.mensaje);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _cambiandoEstado = false);
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

  /// Refacciones usadas en la orden (US7): salen del catálogo con su stock
  /// visible y el retiro siempre pide confirmación (FR-023 a FR-027).
  Widget _buildRefacciones(ServiceOrder order) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final PartsProvider parts = context.watch<PartsProvider>();
    final bool editable = _puedeEditarRefacciones(order);
    final List<Part> catalogo = parts.catalogo;
    // Tras un refresco el id elegido puede haber salido del catálogo.
    final int? valorSelector = catalogo.any((Part p) => p.id == _refaccionId)
        ? _refaccionId
        : null;

    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Refacciones utilizadas', style: textTheme.titleMedium),
          const SizedBox(height: AppSpacing.md),
          if (order.repuestos.isEmpty)
            Text('Sin refacciones registradas.', style: textTheme.bodySmall)
          else
            for (final OrderPart refaccion in order.repuestos)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        '${refaccion.cantidad} × ${refaccion.descripcion}',
                        style: textTheme.bodyMedium,
                      ),
                    ),
                    if (editable)
                      IconButton(
                        tooltip: 'Eliminar refacción',
                        icon: const Icon(
                          LucideIcons.trash2,
                          size: AppMetrics.iconSizeSmall,
                        ),
                        onPressed: () => _eliminarRefaccion(order, refaccion),
                      ),
                  ],
                ),
              ),
          if (editable) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: <Widget>[
                Expanded(
                  child: DropdownButtonFormField<int>(
                    key: const Key('selector-refaccion'),
                    initialValue: valorSelector,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Refacción del catálogo',
                    ),
                    hint: const Text('Selecciona una refacción'),
                    items: <DropdownMenuItem<int>>[
                      for (final Part parte in catalogo)
                        DropdownMenuItem<int>(
                          value: parte.id,
                          // Una refacción sin stock no se puede usar (RN-8).
                          enabled: parte.stockActual > 0,
                          child: Text(
                            '${parte.nombre} (${parte.codigo}) · '
                            'stock ${parte.stockActual}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (int? valor) =>
                        setState(() => _refaccionId = valor),
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
            const SizedBox(height: AppSpacing.xs),
            if (parts.cargandoCatalogo)
              Text('Cargando el catálogo de refacciones…', style: textTheme.bodySmall)
            else if (parts.errorCatalogo != null)
              Text(parts.errorCatalogo!, style: textTheme.bodySmall)
            else if (catalogo.isEmpty)
              Text('No hay refacciones activas en el catálogo.', style: textTheme.bodySmall)
            else
              Text(
                'El stock se descuenta al guardar y se repone al retirar.',
                style: textTheme.bodySmall,
              ),
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: _guardandoRefaccion
                    ? null
                    : () => _agregarRefaccion(order),
                icon: const Icon(
                  LucideIcons.plus,
                  size: AppMetrics.iconSizeSmall,
                ),
                label: const Text('Agregar refacción'),
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

  /// Panel de acciones de estado (US5, FR-014/FR-022): ofrece solo las
  /// transiciones del mapa R-02 que el rol puede hacer según la matriz R-03;
  /// está oculto cuando no hay ninguna acción disponible (p. ej. la orden
  /// entregada es terminal).
  Widget _buildAccionesEstado(ServiceOrder order) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final List<String> destinos = allowedOrderTransitions(order.estado)
        .where((String destino) => _puedeTransicionar(order, destino))
        .toList();
    if (destinos.isEmpty) {
      return const SizedBox.shrink();
    }

    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Acciones de estado', style: textTheme.titleMedium),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              for (final String destino in destinos)
                if (destino == 'ENTREGADO')
                  FilledButton(
                    onPressed: _cambiandoEstado
                        ? null
                        : () => _cambiarEstado(order, destino),
                    child: Text('Pasar a ${orderStatusLabel(destino)}'),
                  )
                else
                  OutlinedButton(
                    onPressed: _cambiandoEstado
                        ? null
                        : () => _cambiarEstado(order, destino),
                    child: Text('Pasar a ${orderStatusLabel(destino)}'),
                  ),
            ],
          ),
        ],
      ),
    );
  }

  /// Abre el formulario de cobro (HU1, FR-001) y refresca el historial de
  /// pagos al volver con el pago registrado.
  Future<void> _irACobro(ServiceOrder order) async {
    final dynamic registrado = await Navigator.pushNamed(
      context,
      Routes.paymentForm,
      arguments: PaymentFormArgs(ordenId: order.id),
    );
    if (registrado == true) {
      await _pagos.reload();
    }
  }

  /// Anulación de un pago por error de captura (FR-016, RN-15): confirmación
  /// obligatoria con motivo de 1 a 255 caracteres; el pago se conserva como
  /// historial con estado `ANULADO` (RN-9).
  Future<void> _anularPago(Payment pago) async {
    final String? motivo = await showAppDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => _AnnulPaymentDialog(pago: pago),
    );
    if (motivo == null) {
      return;
    }
    try {
      await _pagos.annul(id: pago.id, motivo: motivo);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pago anulado correctamente.')),
      );
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.mensaje)),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppMessages.unexpectedError)),
      );
    }
  }

  /// Confirmación manual de un cobro Mercado Pago pendiente (US3, FR-005,
  /// aclaración 3): el rol verifica el cobro en el panel del proveedor y
  /// marca el resultado tras confirmar. Aprobado liquida la orden; rechazado
  /// o cancelado la libera para otro intento (HU3-3, HU3-4). Nunca se piden
  /// ni se muestran datos de tarjeta (RN-14).
  Future<void> _confirmarPago(Payment pago, String estado) async {
    const Map<String, String> etiquetas = <String, String>{
      'PAGADO': 'Marcar como aprobado',
      'RECHAZADO': 'Marcar como rechazado',
      'CANCELADO': 'Cancelar cobro',
    };
    const Map<String, String> preguntas = <String, String>{
      'PAGADO':
          '¿Seguro que quieres marcar este cobro Mercado Pago como '
          'aprobado? La orden quedará liquidada.',
      'RECHAZADO':
          '¿Seguro que quieres marcar este cobro Mercado Pago como '
          'rechazado? La orden quedará libre para otro intento.',
      'CANCELADO':
          '¿Seguro que quieres cancelar este cobro Mercado Pago pendiente? '
          'La orden quedará libre para otro intento.',
    };
    const Map<String, String> avisos = <String, String>{
      'PAGADO': 'Cobro confirmado: el pago queda aprobado.',
      'RECHAZADO': 'Cobro marcado como rechazado.',
      'CANCELADO': 'Cobro cancelado.',
    };

    final bool seguro = await showConfirmDialog(
      context,
      titulo: etiquetas[estado]!,
      mensaje: preguntas[estado]!,
      confirmarLabel: 'Confirmar',
      destructive: estado != 'PAGADO',
    );
    if (!seguro) {
      return;
    }

    try {
      await _pagos.confirm(id: pago.id, estado: estado);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(avisos[estado]!)),
      );
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.mensaje)),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppMessages.unexpectedError)),
      );
    }
  }

  /// Bloque de cobro y pago (HU1/HU2/HU3): total vigente de la orden con su
  /// desglose resumido (FR-015), historial de pagos con monto, método, fecha
  /// y estado (SC-001) y, en órdenes `TERMINADO` sin cobro aprobado ni
  /// pendiente, el botón que abre el formulario (FR-004, FR-005). Un cobro
  /// Mercado Pago `PENDIENTE` muestra su referencia y enlace con las
  /// acciones de confirmación manual (aclaración 3). Solo recepción y
  /// administración (FR-003, RN-15); la anulación es exclusiva de ADMIN
  /// (FR-016).
  Widget _buildCobro(ServiceOrder order) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final MotorixColors colors = context.motorixColors;
    // watch para refrescar el bloque al registrar, confirmar o anular un pago.
    final PaymentsProvider pagos = context.watch<PaymentsProvider>();

    final bool liquidada = pagos.tienePagoAprobado;
    final bool pendiente = pagos.tienePagoPendiente;
    // Con un cobro Mercado Pago pendiente la orden está en disputa: no admite
    // otro intento hasta confirmarlo o rechazarlo (FR-005, 409 PAGO_PENDIENTE).
    final bool puedeCobrar =
        order.estado == 'TERMINADO' && !liquidada && !pendiente;

    String total = 'Calculando…';
    if (pagos.totalStatus == LoadStatus.ready && pagos.totalOrden != null) {
      total = Formatters.money(pagos.totalOrden!.total);
    } else if (pagos.totalStatus == LoadStatus.error) {
      total = 'Total no disponible';
    }

    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text('Cobro y pago', style: textTheme.titleMedium),
              ),
              Text(
                total,
                key: const Key('total-orden'),
                style: textTheme.titleMedium?.copyWith(color: colors.primary),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Total calculado con los precios vigentes: mano de obra + '
            'refacciones × cantidad.',
            style: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
          ),
          if (pagos.totalStatus == LoadStatus.error &&
              pagos.totalError != null) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Text(
              pagos.totalError!,
              style: textTheme.bodySmall?.copyWith(color: colors.danger),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          if (pagos.isLoading && pagos.items.isEmpty)
            const LoadingView(mensaje: 'Cargando pagos…')
          else if (pagos.status == LoadStatus.error)
            Text(
              pagos.error ?? AppMessages.unexpectedError,
              style: textTheme.bodySmall?.copyWith(color: colors.danger),
            )
          else if (pagos.items.isEmpty)
            Text(
              'Sin pagos registrados.',
              key: const Key('sin-pagos'),
              style: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
            )
          else
            for (final Payment pago in pagos.items)
              _buildFilaPago(pago, esAdmin: _esAdmin),
          if (puedeCobrar) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              key: const Key('boton-registrar-pago'),
              onPressed: () => _irACobro(order),
              icon: const Icon(
                LucideIcons.banknote,
                size: AppMetrics.iconSizeSmall,
              ),
              label: const Text('Registrar pago'),
            ),
          ] else if (pendiente) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Cobro Mercado Pago pendiente de confirmar.',
              key: const Key('cobro-pendiente'),
              style: textTheme.bodySmall?.copyWith(color: colors.warning),
            ),
          ] else if (liquidada) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Orden liquidada: ya tiene su pago aprobado.',
              style: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  /// Fila del historial de pagos: monto y método, fecha y quien lo registró,
  /// motivo de anulación si aplica, chip de estado y las acciones que este
  /// rol puede hacer (anular `PAGADO` solo ADMIN, FR-016; confirmar un
  /// Mercado Pago `PENDIENTE`, US3 FR-005).
  Widget _buildFilaPago(Payment pago, {required bool esAdmin}) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final MotorixColors colors = context.motorixColors;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${Formatters.money(pago.monto)} · '
                  '${paymentMethodLabel(pago.metodo)}',
                  key: Key('pago-${pago.id}'),
                  style: textTheme.bodyMedium,
                ),
                Text(
                  '${Formatters.dateTime(pago.fecha)} · '
                  '${pago.registradoPor.isEmpty ? 'sin usuario' : pago.registradoPor}',
                  style: textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                if (pago.motivoAnulacion != null &&
                    pago.motivoAnulacion!.isNotEmpty)
                  Text(
                    'Motivo de anulación: ${pago.motivoAnulacion}',
                    style: textTheme.bodySmall?.copyWith(color: colors.danger),
                  ),
                if (pago.estado == 'PENDIENTE') ...<Widget>[
                  if (pago.referenciaExterna != null &&
                      pago.referenciaExterna!.isNotEmpty)
                    Text(
                      'Referencia externa: ${pago.referenciaExterna}',
                      style: textTheme.bodySmall?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  if (pago.modoPasarela != null &&
                      pago.modoPasarela!.isNotEmpty)
                    Text(
                      'Pasarela: ${pago.modoPasarela}',
                      style: textTheme.bodySmall?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  if (pago.enlacePago != null && pago.enlacePago!.isNotEmpty)
                    Text(
                      'Enlace de pago: ${pago.enlacePago}',
                      style: textTheme.bodySmall?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    children: <Widget>[
                      FilledButton(
                        key: Key('aprobar-${pago.id}'),
                        onPressed: () => _confirmarPago(pago, 'PAGADO'),
                        child: const Text('Marcar como aprobado'),
                      ),
                      OutlinedButton(
                        key: Key('rechazar-${pago.id}'),
                        onPressed: () => _confirmarPago(pago, 'RECHAZADO'),
                        child: const Text('Marcar como rechazado'),
                      ),
                      OutlinedButton(
                        key: Key('cancelar-cobro-${pago.id}'),
                        onPressed: () => _confirmarPago(pago, 'CANCELADO'),
                        child: const Text('Cancelar cobro'),
                      ),
                    ],
                  ),
                ],
                if (esAdmin && pago.estaPagado)
                  TextButton(
                    onPressed: () => _anularPago(pago),
                    child: const Text('Anular pago'),
                  ),
              ],
            ),
          ),
          PaymentStatusChip(estado: pago.estado),
        ],
      ),
    );
  }

  /// Historial de cambios de estado (US5, FR-015): estado, usuario y fecha
  /// de cada transición registrada en el backend.
  Widget _buildHistorial(ServiceOrder order) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final MotorixColors colors = context.motorixColors;

    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Historial de cambios', style: textTheme.titleMedium),
          const SizedBox(height: AppSpacing.md),
          if (order.historial.isEmpty)
            Text('Sin cambios registrados.', style: textTheme.bodySmall)
          else
            for (final OrderHistoryEntry entrada in order.historial)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      entrada.de == null
                          ? 'Alta de la orden → ${orderStatusLabel(entrada.a)}'
                          : '${orderStatusLabel(entrada.de!)} → '
                              '${orderStatusLabel(entrada.a)}',
                      style: textTheme.bodyMedium,
                    ),
                    Text(
                      '${entrada.usuario} · ${_formatoFechaHora(entrada.fecha)}',
                      style: textTheme.bodySmall?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  /// Fecha ISO de la API ('AAAA-MM-DDTHH:MM:SS.sssZ') → 'DD/MM/YYYY HH:MM'
  /// en la zona horaria local del usuario.
  String _formatoFechaHora(String iso) {
    final DateTime? fecha = DateTime.tryParse(iso);
    if (fecha == null) {
      return iso;
    }
    final DateTime local = fecha.toLocal();
    String pad(int valor) => valor.toString().padLeft(2, '0');
    return '${pad(local.day)}/${pad(local.month)}/${local.year} '
        '${pad(local.hour)}:${pad(local.minute)}';
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

  /// Abre el historial del vehículo de la orden (US1, FR-004).
  void _goToVehicleHistory(ServiceOrder order) {
    Navigator.pushNamed(
      context,
      Routes.vehicleHistory,
      arguments: VehicleHistoryArgs(
        vehicleId: order.vehiculoId,
        vehicleLabel: order.vehiculo,
      ),
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

    // Transiciones que este rol puede hacer desde el estado actual (US5).
    final bool hayAccionesEstado = allowedOrderTransitions(order.estado)
        .any((String destino) => _puedeTransicionar(order, destino));

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
            if (hayAccionesEstado) ...<Widget>[
              _buildAccionesEstado(order),
              const SizedBox(height: AppSpacing.lg),
            ],
            if (!_esMecanico && order.editable) ...<Widget>[
              _buildAsignacion(order),
              const SizedBox(height: AppSpacing.lg),
            ],
            _buildDiagnostico(order),
            const SizedBox(height: AppSpacing.lg),
            _buildServicios(order),
            const SizedBox(height: AppSpacing.lg),
            _buildRefacciones(order),
            const SizedBox(height: AppSpacing.lg),
            _buildRecomendaciones(order),
            const SizedBox(height: AppSpacing.lg),
            // Bloque de cobro (HU1): historial y total junto al que se
            // muestran los pagos; oculto para el mecánico (FR-003, RN-15).
            if (!_esMecanico) ...<Widget>[
              _buildCobro(order),
              const SizedBox(height: AppSpacing.lg),
            ],
            _buildHistorial(order),
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
                  const SizedBox(height: AppSpacing.sm),
                  // Historial del vehículo (US1, FR-004): disponible también
                  // para el mecánico, cuya ficha de vehículo es de solo lectura.
                  OutlinedButton.icon(
                    onPressed: () => _goToVehicleHistory(order),
                    icon: const Icon(
                      LucideIcons.history,
                      size: AppMetrics.iconSizeSmall,
                    ),
                    label: const Text('Ver historial del vehículo'),
                  ),
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

/// Diálogo de anulación de un pago (FR-016): pide el motivo obligatorio de
/// 1 a 255 caracteres y solo se cierra con "Anular pago" cuando ya se
/// escribió (mismo patrón que la cancelación de citas).
class _AnnulPaymentDialog extends StatefulWidget {
  const _AnnulPaymentDialog({required this.pago});

  final Payment pago;

  @override
  State<_AnnulPaymentDialog> createState() => _AnnulPaymentDialogState();
}

class _AnnulPaymentDialogState extends State<_AnnulPaymentDialog> {
  late final TextEditingController _motivoController;
  String? _error;

  @override
  void initState() {
    super.initState();
    _motivoController = TextEditingController();
  }

  @override
  void dispose() {
    _motivoController.dispose();
    super.dispose();
  }

  void _confirmar() {
    final String motivo = _motivoController.text.trim();
    if (motivo.isEmpty) {
      setState(() => _error = 'El motivo de la anulación es obligatorio.');
      return;
    }
    if (motivo.length > 255) {
      setState(() => _error = 'El motivo no puede pasar de 255 caracteres.');
      return;
    }
    Navigator.of(context).pop(motivo);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Anular pago'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '¿Seguro que quieres anular el pago de '
            '${Formatters.money(widget.pago.monto)} del '
            '${Formatters.dateTime(widget.pago.fecha)}? El pago queda como '
            'historial y la orden vuelve a estar libre para registrar un '
            'pago nuevo correcto.',
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            key: const Key('campo-motivo-anulacion'),
            controller: _motivoController,
            maxLength: 255,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Motivo de la anulación *',
              hintText: 'Ej. Monto capturado incorrectamente',
              errorText: _error,
            ),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Volver'),
        ),
        FilledButton(
          key: const Key('boton-confirmar-anulacion'),
          onPressed: _confirmar,
          child: const Text('Anular pago'),
        ),
      ],
    );
  }
}
