import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../models/order_total.dart';
import '../models/payment.dart';
import '../providers/load_status.dart';
import '../providers/payment_provider.dart';
import '../services/api_client.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/messages.dart';
import '../utils/validators.dart';
import '../widgets/common_views.dart';

/// Argumento de la ruta del formulario de pago.
class PaymentFormArgs {
  const PaymentFormArgs({required this.ordenId});

  final int ordenId;
}

/// Formulario de registro de pago de una orden (HU1, FR-001 a FR-004).
///
/// Muestra el total calculado en backend con los precios vigentes y su
/// desglose (FR-015, T062) y precarga el monto con ese total, de modo que el
/// valor enviado siempre coincide con el que exige el backend; un `409` del
/// cobro (`ORDEN_YA_LIQUIDADA`, `MONTO_NO_COINCIDE`…) se muestra tal cual.
class PaymentFormScreen extends StatefulWidget {
  const PaymentFormScreen({super.key, required this.args});

  final PaymentFormArgs args;

  @override
  State<PaymentFormScreen> createState() => _PaymentFormScreenState();
}

class _PaymentFormScreenState extends State<PaymentFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _montoController;
  late final TextEditingController _fechaController;

  String? _metodo;
  String? _error;
  bool _saving = false;

  /// El monto solo se precarga una vez con el total del backend; lo que el
  /// usuario escriba después no se sobreescribe (FR-019).
  bool _montoPrecargado = false;

  @override
  void initState() {
    super.initState();
    _montoController = TextEditingController();
    _fechaController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.read<PaymentsProvider>().loadTotal(widget.args.ordenId);
    });
  }

  @override
  void dispose() {
    _montoController.dispose();
    _fechaController.dispose();
    super.dispose();
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

    final PaymentsProvider pagos = context.read<PaymentsProvider>();
    try {
      final num monto = double.parse(_montoController.text.trim());
      await pagos.register(
        ordenId: widget.args.ordenId,
        monto: monto,
        metodo: _metodo!,
        fecha: _fechaController.text.trim(),
      );

      if (!mounted) {
        return;
      }
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pago registrado correctamente.')),
      );
      Navigator.pop(context, true);
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

  /// Total y desglose vigentes de la orden, con estados de carga y error.
  Widget _buildTotal(PaymentsProvider pagos) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final MotorixColors colors = context.motorixColors;

    final Widget encabezado = Text('Total de la orden', style: textTheme.titleMedium);

    if (pagos.totalStatus == LoadStatus.loading ||
        pagos.totalStatus == LoadStatus.idle) {
      return AppPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            encabezado,
            const SizedBox(height: AppSpacing.md),
            Text('Calculando el total con los precios vigentes…',
                style: textTheme.bodySmall),
          ],
        ),
      );
    }

    if (pagos.totalStatus == LoadStatus.error) {
      return AppPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            encabezado,
            const SizedBox(height: AppSpacing.md),
            Text(
              pagos.totalError ?? AppMessages.unexpectedError,
              style: textTheme.bodySmall?.copyWith(color: colors.danger),
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: () => pagos.loadTotal(widget.args.ordenId),
              icon: const Icon(
                LucideIcons.refreshCw,
                size: AppMetrics.iconSizeSmall,
              ),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    final OrderTotal? total = pagos.totalOrden;
    if (total == null) {
      return AppPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            encabezado,
            const SizedBox(height: AppSpacing.md),
            Text('Sin total disponible.', style: textTheme.bodySmall),
          ],
        ),
      );
    }

    // Precarga del monto con el total calculado en backend (FR-015, SC-001).
    if (!_montoPrecargado) {
      _montoPrecargado = true;
      _montoController.text = total.total.toStringAsFixed(2);
    }

    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          encabezado,
          const SizedBox(height: AppSpacing.md),
          if (total.desglose.manoDeObra.isEmpty &&
              total.desglose.refacciones.isEmpty)
            Text(
              'La orden aún no tiene servicios ni refacciones registrados.',
              style: textTheme.bodySmall,
            )
          else ...<Widget>[
            if (total.desglose.manoDeObra.isNotEmpty) ...<Widget>[
              Text('Mano de obra', style: textTheme.labelMedium),
              const SizedBox(height: AppSpacing.xs),
              for (final LaborBreakdownLine linea in total.desglose.manoDeObra)
                _buildLineaTotal(
                  titulo: linea.descripcion ?? 'Mano de obra',
                  detalle: linea.aviso,
                  valor: Formatters.money(linea.precio),
                ),
              const SizedBox(height: AppSpacing.sm),
            ],
            if (total.desglose.refacciones.isNotEmpty) ...<Widget>[
              Text('Refacciones', style: textTheme.labelMedium),
              const SizedBox(height: AppSpacing.xs),
              for (final PartBreakdownLine linea in total.desglose.refacciones)
                _buildLineaTotal(
                  titulo: '${linea.cantidad} × ${linea.descripcion ?? 'Refacción'}',
                  detalle: linea.aviso ??
                      'c/u ${Formatters.money(linea.precioUnitario)}',
                  valor: Formatters.money(linea.subtotal),
                ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ],
          const Divider(),
          _buildFilaResumen(
            'Subtotal mano de obra',
            Formatters.money(total.subtotalManoDeObra),
          ),
          _buildFilaResumen(
            'Subtotal refacciones',
            Formatters.money(total.subtotalRefacciones),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              Expanded(
                child: Text('Total a cobrar', style: textTheme.titleMedium),
              ),
              Text(
                Formatters.money(total.total),
                key: const Key('total-cobrar'),
                style: textTheme.titleMedium?.copyWith(color: colors.primary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Fila de una partida del desglose: descripción, aviso y subtotal.
  Widget _buildLineaTotal({
    required String titulo,
    required String valor,
    String? detalle,
  }) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final MotorixColors colors = context.motorixColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(titulo, style: textTheme.bodyMedium),
                if (detalle != null)
                  Text(
                    detalle,
                    style: textTheme.bodySmall?.copyWith(
                      color: detalle == 'sin precio registrado'
                          ? colors.warning
                          : colors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          Text(valor, style: textTheme.bodyMedium),
        ],
      ),
    );
  }

  /// Fila de resumen (subtotal) del desglose.
  Widget _buildFilaResumen(String etiqueta, String valor) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(etiqueta, style: textTheme.bodySmall)),
          Text(valor, style: textTheme.bodySmall),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final PaymentsProvider pagos = context.watch<PaymentsProvider>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppMetrics.contentMaxWidth),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const BackAction(),
            const SizedBox(height: AppSpacing.lg),
            Text('Registrar pago', style: textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Cobra la orden #${widget.args.ordenId}: el monto debe coincidir '
              'con el total calculado con los precios vigentes.',
              style: textTheme.bodySmall?.copyWith(
                color: context.motorixColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            _buildTotal(pagos),
            const SizedBox(height: AppSpacing.lg),
            AppPanel(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (_error != null && _error!.isNotEmpty) ...<Widget>[
                      FormErrorBanner(mensaje: _error!),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                    TextFormField(
                      key: const Key('campo-monto'),
                      controller: _montoController,
                      enabled: !_saving,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Monto *',
                        hintText: 'Ej. 450.00',
                        prefixIcon: Icon(
                          LucideIcons.banknote,
                          size: AppMetrics.iconSizeSmall,
                        ),
                      ),
                      validator: (String? value) {
                        final String texto = value?.trim() ?? '';
                        if (texto.isEmpty) {
                          return 'El campo monto es obligatorio.';
                        }
                        final double? monto = double.tryParse(texto);
                        if (monto == null || monto <= 0) {
                          return 'El monto debe ser un número mayor a 0.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    DropdownButtonFormField<String>(
                      key: const Key('selector-metodo'),
                      initialValue: _metodo,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Método de pago *',
                        prefixIcon: Icon(
                          LucideIcons.creditCard,
                          size: AppMetrics.iconSizeSmall,
                        ),
                      ),
                      hint: const Text('Selecciona un método'),
                      items: <DropdownMenuItem<String>>[
                        for (final String metodo in paymentMethodValues)
                          DropdownMenuItem<String>(
                            value: metodo,
                            child: Text(paymentMethodLabel(metodo)),
                          ),
                      ],
                      validator: (String? value) =>
                          (value == null || value.isEmpty)
                              ? 'El método de pago es obligatorio.'
                              : null,
                      onChanged: (String? value) =>
                          setState(() => _metodo = value),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    TextFormField(
                      key: const Key('campo-fecha'),
                      controller: _fechaController,
                      enabled: !_saving,
                      decoration: const InputDecoration(
                        labelText: 'Fecha del pago',
                        hintText: 'AAAA-MM-DD (opcional; hoy por defecto)',
                        prefixIcon: Icon(
                          LucideIcons.calendar,
                          size: AppMetrics.iconSizeSmall,
                        ),
                      ),
                      validator: Validators.optionalFecha,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    FormActions(
                      onCancel: () => Navigator.pop(context, false),
                      onSave: _save,
                      saveLabel: 'Registrar pago',
                      saving: _saving,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
