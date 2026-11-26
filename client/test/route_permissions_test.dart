// Permisos de navegación por rol (Sprint 6, H-S6-05): el mecánico abre el
// detalle de SUS órdenes (desde «Mis órdenes» y desde el aviso de orden
// detenida). El backend responde 403 ORDEN_AJENA si la orden es de otro
// mecánico o no está asignada, y nunca le manda precios (Sprint 5).
import 'package:flutter_test/flutter_test.dart';
import 'package:motorix_client/main.dart';
import 'package:motorix_client/models/enums.dart';
import 'package:motorix_client/utils/app_routes.dart';
import 'package:motorix_client/widgets/app_shell.dart';

void main() {
  test('el mecánico puede abrir el detalle de una orden', () {
    expect(canAccessRoute(Routes.serviceOrderDetail, Rol.mechanic), isTrue);
    expect(canAccessRoute(Routes.serviceOrderDetail, Rol.admin), isTrue);
    expect(canAccessRoute(Routes.serviceOrderDetail, Rol.receptionist), isTrue);
  });

  test('el mecánico sigue sin acceso a listas, altas, cobro, ticket ni fichas', () {
    for (final String ruta in <String>[
      Routes.serviceOrders,
      Routes.serviceOrderNew,
      Routes.clients,
      Routes.vehicles,
      Routes.appointments,
      Routes.appointmentNew,
      Routes.paymentForm,
      Routes.ticket,
      Routes.vehicleDetail,
      Routes.clientDetail,
      Routes.clientNotices,
      Routes.dashboard,
    ]) {
      expect(canAccessRoute(ruta, Rol.mechanic), isFalse, reason: ruta);
    }
    expect(canAccessRoute(Routes.myOrders, Rol.mechanic), isTrue);
  });

  // Sprint 7 (Entrega A): configuración, tipos de servicio y bitácora solo
  // ADMIN (el backend responde 403); términos y aviso para los tres roles.
  test('las secciones del Sprint 7 respetan el rol', () {
    for (final String ruta in <String>[Routes.settings, Routes.serviceTypes, Routes.auditLog]) {
      expect(canAccessRoute(ruta, Rol.admin), isTrue, reason: ruta);
      expect(canAccessRoute(ruta, Rol.receptionist), isFalse, reason: ruta);
      expect(canAccessRoute(ruta, Rol.mechanic), isFalse, reason: ruta);
    }
    for (final String rol in <String>[Rol.admin, Rol.receptionist, Rol.mechanic]) {
      expect(canAccessRoute(Routes.terms, rol), isTrue, reason: rol);
    }
  });

  // Sprint 7 (Entrega B, FR-038): reportes solo ADMIN, también en el menú.
  test('los reportes son solo para el administrador', () {
    expect(canAccessRoute(Routes.reports, Rol.admin), isTrue);
    expect(canAccessRoute(Routes.reports, Rol.receptionist), isFalse);
    expect(canAccessRoute(Routes.reports, Rol.mechanic), isFalse);
    expect(ShellSections.forRole(Rol.admin).map((ShellSection s) => s.route), contains(Routes.reports));
    for (final String rol in <String>[Rol.receptionist, Rol.mechanic]) {
      expect(ShellSections.forRole(rol).map((ShellSection s) => s.route), isNot(contains(Routes.reports)));
    }
  });
}
