import 'package:motorix_client/models/dashboard_summary.dart';
import 'package:motorix_client/services/api_client.dart';
import 'package:motorix_client/services/dashboard_service.dart';

/// Servicio del panel falso para pruebas (US5): devuelve el resumen que se le
/// asigne sin abrir ninguna conexión y deja a la vista las llamadas.
class FakeDashboardService extends DashboardService {
  FakeDashboardService({this.resumen, this.error}) : super(ApiClient());

  /// Resumen devuelto; sin valor se usa el de [dashboardDePrueba].
  DashboardSummary? resumen;

  /// Fallo opcional lanzado como [ApiException] (por ejemplo, un
  /// `403 PANEL_SOLO_ADMIN`).
  ApiException? error;

  /// Veces que se pidió el resumen y la última fecha enviada.
  int llamadas = 0;
  String? ultimaFecha;

  @override
  Future<DashboardSummary> fetchSummary({String? fecha}) async {
    llamadas += 1;
    ultimaFecha = fecha;
    final ApiException? fallo = error;
    if (fallo != null) {
      throw fallo;
    }
    return resumen ?? dashboardDePrueba();
  }
}

/// Fábrica compacta de un resumen con todos los bloques, con el formato del
/// contrato (FR-011).
DashboardSummary dashboardDePrueba({
  String fecha = '2026-10-14',
  DashboardOrdersBlock ordenes = const DashboardOrdersBlock(
    total: 12,
    abiertas: 7,
    entregadas: 5,
    porEstado: <String, int>{
      'RECIBIDO': 2,
      'DIAGNOSTICO': 1,
      'EN_REPARACION': 2,
      'ESPERANDO_REFACCION': 1,
      'TERMINADO': 1,
      'ENTREGADO': 5,
    },
  ),
  DashboardAppointmentsBlock citas = const DashboardAppointmentsBlock(
    hoy: 2,
    proximas: <DashboardAppointmentLine>[
      DashboardAppointmentLine(
        id: 9,
        fecha: '2026-10-15',
        hora: '10:00',
        cliente: 'María López',
        estado: 'PROGRAMADA',
      ),
    ],
  ),
  DashboardMaintenancesBlock mantenimientos = const DashboardMaintenancesBlock(
    proximos: <DashboardMaintenanceLine>[
      DashboardMaintenanceLine(
        id: 5,
        vehiculo: 'Nissan Versa ABC-123-D',
        tipo: 'Cambio de aceite',
        estado: 'PROXIMO',
        objetivo: '2026-10-20',
      ),
    ],
    vencidos: <DashboardMaintenanceLine>[
      DashboardMaintenanceLine(
        id: 2,
        vehiculo: 'Chevrolet Aveo XYZ-987-L',
        tipo: 'Rotación de llantas',
        estado: 'VENCIDO',
        objetivo: '2026-10-01',
      ),
    ],
  ),
  DashboardInventoryBlock alertasInventario = const DashboardInventoryBlock(
    stockBajo: 1,
    refacciones: <DashboardLowStockLine>[
      DashboardLowStockLine(
        id: 2,
        codigo: 'PAD-001',
        nombre: 'Juego de pastillas delanteras',
        stockActual: 3,
        stockMinimo: 5,
      ),
    ],
  ),
}) =>
    DashboardSummary(
      fecha: fecha,
      ordenes: ordenes,
      citas: citas,
      mantenimientos: mantenimientos,
      alertasInventario: alertasInventario,
    );

/// Resumen sin órdenes, para el estado vacío amigable (HU6-4).
DashboardSummary panelVacioPrueba() => DashboardSummary(
      fecha: '2026-10-14',
      ordenes: const DashboardOrdersBlock(),
    );
