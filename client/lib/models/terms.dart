import '../utils/parsing.dart';

/// Versión vigente de los términos y del aviso de privacidad (Sprint 7, US9;
/// contrato: specs/007-reportes-configuracion/contracts/terms.md).
class TermsVersion {
  const TermsVersion({
    required this.version,
    required this.publicadoEn,
    required this.terminos,
    required this.avisoPrivacidad,
    this.aceptado = false,
    this.aceptadoEn,
  });

  factory TermsVersion.fromJson(Map<String, dynamic> json) => TermsVersion(
        version: asString(json['version']),
        publicadoEn: asString(json['publicadoEn']),
        terminos: asString(json['terminos']),
        avisoPrivacidad: asString(json['avisoPrivacidad']),
        aceptado: asBool(json['aceptado']),
        aceptadoEn: asStringOrNull(json['aceptadoEn']),
      );

  final String version;
  final String publicadoEn;
  final String terminos;
  final String avisoPrivacidad;
  final bool aceptado;
  final String? aceptadoEn;
}

/// Aceptación registrada (vista de ADMIN).
class TermsAcceptance {
  const TermsAcceptance({
    required this.usuarioId,
    required this.username,
    required this.version,
    required this.aceptadoEn,
  });

  factory TermsAcceptance.fromJson(Map<String, dynamic> json) =>
      TermsAcceptance(
        usuarioId: asInt(json['usuarioId']),
        username: asString(json['username']),
        version: asString(json['version']),
        aceptadoEn: asString(json['aceptadoEn']),
      );

  final int usuarioId;
  final String username;
  final String version;
  final String aceptadoEn;
}

/// Página de resultados genérica de las listas paginadas del Sprint 7.
class PagedResult<T> {
  const PagedResult({
    required this.elementos,
    required this.pagina,
    required this.paginas,
    required this.total,
  });

  final List<T> elementos;
  final int pagina;
  final int paginas;
  final int total;
}
