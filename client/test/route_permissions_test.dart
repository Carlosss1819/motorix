// Permisos de navegación por rol (Sprint 6, H-S6-05): el mecánico abre el
// detalle de SUS órdenes (desde «Mis órdenes» y desde el aviso de orden
// detenida). El backend responde 403 ORDEN_AJENA si la orden es de otro
// mecánico o no está asignada, y nunca le manda precios (Sprint 5).
import 'package:flutter_test/flutter_test.dart';
import 'package:motorix_client/main.dart';
import 'package:motorix_client/models/enums.dart';
import 'package:motorix_client/utils/app_routes.dart';

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
}
