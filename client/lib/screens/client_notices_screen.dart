import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../models/client_notice.dart';
import '../providers/client_notices_provider.dart';
import '../providers/load_status.dart';
import '../utils/app_theme.dart';
import '../utils/messages.dart';
import '../widgets/app_table.dart';
import '../widgets/common_views.dart';
import '../widgets/confirm_dialog.dart';

/// Ancho desde el que la lista se muestra como tabla.
const double kClientNoticesTableWidth = 1000;

/// «Clientes por avisar» (Sprint 6, US7; contracts/ui-flutter.md): clientes a
/// los que hay que llamar, con su teléfono, y el registro de «avisado» una
/// sola vez por hecho. Solo ADMIN y RECEPTIONIST (el backend lo vuelve a
/// validar, RN-15).
class ClientNoticesScreen extends StatefulWidget {
  const ClientNoticesScreen({super.key});

  @override
  State<ClientNoticesScreen> createState() => _ClientNoticesScreenState();
}

class _ClientNoticesScreenState extends State<ClientNoticesScreen> {
  late final ClientNoticesProvider _avisos;

  @override
  void initState() {
    super.initState();
    _avisos = context.read<ClientNoticesProvider>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _avisos.load();
      }
    });
  }

  Future<void> _marcar(ClientNotice aviso) async {
    final bool confirmado = await showConfirmDialog(
      context,
      titulo: 'Marcar como avisado',
      mensaje: '¿Ya avisaste a ${aviso.clienteNombre}? '
          'Solo márcalo si de verdad le avisaste.',
    );
    if (!confirmado || !mounted) {
      return;
    }
    final MarkNotifiedResult resultado = await _avisos.markNotified(aviso);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          resultado.ok ? 'Aviso registrado' : resultado.mensaje ?? AppMessages.unexpectedError,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ClientNoticesProvider avisos = context.watch<ClientNoticesProvider>();
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: switch (avisos.status) {
        LoadStatus.idle || LoadStatus.loading =>
          const LoadingView(mensaje: 'Cargando clientes por avisar…'),
        LoadStatus.error => ErrorView(
            mensaje: avisos.error ?? AppMessages.unexpectedError,
            onRetry: avisos.load,
          ),
        LoadStatus.ready when avisos.items.isEmpty =>
          const EmptyView(mensaje: 'No hay clientes por avisar'),
        LoadStatus.ready => LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) =>
                constraints.maxWidth >= kClientNoticesTableWidth
                    ? _buildTable(avisos.items)
                    : _buildList(avisos.items),
          ),
      },
    );
  }

  Widget _buildTable(List<ClientNotice> items) {
    return SingleChildScrollView(
      child: AppPanel(
        padding: EdgeInsets.zero,
        child: FullWidthTable(
          columns: <DataColumn>[
            fluidColumn('Cliente y teléfono', weight: 1.5, minWidth: 150),
            fluidColumn('Vehículo', weight: 1.3, minWidth: 140),
            fluidColumn('Motivo', weight: 1, minWidth: 120),
            fluidColumn('Fecha', weight: 0.8, minWidth: 90),
            fluidColumn('Acciones', weight: 1.7, minWidth: 220),
          ],
          rows: <DataRow>[
            for (final ClientNotice aviso in items)
              DataRow(
                key: ValueKey<String>('cliente-aviso-${aviso.clave}'),
                cells: <DataCell>[
                  DataCell(
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(aviso.clienteNombre),
                        Text(aviso.clienteTelefono, style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                  DataCell(Text('${aviso.vehiculoDescripcion}\n${aviso.vehiculoPlacas}')),
                  DataCell(ClientNoticeReasonChip(aviso: aviso)),
                  DataCell(Text(aviso.fecha)),
                  DataCell(_MarkButton(aviso: aviso, onPressed: () => _marcar(aviso))),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(List<ClientNotice> items) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (BuildContext context, int index) {
        final ClientNotice aviso = items[index];
        return AppPanel(
          key: ValueKey<String>('cliente-aviso-${aviso.clave}'),
          expand: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(child: Text(aviso.clienteNombre, style: textTheme.titleSmall)),
                  ClientNoticeReasonChip(aviso: aviso),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text('Teléfono: ${aviso.clienteTelefono}', style: textTheme.bodyMedium),
              Text(
                '${aviso.vehiculoDescripcion} (${aviso.vehiculoPlacas}) · ${aviso.fecha}',
                style: textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerRight,
                child: _MarkButton(aviso: aviso, onPressed: () => _marcar(aviso)),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MarkButton extends StatelessWidget {
  const _MarkButton({required this.aviso, required this.onPressed});

  final ClientNotice aviso;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      key: Key('marcar-avisado-${aviso.clave}'),
      onPressed: onPressed,
      icon: const Icon(LucideIcons.phoneCall, size: AppMetrics.iconSizeSmall),
      label: const Text('Marcar como avisado'),
    );
  }
}

/// Chip del motivo con su color: vencido en `danger`, próximo en `warning`,
/// vehículo listo en `success` y cita de mañana en el color primario.
class ClientNoticeReasonChip extends StatelessWidget {
  const ClientNoticeReasonChip({super.key, required this.aviso});

  final ClientNotice aviso;

  @override
  Widget build(BuildContext context) {
    final MotorixColors colors = context.motorixColors;
    final (Color fondo, Color texto) = switch (aviso.motivo) {
      ClientNoticeReasons.mantVencido => (colors.dangerSoft, colors.danger),
      ClientNoticeReasons.mantProximo => (colors.warningSoft, colors.warning),
      ClientNoticeReasons.vehiculoListo => (colors.successSoft, colors.success),
      _ => (colors.primarySoft, colors.primary),
    };
    return Chip(
      label: Text(aviso.motivoTexto),
      backgroundColor: fondo,
      labelStyle: Theme.of(context).textTheme.labelSmall?.copyWith(color: texto),
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
    );
  }
}
