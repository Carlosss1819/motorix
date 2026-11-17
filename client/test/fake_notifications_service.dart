import 'dart:async';

import 'package:motorix_client/models/client_notice.dart';
import 'package:motorix_client/models/notification.dart';
import 'package:motorix_client/services/api_client.dart';
import 'package:motorix_client/services/client_notices_service.dart';
import 'package:motorix_client/services/notifications_service.dart';

/// Servicio de avisos falso (Sprint 6): devuelve lo que se le asigne sin abrir
/// conexiones y deja a la vista las llamadas.
class FakeNotificationsService extends NotificationsService {
  FakeNotificationsService({
    this.conteo = 0,
    NotificationsSummary? resumen,
    this.errorConteo,
    this.errorLista,
  })  : resumen = resumen ?? resumenDePrueba(),
        super(ApiClient());

  int conteo;
  NotificationsSummary resumen;
  ApiException? errorConteo;
  ApiException? errorLista;

  /// Si tiene valor, `fetchAll` espera a que se complete (estado de carga).
  Completer<void>? bloqueo;

  int llamadasConteo = 0;
  int llamadasLista = 0;
  final List<String> leidas = <String>[];

  @override
  Future<int> fetchCount() async {
    llamadasConteo += 1;
    final ApiException? fallo = errorConteo;
    if (fallo != null) {
      throw fallo;
    }
    return conteo;
  }

  @override
  Future<NotificationsSummary> fetchAll() async {
    llamadasLista += 1;
    final Completer<void>? espera = bloqueo;
    if (espera != null) {
      await espera.future;
    }
    final ApiException? fallo = errorLista;
    if (fallo != null) {
      throw fallo;
    }
    return resumen;
  }

  @override
  Future<void> markRead(String clave) async {
    leidas.add(clave);
  }
}

NotificationItem avisoDePrueba({
  required String clave,
  required String tipo,
  String titulo = 'Aviso',
  String descripcion = 'Descripción',
  String fechaReferencia = '2026-11-16',
  bool leido = false,
  required NotificationTarget destino,
}) {
  return NotificationItem(
    clave: clave,
    tipo: tipo,
    titulo: titulo,
    descripcion: descripcion,
    fechaReferencia: fechaReferencia,
    leido: leido,
    destino: destino,
  );
}

NotificationGroup grupoDePrueba(String tipo, String titulo, List<NotificationItem> avisos) {
  return NotificationGroup(
    tipo: tipo,
    titulo: titulo,
    cantidad: avisos.length,
    noLeidos: avisos.where((NotificationItem a) => !a.leido).length,
    avisos: avisos,
  );
}

/// Un aviso de cada destino: orden, cita, vehículo y refacción.
NotificationsSummary resumenDePrueba() {
  final List<NotificationGroup> grupos = <NotificationGroup>[
    grupoDePrueba(NotificationTypes.mantVencido, 'Mantenimientos vencidos', <NotificationItem>[
      avisoDePrueba(
        clave: 'MANT_VENCIDO:7:2026-11-01|-',
        tipo: NotificationTypes.mantVencido,
        titulo: 'Mantenimiento vencido',
        descripcion: 'Cambio de aceite · Nissan Versa 2020 (ABC1234)',
        destino: const NotificationTarget(pantalla: NotificationScreens.vehiculo, id: 4),
      ),
    ]),
    grupoDePrueba(NotificationTypes.ordenDetenida, 'Órdenes detenidas', <NotificationItem>[
      avisoDePrueba(
        clave: 'ORDEN_DETENIDA:12:DIAGNOSTICO',
        tipo: NotificationTypes.ordenDetenida,
        titulo: 'Orden detenida',
        descripcion: 'Orden #12 · 4 días sin cambio',
        destino: const NotificationTarget(pantalla: NotificationScreens.orden, id: 12),
      ),
    ]),
    grupoDePrueba(NotificationTypes.stockBajo, 'Refacciones con stock bajo', <NotificationItem>[
      avisoDePrueba(
        clave: 'STOCK_BAJO:5',
        tipo: NotificationTypes.stockBajo,
        titulo: 'Stock bajo',
        descripcion: 'FIL-ACE01 · Existencia 3 · mínimo 5',
        destino: const NotificationTarget(pantalla: NotificationScreens.refaccion, id: 5),
      ),
    ]),
    grupoDePrueba(NotificationTypes.citaHoy, 'Citas de hoy', <NotificationItem>[
      avisoDePrueba(
        clave: 'CITA_HOY:9:2026-11-16',
        tipo: NotificationTypes.citaHoy,
        titulo: 'Cita de hoy',
        descripcion: '23:30 · Laura Méndez',
        destino: const NotificationTarget(
          pantalla: NotificationScreens.citas,
          id: 9,
          fecha: '2026-11-16',
        ),
      ),
      avisoDePrueba(
        clave: 'CITA_HOY:10:2026-11-16',
        tipo: NotificationTypes.citaHoy,
        titulo: 'Cita de hoy (leída)',
        leido: true,
        destino: const NotificationTarget(
          pantalla: NotificationScreens.citas,
          id: 10,
          fecha: '2026-11-16',
        ),
      ),
    ]),
  ];
  return NotificationsSummary(noLeidos: 4, totalAvisos: 5, grupos: grupos);
}

/// Solo el grupo de órdenes detenidas (lo único que recibe el mecánico).
NotificationsSummary resumenDeMecanico() {
  return NotificationsSummary(
    noLeidos: 1,
    totalAvisos: 1,
    grupos: <NotificationGroup>[
      grupoDePrueba(NotificationTypes.ordenDetenida, 'Órdenes detenidas', <NotificationItem>[
        avisoDePrueba(
          clave: 'ORDEN_DETENIDA:21:EN_REPARACION',
          tipo: NotificationTypes.ordenDetenida,
          titulo: 'Orden detenida',
          descripcion: 'Orden #21 · 5 días sin cambio',
          destino: const NotificationTarget(pantalla: NotificationScreens.orden, id: 21),
        ),
      ]),
    ],
  );
}

/// Servicio falso de «Clientes por avisar».
class FakeClientNoticesService extends ClientNoticesService {
  FakeClientNoticesService({List<ClientNotice>? elementos, this.errorLista, this.errorMarcar})
      : elementos = elementos ?? clientesPorAvisarDePrueba(),
        super(ApiClient());

  List<ClientNotice> elementos;
  ApiException? errorLista;
  ApiException? errorMarcar;
  int llamadasLista = 0;
  final List<String> marcadas = <String>[];

  @override
  Future<List<ClientNotice>> fetchAll() async {
    llamadasLista += 1;
    final ApiException? fallo = errorLista;
    if (fallo != null) {
      throw fallo;
    }
    return List<ClientNotice>.of(elementos);
  }

  @override
  Future<void> markNotified(String clave) async {
    final ApiException? fallo = errorMarcar;
    if (fallo != null) {
      throw fallo;
    }
    marcadas.add(clave);
    elementos = elementos.where((ClientNotice e) => e.clave != clave).toList();
  }
}

ClientNotice clienteAvisoDePrueba({
  String clave = 'ORDEN:60003',
  String motivo = ClientNoticeReasons.vehiculoListo,
  String motivoTexto = 'Vehículo listo',
  String nombre = 'Laura Méndez',
}) {
  return ClientNotice(
    clave: clave,
    motivo: motivo,
    motivoTexto: motivoTexto,
    clienteId: 60001,
    clienteNombre: nombre,
    clienteTelefono: '5550060001',
    vehiculoId: 60003,
    vehiculoDescripcion: 'Chevrolet Aveo 2017',
    vehiculoPlacas: 'NOT6-003',
    fecha: '2026-11-16',
    destino: const NotificationTarget(pantalla: NotificationScreens.orden, id: 60003),
  );
}

List<ClientNotice> clientesPorAvisarDePrueba() => <ClientNotice>[
      clienteAvisoDePrueba(),
      clienteAvisoDePrueba(
        clave: 'CITA:60002',
        motivo: ClientNoticeReasons.citaManana,
        motivoTexto: 'Cita de mañana',
        nombre: 'Pedro Ruiz',
      ),
    ];
