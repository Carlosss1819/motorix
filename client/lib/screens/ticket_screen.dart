import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../models/payment.dart';
import '../models/ticket.dart';
import '../providers/load_status.dart';
import '../providers/ticket_provider.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/messages.dart';
import '../utils/print_service.dart';
import '../widgets/common_views.dart';
import '../widgets/payment_status_chip.dart';

/// Argumento de la ruta del ticket: el comprobante ya cargado o la orden de
/// la que debe abrirse (generándolo si aún no existe, HU4).
class TicketScreenArgs {
  const TicketScreenArgs({this.ticket, this.ordenId = 0});

  final Ticket? ticket;
  final int ordenId;
}

/// Visualización del ticket de servicio con formato de comprobante (HU4,
/// FR-007/FR-008). El botón «Imprimir» delega en el diálogo de impresión del
/// navegador o del sistema (D3, CA-5); no se genera ningún PDF y el
/// comprobante no contiene datos de tarjeta ni credenciales (RN-14).
class TicketScreen extends StatefulWidget {
  const TicketScreen({super.key, required this.args});

  final TicketScreenArgs args;

  @override
  State<TicketScreen> createState() => _TicketScreenState();
}

class _TicketScreenState extends State<TicketScreen> {
  late final TicketProvider _tickets;

  @override
  void initState() {
    super.initState();
    _tickets = context.read<TicketProvider>();
    final Ticket? inicial = widget.args.ticket;
    // En post-frame para no notificar a los oyentes (la orden) durante la
    // construcción de esta ruta.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (inicial != null) {
        _tickets.mostrar(inicial);
      } else {
        _tickets.abrir(widget.args.ordenId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final TicketProvider tickets = context.watch<TicketProvider>();

    Widget contenido;
    if (tickets.status == LoadStatus.ready && tickets.ticket != null) {
      contenido = _buildComprobante(tickets.ticket!);
    } else if (tickets.status == LoadStatus.error) {
      // Entre ellos el 409 de una orden sin pago aprobado: se muestra el
      // mensaje del backend («primero debe registrarse el pago», E5).
      contenido = ErrorView(mensaje: tickets.error ?? AppMessages.unexpectedError);
    } else {
      contenido = const LoadingView(mensaje: 'Cargando ticket…');
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
            contenido,
          ],
        ),
      ),
    );
  }

  /// Comprobante completo: encabezado con folio, datos del taller, cliente y
  /// vehículo, servicios con sus refacciones, subtotales, total, pago y
  /// emisión (FR-007).
  Widget _buildComprobante(Ticket ticket) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final MotorixColors colors = context.motorixColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text('Ticket de servicio', style: textTheme.titleLarge),
            ),
            PaymentStatusChip(estado: ticket.estadoPago),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          ticket.folio,
          key: const Key('ticket-folio'),
          style: textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.xl),
        AppPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              DetailRow(label: 'Taller', value: ticket.taller.nombre),
              DetailRow(label: 'Dirección', value: ticket.taller.direccion),
              DetailRow(label: 'Teléfono', value: ticket.taller.telefono),
              DetailRow(label: 'Cliente', value: ticket.cliente.nombre),
              DetailRow(label: 'Teléfono del cliente', value: ticket.cliente.telefono),
              DetailRow(label: 'Vehículo', value: ticket.vehiculo.etiqueta),
              DetailRow(label: 'Placas', value: ticket.vehiculo.placas),
              DetailRow(
                label: 'Kilometraje',
                value: Formatters.mileage(ticket.vehiculo.kilometraje),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (int index = 0; index < ticket.servicios.length; index++)
                _buildServicio(ticket.servicios[index], index),
              if (ticket.servicios.isEmpty)
                Text(
                  'Sin servicios registrados.',
                  style: textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              DetailRow(
                label: 'Subtotal mano de obra',
                value: Formatters.money(ticket.subtotalManoDeObra),
              ),
              DetailRow(
                label: 'Subtotal refacciones',
                value: Formatters.money(ticket.subtotalRefacciones),
              ),
              DetailRow(
                key: const Key('ticket-total'),
                label: 'Total',
                value: Formatters.money(ticket.total),
              ),
              DetailRow(
                label: 'Método de pago',
                value: paymentMethodLabel(ticket.metodoPago),
              ),
              DetailRow(
                label: 'Estado del pago',
                value: paymentStatusLabel(ticket.estadoPago),
              ),
              DetailRow(label: 'Fecha', value: ticket.fecha),
              DetailRow(label: 'Emitido por', value: ticket.emitidoPor),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton.icon(
          key: const Key('boton-imprimir'),
          onPressed: () => imprimirComprobante(
            context,
            texto: _textoPlano(ticket),
          ),
          icon: const Icon(
            LucideIcons.printer,
            size: AppMetrics.iconSizeSmall,
          ),
          label: const Text('Imprimir'),
        ),
      ],
    );
  }

  /// Servicio con su mano de obra y sus refacciones anidadas (FR-007).
  Widget _buildServicio(TicketServiceLine servicio, int index) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final MotorixColors colors = context.motorixColors;

    return Padding(
      key: Key('ticket-servicio-$index'),
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(servicio.descripcion, style: textTheme.bodyMedium),
          Text(
            'Mano de obra: ${Formatters.money(servicio.manoDeObra)}',
            style: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
          ),
          for (int posicion = 0;
              posicion < servicio.refacciones.length;
              posicion++)
            _buildRefaccion(servicio.refacciones[posicion], index, posicion),
        ],
      ),
    );
  }

  Widget _buildRefaccion(
    TicketPartLine refaccion,
    int servicio,
    int posicion,
  ) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final MotorixColors colors = context.motorixColors;
    final String codigo =
        refaccion.codigo == null || refaccion.codigo!.isEmpty
            ? ''
            : '${refaccion.codigo} · ';

    return Padding(
      key: Key('ticket-refaccion-$servicio-$posicion'),
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Text(
        '${refaccion.cantidad} × $codigo${refaccion.nombre} — '
        '${Formatters.money(refaccion.precioUnitario)} · '
        'Subtotal ${Formatters.money(refaccion.subtotal)}',
        style: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
      ),
    );
  }

  /// Copia textual del comprobante para la impresión de escritorio
  /// (print_service_stub.dart), sin datos sensibles (RN-14).
  String _textoPlano(Ticket ticket) {
    final StringBuffer buffer = StringBuffer()
      ..writeln('${ticket.taller.nombre} — ${ticket.taller.direccion}')
      ..writeln('Tel. ${ticket.taller.telefono}')
      ..writeln('Ticket ${ticket.folio}')
      ..writeln('Fecha: ${ticket.fecha}')
      ..writeln(
        'Cliente: ${ticket.cliente.nombre} (${ticket.cliente.telefono})',
      )
      ..writeln(
        'Vehículo: ${ticket.vehiculo.etiqueta} · '
        'Placas ${ticket.vehiculo.placas} · '
        '${Formatters.mileage(ticket.vehiculo.kilometraje)}',
      )
      ..writeln('')
      ..writeln('Servicios:');

    for (final TicketServiceLine servicio in ticket.servicios) {
      buffer.writeln(
        '  ${servicio.descripcion} — ${Formatters.money(servicio.manoDeObra)}',
      );
      for (final TicketPartLine refaccion in servicio.refacciones) {
        buffer.writeln(
          '    ${refaccion.cantidad} × ${refaccion.nombre} — '
          '${Formatters.money(refaccion.subtotal)}',
        );
      }
    }

    buffer
      ..writeln('')
      ..writeln(
        'Subtotal mano de obra: ${Formatters.money(ticket.subtotalManoDeObra)}',
      )
      ..writeln(
        'Subtotal refacciones: ${Formatters.money(ticket.subtotalRefacciones)}',
      )
      ..writeln('Total: ${Formatters.money(ticket.total)}')
      ..writeln(
        'Pago: ${paymentMethodLabel(ticket.metodoPago)} — '
        '${paymentStatusLabel(ticket.estadoPago)}',
      )
      ..writeln('Emitido por ${ticket.emitidoPor} el ${ticket.emitidoEn}');

    return buffer.toString();
  }
}
