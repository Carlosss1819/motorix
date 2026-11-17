# Contrato de interfaz (Flutter): Sprint 6

Sigue `docs/design-system.md` (Material 3, íconos Lucide, colores semánticos `danger`, `warning`, `info`, estados de carga, vacío y error de `common_views.dart`).

## Campana (`NotificationBell`, en el `AppBar` del `AppShell`)

- Visible para los tres roles.
- Ícono de campana; insignia con `noLeidos` (1 a 99, «99+» si hay más); sin insignia si es 0.
- `Key('notification-bell')`, insignia `Key('notification-badge')`.
- Se actualiza (`GET /notifications/count`) al iniciar sesión y al cambiar de sección del menú lateral (FR-017). Sin temporizador.
- Si la consulta del contador falla, la campana se muestra sin insignia (no bloquea la navegación).

## Panel de avisos

- Se abre al tocar la campana (panel lateral o diálogo según el ancho). Llama `GET /notifications` y actualiza el contador con `noLeidos`.
- Estados: carga (indicador), vacío («No tienes avisos pendientes»), error (mensaje + «Reintentar»).
- Grupos en el orden del contrato, con título y cantidad. Cada aviso: título, descripción, fecha, color según tipo (`danger` para vencido, agotado y orden detenida; `warning` para stock bajo y próximo; `info` para cita de hoy). Los no leídos con punto indicador y texto en negritas; los leídos atenuados.
- Acciones por aviso:
  - Tocar el aviso: abre el destino (`ORDEN` → detalle de la orden; `CITAS` → Citas con la fecha; `VEHICULO` → detalle del vehículo; `REFACCION` → detalle de la refacción) y lo marca como leído.
  - Botón «Marcar como leído» (`Key('marcar-leido-<clave>')`) en los no leídos: `POST /notifications/read`; el contador baja en 1.

## Pantalla «Clientes por avisar» (`ClientNoticesScreen`)

- Sección nueva del menú lateral, ruta `/client-notices`, visible solo para ADMIN y RECEPTIONIST (ícono de teléfono).
- Lista o tabla (según el ancho) con cliente, teléfono, vehículo, motivo (chip) y fecha.
- Estados de carga, vacío («No hay clientes por avisar») y error con «Reintentar».
- Botón «Marcar como avisado» → diálogo de confirmación («¿Ya avisaste a <cliente>? Solo márcalo si de verdad le avisaste.»). Al confirmar: `POST /client-notices`; el renglón sale de la lista y aparece un `SnackBar` «Aviso registrado».
- 409 `YA_AVISADO` o 404 `HECHO_NO_VIGENTE`: `SnackBar` con el mensaje del servidor y la lista se recarga.

## Citas con fecha inicial

`AppointmentsScreen` acepta un argumento opcional de fecha para abrirse en ese día (destino de `CITA_HOY`).
