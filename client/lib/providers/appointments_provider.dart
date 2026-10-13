import 'package:flutter/foundation.dart';

import '../models/appointment.dart';
import '../services/api_client.dart';
import '../services/appointments_service.dart';
import '../utils/messages.dart';
import 'load_status.dart';

/// Filtro "sin estado" y "sin fecha" para los selectores de citas.
const String kSinEstadoCita = '';
const String kSinFechaCita = '';

/// Fecha local en formato `AAAA-MM-DD` (la que exige el backend).
String hoyIso() {
  final DateTime hoy = DateTime.now();
  final String anio = hoy.year.toString().padLeft(4, '0');
  final String mes = hoy.month.toString().padLeft(2, '0');
  final String dia = hoy.day.toString().padLeft(2, '0');
  return '$anio-$mes-$dia';
}

/// Estado de la lista y de las acciones de las citas de recepción (US2).
///
/// El filtro de fecha arranca en el día de hoy porque la HU2 trabaja sobre el
/// listado del día; `kSinFechaCita` significa "todas las fechas".
class AppointmentsProvider extends ChangeNotifier {
  /// [service] permite sustituir el servicio en pruebas, sin tocar la red.
  AppointmentsProvider({required ApiClient api, AppointmentsService? service})
      : _service = service ?? AppointmentsService(api),
        _fecha = hoyIso();

  /// Citas por página en el listado paginado del backend.
  static const int porPagina = 10;

  final AppointmentsService _service;

  LoadStatus _status = LoadStatus.idle;
  List<Appointment> _items = const <Appointment>[];
  String? _error;
  String _fecha;
  String _estado = kSinEstadoCita;
  String _buscar = '';
  int _pagina = 1;
  int _paginas = 1;
  int _total = 0;

  /// Mensaje del último conflicto de horario (`409`, FR-008) o `null`.
  String? _conflictoHorario;

  LoadStatus get status => _status;
  List<Appointment> get items => _items;
  String? get error => _error;
  String get fecha => _fecha;
  String get estado => _estado;
  String get buscar => _buscar;
  int get pagina => _pagina;
  int get paginas => _paginas;
  int get total => _total;
  String? get conflictoHorario => _conflictoHorario;
  bool get hayConflictoHorario => _conflictoHorario != null;

  bool get isLoading => _status == LoadStatus.loading;

  /// Carga la página actual con los filtros aplicados (fecha, estado y
  /// búsqueda).
  Future<void> load() async {
    _status = LoadStatus.loading;
    _error = null;
    notifyListeners();

    try {
      final AppointmentPage page = await _service.list(
        fecha: _fecha,
        estado: _estado,
        buscar: _buscar,
        pagina: _pagina,
        porPagina: porPagina,
      );
      _items = page.elementos;
      _pagina = page.pagina;
      _paginas = page.paginas;
      _total = page.total;
      _status = LoadStatus.ready;
    } on ApiException catch (e) {
      _items = const <Appointment>[];
      _error = e.mensaje;
      _status = LoadStatus.error;
    } catch (_) {
      _items = const <Appointment>[];
      _error = AppMessages.unexpectedError;
      _status = LoadStatus.error;
    }
    notifyListeners();
  }

  /// Vuelve a cargar con los últimos filtros usados.
  Future<void> reload() => load();

  /// Filtra por día exacto; [kSinFechaCita] muestra todas las fechas. Siempre
  /// vuelve a la primera página.
  Future<void> setFecha(String value) async {
    if (_fecha == value) {
      return;
    }
    _fecha = value;
    _pagina = 1;
    await load();
  }

  /// Filtra por estado de cita desde la primera página.
  Future<void> setEstado(String value) async {
    if (_estado == value) {
      return;
    }
    _estado = value;
    _pagina = 1;
    await load();
  }

  /// Filtra por placas o nombre del cliente desde la primera página.
  Future<void> setBuscar(String value) async {
    if (_buscar == value) {
      return;
    }
    _buscar = value;
    _pagina = 1;
    await load();
  }

  /// Cambia de página del listado.
  Future<void> goToPage(int value) async {
    final int destino = value.clamp(1, _paginas);
    if (destino == _pagina) {
      return;
    }
    _pagina = destino;
    await load();
  }

  /// Registra el conflicto de horario (FR-008) para que la interfaz ofrezca
  /// el reenvío con confirmación.
  void _registrarConflicto(ApiException e) {
    if (e.codigo == 'CITA_CONFLICTO_HORARIO' && e.statusCode == 409) {
      _conflictoHorario = e.mensaje;
      notifyListeners();
    }
  }

  /// Limpia el conflicto guardado cuando la interfaz ya lo mostró.
  void limpiarConflicto() {
    if (_conflictoHorario == null) {
      return;
    }
    _conflictoHorario = null;
    notifyListeners();
  }

  /// Crea la cita (nace en `PROGRAMADA`, FR-005) y refresca el listado. Ante
  /// un `409` de conflicto de horario guarda el mensaje en [conflictoHorario]
  /// y vuelve a lanzar el error para que el formulario ofrezca confirmar.
  Future<Appointment> create({
    required int clienteId,
    required int vehiculoId,
    required String fecha,
    required String hora,
    required String motivo,
    bool confirmar = false,
  }) async {
    _conflictoHorario = null;
    try {
      final Appointment creada = await _service.create(
        clienteId: clienteId,
        vehiculoId: vehiculoId,
        fecha: fecha,
        hora: hora,
        motivo: motivo,
        confirmar: confirmar,
      );
      _pagina = 1;
      await reload();
      return creada;
    } on ApiException catch (e) {
      _registrarConflicto(e);
      rethrow;
    }
  }

  /// Edita fecha, hora y motivo de una cita `PROGRAMADA` (el cliente y el
  /// vehículo no cambian) y refresca el listado.
  Future<Appointment> update({
    required int id,
    required int clienteId,
    required int vehiculoId,
    required String fecha,
    required String hora,
    required String motivo,
  }) async {
    _conflictoHorario = null;
    try {
      final Appointment editada = await _service.update(
        id: id,
        clienteId: clienteId,
        vehiculoId: vehiculoId,
        fecha: fecha,
        hora: hora,
        motivo: motivo,
      );
      await reload();
      return editada;
    } on ApiException catch (e) {
      _registrarConflicto(e);
      rethrow;
    }
  }

  /// Cancela una cita `PROGRAMADA` con motivo opcional (FR-006) y refresca
  /// el listado.
  Future<Appointment> cancel({required int id, String motivo = ''}) async {
    final Appointment cancelada = await _service.cancel(id: id, motivo: motivo);
    await reload();
    return cancelada;
  }

  /// Recibe una cita `PROGRAMADA`: pasa a `RECIBIDA` sin crear órdenes y
  /// devuelve la precarga del formulario (FR-007). Refresca el listado.
  Future<ReceivedAppointment> receive({required int id}) async {
    final ReceivedAppointment recibida = await _service.receive(id: id);
    await reload();
    return recibida;
  }
}
