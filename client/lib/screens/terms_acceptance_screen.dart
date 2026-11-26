import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../models/terms.dart';
import '../providers/auth_provider.dart';
import '../services/api_client.dart';
import '../utils/app_routes.dart';
import '../utils/app_theme.dart';
import '../utils/messages.dart';
import '../widgets/common_views.dart';

/// Nota visible que exige la aclaración de la spec 007 (US9).
const String kNotaPlantillaAcademica =
    'Plantilla académica: estos textos son un ejemplo para un proyecto escolar '
    'y no constituyen asesoría legal.';

/// Aceptación obligatoria de los términos y del aviso de privacidad al
/// iniciar sesión (Sprint 7, US9, FR-017 a FR-019). Mientras esté pendiente,
/// main.dart muestra esta pantalla en cualquier ruta y el backend responde
/// 403 TERMINOS_PENDIENTES. Rechazar cierra la sesión.
class TermsAcceptanceScreen extends StatefulWidget {
  const TermsAcceptanceScreen({super.key});

  @override
  State<TermsAcceptanceScreen> createState() => _TermsAcceptanceScreenState();
}

class _TermsAcceptanceScreenState extends State<TermsAcceptanceScreen> {
  TermsVersion? _terminos;
  String? _error;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final TermsVersion terminos =
          await context.read<AuthProvider>().termsService.current();
      if (!mounted) return;
      setState(() {
        _terminos = terminos;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.mensaje;
        _loading = false;
      });
    }
  }

  Future<void> _accept() async {
    final TermsVersion? terminos = _terminos;
    if (terminos == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await context.read<AuthProvider>().acceptTerms(terminos.version);
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(
        Routes.home,
        (Route<dynamic> route) => false,
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

  Future<void> _reject() async {
    await context.read<AuthProvider>().rejectTerms();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      Routes.login,
      (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final MotorixColors colors = context.motorixColors;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colors.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: AppMetrics.contentMaxWidth),
            child: AppPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Icon(LucideIcons.shieldCheck, color: colors.primary),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Términos y condiciones y aviso de privacidad',
                          style: textTheme.titleLarge,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Para usar el sistema debes leer y aceptar la versión '
                    'vigente. Si no la aceptas, se cerrará tu sesión.',
                    style: textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (_error != null) ...<Widget>[
                    FormErrorBanner(mensaje: _error!),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  if (_loading)
                    const LoadingView()
                  else if (_terminos != null)
                    TermsTextView(terminos: _terminos!),
                  const SizedBox(height: AppSpacing.xl),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      OutlinedButton(
                        key: const Key('terminos-rechazar'),
                        onPressed: _saving ? null : _reject,
                        child: const Text('Rechazar y salir'),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      FilledButton.icon(
                        key: const Key('terminos-aceptar'),
                        onPressed:
                            _saving || _terminos == null ? null : _accept,
                        icon: const Icon(
                          LucideIcons.check,
                          size: AppMetrics.iconSizeSmall,
                        ),
                        label: Text(_saving ? 'Guardando…' : 'Acepto'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Texto de los términos y del aviso, con la nota de plantilla académica.
/// Lo comparten la aceptación y la consulta (terms_screen.dart).
class TermsTextView extends StatelessWidget {
  const TermsTextView({super.key, required this.terminos});

  final TermsVersion terminos;

  @override
  Widget build(BuildContext context) {
    final MotorixColors colors = context.motorixColors;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          key: const Key('nota-plantilla-academica'),
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: colors.warning.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppRadius.panel),
            border: Border.all(color: colors.warning.withValues(alpha: 0.4)),
          ),
          child: Text(
            kNotaPlantillaAcademica,
            style: textTheme.bodySmall?.copyWith(color: colors.warning),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Versión ${terminos.version} · publicada el ${terminos.publicadoEn.split(' ').first}',
          style: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.lg),
        SelectableText(terminos.terminos, style: textTheme.bodyMedium),
        const SizedBox(height: AppSpacing.xl),
        const Divider(),
        const SizedBox(height: AppSpacing.xl),
        SelectableText(terminos.avisoPrivacidad, style: textTheme.bodyMedium),
      ],
    );
  }
}
