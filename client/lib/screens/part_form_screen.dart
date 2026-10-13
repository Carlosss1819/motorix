import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../models/part.dart';
import '../providers/parts_provider.dart';
import '../services/api_client.dart';
import '../utils/app_theme.dart';
import '../utils/messages.dart';
import '../utils/validators.dart';
import '../widgets/common_views.dart';

/// Argumentos de la ruta del formulario de refacción.
class PartFormArgs {
  const PartFormArgs({this.refaccion});

  /// Si se pasa una refacción, el formulario la edita (FR-022); el código y
  /// el stock actual no se pueden modificar aquí.
  final Part? refaccion;
}

/// Formulario de refacción (US5/HU5): alta con código único (FR-017) y
/// edición del catálogo sin campo de stock actual, porque el stock solo
/// cambia por movimientos de inventario (FR-022).
class PartFormScreen extends StatefulWidget {
  const PartFormScreen({super.key, required this.args});

  final PartFormArgs args;

  @override
  State<PartFormScreen> createState() => _PartFormScreenState();
}

class _PartFormScreenState extends State<PartFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _codigoController;
  late final TextEditingController _nombreController;
  late final TextEditingController _categoriaController;
  late final TextEditingController _marcaController;
  late final TextEditingController _stockInicialController;
  late final TextEditingController _stockMinimoController;
  late final TextEditingController _precioCompraController;
  late final TextEditingController _precioVentaController;

  String? _error;
  bool _saving = false;

  bool get _esEdicion => widget.args.refaccion != null;

  @override
  void initState() {
    super.initState();
    final Part? actual = widget.args.refaccion;
    _codigoController = TextEditingController(text: actual?.codigo ?? '');
    _nombreController = TextEditingController(text: actual?.nombre ?? '');
    _categoriaController =
        TextEditingController(text: actual?.categoria ?? '');
    _marcaController = TextEditingController(text: actual?.marca ?? '');
    _stockInicialController = TextEditingController();
    _stockMinimoController = TextEditingController(
      text: actual?.stockMinimo.toString() ?? '',
    );
    _precioCompraController = TextEditingController(
      text: actual?.precioCompra?.toStringAsFixed(2) ?? '',
    );
    _precioVentaController = TextEditingController(
      text: actual?.precioVenta?.toStringAsFixed(2) ?? '',
    );
  }

  @override
  void dispose() {
    _codigoController.dispose();
    _nombreController.dispose();
    _categoriaController.dispose();
    _marcaController.dispose();
    _stockInicialController.dispose();
    _stockMinimoController.dispose();
    _precioCompraController.dispose();
    _precioVentaController.dispose();
    super.dispose();
  }

  int? _entero(TextEditingController controller) {
    final String texto = controller.text.trim();
    return texto.isEmpty ? null : int.tryParse(texto);
  }

  double? _decimal(TextEditingController controller) {
    final String texto = controller.text.trim();
    return texto.isEmpty ? null : double.tryParse(texto);
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

    final PartsProvider provider = context.read<PartsProvider>();
    try {
      final Part? actual = widget.args.refaccion;
      if (actual == null) {
        await provider.create(
          codigo: _codigoController.text.trim(),
          nombre: _nombreController.text.trim(),
          categoria: _categoriaController.text.trim(),
          marca: _marcaController.text.trim().isEmpty
              ? null
              : _marcaController.text.trim(),
          stockInicial: _entero(_stockInicialController) ?? 0,
          stockMinimo: _entero(_stockMinimoController) ?? 0,
          precioCompra: _decimal(_precioCompraController),
          precioVenta: _decimal(_precioVentaController),
        );
      } else {
        await provider.update(
          id: actual.id,
          nombre: _nombreController.text.trim(),
          categoria: _categoriaController.text.trim(),
          marca: _marcaController.text.trim().isEmpty
              ? null
              : _marcaController.text.trim(),
          stockMinimo: _entero(_stockMinimoController) ?? 0,
          precioCompra: _decimal(_precioCompraController),
          precioVenta: _decimal(_precioVentaController),
        );
      }

      if (!mounted) {
        return;
      }
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            actual == null
                ? 'Refacción registrada en el inventario.'
                : 'Refacción actualizada correctamente.',
          ),
        ),
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

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppMetrics.contentMaxWidth),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const BackAction(),
            const SizedBox(height: AppSpacing.lg),
            Text(
              _esEdicion ? 'Editar refacción' : 'Nueva refacción',
              style: textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              _esEdicion
                  ? 'Actualiza los datos del catálogo: el código y el stock '
                      'actual no se modifican aquí.'
                  : 'Registra la refacción con su código único; el stock '
                      'actual solo cambia con los movimientos de inventario.',
              style: textTheme.bodySmall?.copyWith(
                color: context.motorixColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
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
                    if (_esEdicion)
                      _buildCodigoSoloLectura()
                    else ...<Widget>[
                      TextFormField(
                        controller: _codigoController,
                        enabled: !_saving,
                        maxLength: 30,
                        decoration: const InputDecoration(
                          labelText: 'Código *',
                          hintText: 'Ej. PAD-001',
                          prefixIcon: Icon(
                            LucideIcons.tag,
                            size: AppMetrics.iconSizeSmall,
                          ),
                        ),
                        validator: (String? value) =>
                            Validators.required(value, 'el código'),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                    TextFormField(
                      controller: _nombreController,
                      enabled: !_saving,
                      maxLength: 120,
                      decoration: const InputDecoration(
                        labelText: 'Nombre *',
                        hintText: 'Ej. Juego de pastillas delanteras',
                        prefixIcon: Icon(
                          LucideIcons.package,
                          size: AppMetrics.iconSizeSmall,
                        ),
                      ),
                      validator: (String? value) =>
                          Validators.required(value, 'el nombre'),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: TextFormField(
                            controller: _categoriaController,
                            enabled: !_saving,
                            maxLength: 80,
                            decoration: const InputDecoration(
                              labelText: 'Categoría *',
                              hintText: 'Ej. Frenos',
                              prefixIcon: Icon(
                                LucideIcons.shapes,
                                size: AppMetrics.iconSizeSmall,
                              ),
                            ),
                            validator: (String? value) =>
                                Validators.required(value, 'la categoría'),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.lg),
                        Expanded(
                          child: TextFormField(
                            controller: _marcaController,
                            enabled: !_saving,
                            maxLength: 80,
                            decoration: const InputDecoration(
                              labelText: 'Marca',
                              hintText: 'Opcional',
                              prefixIcon: Icon(
                                LucideIcons.badge,
                                size: AppMetrics.iconSizeSmall,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    if (!_esEdicion) ...<Widget>[
                      TextFormField(
                        controller: _stockInicialController,
                        enabled: !_saving,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Stock inicial',
                          hintText: '0 (opcional)',
                          prefixIcon: Icon(
                            LucideIcons.packagePlus,
                            size: AppMetrics.iconSizeSmall,
                          ),
                        ),
                        validator: (String? value) =>
                            Validators.optionalNonNegativeInt(
                          value,
                          'el stock inicial',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: TextFormField(
                            controller: _stockMinimoController,
                            enabled: !_saving,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Stock mínimo',
                              hintText: '0 (opcional)',
                              prefixIcon: Icon(
                                LucideIcons.packageMinus,
                                size: AppMetrics.iconSizeSmall,
                              ),
                            ),
                            validator: (String? value) =>
                                Validators.optionalNonNegativeInt(
                              value,
                              'el stock mínimo',
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.lg),
                        Expanded(
                          child: TextFormField(
                            controller: _precioCompraController,
                            enabled: !_saving,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Precio de compra',
                              hintText: 'Ej. 180.00 (opcional)',
                              prefixIcon: Icon(
                                LucideIcons.arrowDownToLine,
                                size: AppMetrics.iconSizeSmall,
                              ),
                            ),
                            validator: (String? value) =>
                                Validators.optionalNonNegativeNumber(
                              value,
                              'el precio de compra',
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.lg),
                        Expanded(
                          child: TextFormField(
                            controller: _precioVentaController,
                            enabled: !_saving,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Precio de venta',
                              hintText: 'Ej. 320.00 (opcional)',
                              prefixIcon: Icon(
                                LucideIcons.arrowUpFromLine,
                                size: AppMetrics.iconSizeSmall,
                              ),
                            ),
                            validator: (String? value) =>
                                Validators.optionalNonNegativeNumber(
                              value,
                              'el precio de venta',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    FormActions(
                      onCancel: () => Navigator.pop(context, false),
                      onSave: _save,
                      saveLabel: _esEdicion ? 'Guardar cambios' : 'Registrar',
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

  /// El código es identificador de la refacción (FR-022): en edición se
  /// muestra, pero no se puede cambiar.
  Widget _buildCodigoSoloLectura() {
    final Part? actual = widget.args.refaccion;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: TextFormField(
        initialValue: actual?.codigo ?? '',
        enabled: false,
        decoration: const InputDecoration(
          labelText: 'Código (identificador)',
          prefixIcon: Icon(
            LucideIcons.tag,
            size: AppMetrics.iconSizeSmall,
          ),
        ),
      ),
    );
  }
}
