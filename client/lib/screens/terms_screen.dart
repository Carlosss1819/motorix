import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/terms.dart';
import '../providers/auth_provider.dart';
import '../services/api_client.dart';
import '../services/terms_service.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/app_table.dart';
import '../widgets/common_views.dart';
import 'terms_acceptance_screen.dart';

/// Términos y aviso de privacidad vigentes (Sprint 7, US9, FR-021): los tres
/// roles consultan el texto («aviso de privacidad visible en la app»,
/// enmienda 1.1.0); ADMIN además ve las aceptaciones. Nadie edita el texto.
class TermsScreen extends StatefulWidget {
  const TermsScreen({super.key, this.service});

  /// Servicio inyectable para las pruebas.
  final TermsService? service;

  @override
  State<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends State<TermsScreen> {
  late final TermsService _service =
      widget.service ?? context.read<AuthProvider>().termsService;

  TermsVersion? _terminos;
  PagedResult<TermsAcceptance>? _aceptaciones;
  String? _error;
  bool _loading = true;
  int _pagina = 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final bool isAdmin = context.read<AuthProvider>().user?.isAdmin ?? false;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final TermsVersion terminos = await _service.current();
      final PagedResult<TermsAcceptance>? aceptaciones =
          isAdmin ? await _service.acceptances(pagina: _pagina) : null;
      if (!mounted) return;
      setState(() {
        _terminos = terminos;
        _aceptaciones = aceptaciones;
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

  void _irAPagina(int pagina) {
    _pagina = pagina;
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    if (_loading) return const LoadingView();
    if (_error != null) return ErrorView(mensaje: _error!, onRetry: _load);

    final PagedResult<TermsAcceptance>? aceptaciones = _aceptaciones;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppMetrics.contentMaxWidth),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Términos y aviso de privacidad', style: textTheme.titleLarge),
            const SizedBox(height: AppSpacing.lg),
            AppPanel(child: TermsTextView(terminos: _terminos!)),
            if (aceptaciones != null) ...<Widget>[
              const SizedBox(height: AppSpacing.xl),
              Text('Aceptaciones (${aceptaciones.total})', style: textTheme.titleMedium),
              const SizedBox(height: AppSpacing.md),
              AppPanel(
                padding: EdgeInsets.zero,
                child: aceptaciones.elementos.isEmpty
                    ? const EmptyView(
                        mensaje: 'Nadie ha aceptado esta versión todavía.',
                      )
                    : FullWidthTable(
                        key: const Key('tabla-aceptaciones'),
                        columns: <DataColumn>[
                          fluidColumn('Usuario', weight: 2),
                          fluidColumn('Versión'),
                          fluidColumn('Fecha de aceptación', weight: 2),
                        ],
                        rows: <DataRow>[
                          for (final TermsAcceptance a in aceptaciones.elementos)
                            DataRow(cells: <DataCell>[
                              DataCell(Text(a.username)),
                              DataCell(Text(a.version)),
                              DataCell(Text(Formatters.dateTime(a.aceptadoEn))),
                            ]),
                        ],
                      ),
              ),
              PagerBar(
                pagina: aceptaciones.pagina,
                paginas: aceptaciones.paginas,
                onPage: _irAPagina,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Paginador simple «Anterior / Página X de Y / Siguiente» de las listas del
/// Sprint 7 (aceptaciones y bitácora).
class PagerBar extends StatelessWidget {
  const PagerBar({
    super.key,
    required this.pagina,
    required this.paginas,
    required this.onPage,
  });

  final int pagina;
  final int paginas;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) {
    if (paginas <= 1) return const SizedBox(height: AppSpacing.md);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          TextButton(
            onPressed: pagina > 1 ? () => onPage(pagina - 1) : null,
            child: const Text('Anterior'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Text('Página $pagina de $paginas'),
          ),
          TextButton(
            onPressed: pagina < paginas ? () => onPage(pagina + 1) : null,
            child: const Text('Siguiente'),
          ),
        ],
      ),
    );
  }
}
