import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Nombres de ruta de la aplicación.
abstract final class Routes {
  /// Inicio de sesión (única ruta pública).
  static const String login = '/login';

  /// Inicio (bienvenida).
  static const String home = '/';

  /// Panel de recepción (US6): citas del día y órdenes abiertas; es la vista
  /// principal ("Inicio") de ADMIN y RECEPTIONIST.
  static const String reception = '/reception';

  /// Clientes.
  static const String clients = '/clients';
  static const String clientNew = '/clients/new';
  static const String clientDetail = '/clients/detail';
  static const String clientEdit = '/clients/edit';

  /// Vehículos.
  static const String vehicles = '/vehicles';
  static const String vehicleNew = '/vehicles/new';
  static const String vehicleDetail = '/vehicles/detail';
  static const String vehicleEdit = '/vehicles/edit';

  /// Historial del vehículo (US1, Sprint 3).
  static const String vehicleHistory = '/vehicles/history';

  /// Mantenimientos preventivos (US3/US4, Sprint 3).
  static const String maintenance = '/maintenance';
  static const String maintenanceNew = '/maintenance/new';
  static const String maintenanceEdit = '/maintenance/edit';

  /// Citas de recepción.
  static const String appointments = '/appointments';
  static const String appointmentNew = '/appointments/new';
  static const String appointmentEdit = '/appointments/edit';

  /// Órdenes de servicio.
  static const String serviceOrders = '/service-orders';
  static const String serviceOrderNew = '/service-orders/new';
  static const String serviceOrderDetail = '/service-orders/detail';

  /// Órdenes propias del mecánico (US3).
  static const String myOrders = '/my-orders';

  /// Usuarios (solo ADMIN).
  static const String users = '/users';

  /// Mi cuenta.
  static const String account = '/account';
}

/// Ruta de Material que usa la duración de navegación del sistema de diseño
/// (250 ms, con fundido y desplazamiento leve) y respeta la preferencia de
/// reducir movimiento.
class AppPageRoute<T> extends MaterialPageRoute<T> {
  AppPageRoute({required super.builder, super.settings});

  @override
  Duration get transitionDuration => AppDuration.navigate;
}
