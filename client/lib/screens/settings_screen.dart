import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../models/shop_settings.dart';
import '../services/api_client.dart';
import '../services/settings_service.dart';
import '../utils/app_theme.dart';
import '../utils/messages.dart';
import '../widgets/common_views.dart';

/// Configuración del taller (Sprint 7, US1/US2): datos que encabezan los
/// tickets nuevos y márgenes de «Próximo» de los mantenimientos nuevos.
/// Solo ADMIN (ruta protegida y 403 del backend, FR-006).
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, this.service});

  /// Servicio inyectable para las pruebas.
  final SettingsService? service;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final SettingsService _service =
      widget.service ?? SettingsService(context.read<ApiClient>());

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nombre = TextEditingController();
  final TextEditingController _direccion = TextEditingController();
  final TextEditingController _telefono = TextEditingController();
  final TextEditingController _dias = TextEditingController();
  final TextEditingController _km = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _loadError;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final TextEditingController c in <TextEditingController>[_nombre, _direccion, _telefono, _dias, _km]) {
      c.dispose();
    }
    super.dispose();
  }

  void _fill(ShopSettings s) {
    _nombre.text = s.nombre;
    _direccion.text = s.direccion;
    _telefono.text = s.telefono;
    _dias.text = '${s.antelacionDias}';
    _km.text = '${s.antelacionKm}';
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final ShopSettings settings = await _service.get();
      if (!mounted) return;
      _fill(settings);
      setState(() => _loading = false);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.mensaje;
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final ShopSettings saved = await _service.save(
        ShopSettings(
          nombre: _nombre.text.trim(),
          direccion: _direccion.text.trim(),
          telefono: _telefono.text.trim(),
          antelacionDias: int.parse(_dias.text.trim()),
          antelacionKm: int.parse(_km.text.trim()),
        ),
      );
      if (!mounted) return;
      _fill(saved);
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Configuración guardada. Los tickets y mantenimientos nuevos usarán estos datos.',
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.mensaje;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = AppMessages.unexpectedError;
      });
    }
  }

  static String? _texto(String? value, String campo, int max) {
    final String text = value?.trim() ?? '';
    if (text.isEmpty) return 'Ingresa $campo.';
    if (text.length > max) return '$campo no puede exceder $max caracteres.';
    return null;
  }

  static String? _entero(String? value, String campo, int max) {
    final int? number = int.tryParse(value?.trim() ?? '');
    if (number == null) return 'Ingresa $campo como número entero.';
    if (number < 1 || number > max) return '$campo debe estar entre 1 y $max.';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    if (_loading) return const LoadingView();
    if (_loadError != null) return ErrorView(mensaje: _loadError!, onRetry: _load);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppMetrics.contentMaxWidth),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Configuración del taller', style: textTheme.titleLarge),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Los cambios aplican a los tickets y mantenimientos nuevos; '
                'los ya emitidos o registrados conservan sus datos.',
                style: textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.lg),
              if (_error != null) ...<Widget>[
                FormErrorBanner(mensaje: _error!),
                const SizedBox(height: AppSpacing.lg),
              ],
              AppPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Datos del ticket', style: textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.lg),
                    TextFormField(
                      key: const Key('config-nombre'),
                      controller: _nombre,
                      decoration: const InputDecoration(labelText: 'Nombre del taller'),
                      validator: (String? v) => _texto(v, 'el nombre del taller', 120),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    TextFormField(
                      key: const Key('config-direccion'),
                      controller: _direccion,
                      decoration: const InputDecoration(labelText: 'Dirección'),
                      validator: (String? v) => _texto(v, 'la dirección', 200),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    TextFormField(
                      key: const Key('config-telefono'),
                      controller: _telefono,
                      decoration: const InputDecoration(labelText: 'Teléfono'),
                      validator: (String? v) => _texto(v, 'el teléfono', 30),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Márgenes de «Próximo» del mantenimiento', style: textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Antelación por defecto con la que un mantenimiento nuevo pasa a «Próximo».',
                      style: textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    TextFormField(
                      key: const Key('config-dias'),
                      controller: _dias,
                      keyboardType: TextInputType.number,
                      inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(labelText: 'Días antes (1 a 365)'),
                      validator: (String? v) => _entero(v, 'el margen en días', 365),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    TextFormField(
                      key: const Key('config-km'),
                      controller: _km,
                      keyboardType: TextInputType.number,
                      inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(labelText: 'Kilómetros antes (1 a 50000)'),
                      validator: (String? v) => _entero(v, 'el margen en kilómetros', 50000),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                key: const Key('config-guardar'),
                onPressed: _saving ? null : _save,
                icon: const Icon(LucideIcons.save, size: AppMetrics.iconSizeSmall),
                label: Text(_saving ? 'Guardando…' : 'Guardar configuración'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
