# Reporte de implementación — Sprint 4: pagos, tickets y dashboard

**Fecha**: 2026-10-14
**Especificación**: [spec.md](spec.md) · [tasks.md](tasks.md) · [quickstart.md](quickstart.md)
**Estado**: sprint completo — T001 a T061 cerradas, seis historias de usuario entregadas.

## 1. Alcance

| Historia | Entregable | Estado |
| --- | --- | --- |
| US1 | Registro y consulta de pagos (`POST /api/payments`, consulta por orden, total con desglose, anulación con motivo, guard de entrega condicionado al pago) | Completa |
| US2 | Métodos `EFECTIVO`, `TARJETA`, `TRANSFERENCIA` con validación de monto y etiquetas legibles en el formulario de cobro | Completa |
| US3 | Mercado Pago con `payment_gateway/` (preferencia, confirmación `PAGADO/RECHAZADO/CANCELADO`, reintentos) sin dependencias nuevas | Completa |
| US4 | Ticket de servicio idempotente con folio `T000001-2026`, contenido completo e impresión con el diálogo del navegador (sin PDF almacenado) | Completa |
| US5 | `GET /api/dashboard` con `fecha` + bloque `ordenes` y sección «Panel» solo para `Rol.admin` en el cliente | Completa |
| US6 | Bloques `citas` (hoy y próximas), `mantenimientos` (próximos/vencidos con su `objetivo`) y `alertasInventario` (top 10 por faltante) en backend y pantalla | Completa |

Fuera de alcance (supuestos confirmados en la spec): pagos parciales, reembolsos,
almacenamiento de PDF, datos de tarjeta y actualización en tiempo real del panel.

## 2. Decisiones

- **Sin dependencias nuevas**: Mercado Pago se integra con `fetch` nativo de Node;
  la impresión usa `window.print()` con hoja de estilo `@media print`; no se agregó
  `url_launcher` ni cualquier otra librería.
- **RN‑14 (secretos y datos de tarjeta)**: credenciales solo por `MP_ACCESS_TOKEN` y
  `MP_PUBLIC_URL` (documentadas en `server/.env.example` sin valores); ninguna fila de
  `payments` guarda PAN, CVV ni tokens; hay prueba automática que lo verifica.
- **Pasarela por entorno**: con `MP_ACCESS_TOKEN` se usa Mercado Pago (`sandbox`);
  sin él, la pasarela `simulada` (mismo contrato), lo que permite desarrollar y
  probar sin credenciales.
- **Idempotencia del ticket**: la generación es atómica ante la carrera de dos
  emisiones simultáneas (reintento sobre `ER_DUP_ENTRY`), siempre con el mismo folio.
- **Estado derivado del mantenimiento**: `calcMaintenanceState` se reutiliza en el
  panel; `objetivo` usa la misma prioridad del cálculo (kilometraje primero, después
  fecha) para que el dato muestre qué disparó la alerta.
- **Panel con una sola petición (D4)**: carga y error son globales en la pantalla;
  cada bloque ofrece su estado vacío amigable (HU6‑4) sin llamadas adicionales.
- **Sin copias para estadísticas (CA‑6)**: los contadores se calculan sobre las
  tablas de origen (`service_orders`, `appointments`, `maintenance`, `parts`); las
  pruebas los contrastan contra el listado individual dentro de una ventana estable.
- **Roles**: anulación de pago solo `ADMIN`; emisión y consulta de tickets
  `ADMIN`/`RECEPTIONIST`; panel solo `ADMIN` (doble filtro: navegación oculta y
  `403 PANEL_SOLO_ADMIN`).

## 3. Métricas

| Métrica | Valor |
| --- | --- |
| Tareas cerradas (T001–T061) | 61 de 61 |
| Commits del sprint | 36 (Conventional Commits, descripción en español) |
| Archivos modificados/creados | 82 (+10 856 líneas) |
| Pruebas backend | 49 suites / 411 pruebas en verde (Jest, `--forceExit` conocido) |
| Pruebas frontend | 124 pruebas en verde (Flutter) |
| Estática | `eslint .` 0 errores · `flutter analyze` 0 problemas |
| Escenarios E1–E6 (backend local, `DB_NAME=motorix_v2_test`, 3 roles) | 40 de 40 pasos correctos |
| Escenario E7 (migraciones y seeds consecutivos en `motorix_v2`) | Sin duplicación; panel con datos desde el primer arranque |

## 4. Resultados de validación (E1–E7)

Ejecutados contra el backend local en el puerto 3000 con los roles
`admin`/`recepcion`/`mecanico`:

- **E1 — Cobro**: total con desglose (400 de mano de obra), pagos en efectivo,
  tarjeta y transferencia quedan `PAGADO` y visibles en el detalle; sin método
  responde `400` con «método de pago requerido».
- **E2 — Rechazos y entrega**: segundo pago de orden liquidada `409`; pago sobre
  orden `RECIBIDO` `409`; `ENTREGADO` sin pago `409` con mensaje que pide el pago;
  con pago pasa a `ENTREGADO` y llena `fechaEntrega`.
- **E3 — Anulación**: `recepcion` recibe `403`; anular sin motivo `400`; con motivo
  queda `ANULADO` conservando el texto; el pago anulado permanece en el historial y
  la orden libre admite un pago nuevo; anular el pago de una orden `ENTREGADO` `409`.
- **E4 — Mercado Pago (modo `simulado`)**: el pago nace `PENDIENTE` con
  `referenciaExterna`, `enlacePago` y `modoPasarela`; `PAGADO` liquida la orden;
  `RECHAZADO` y `CANCELADO` liberan el reintento; ninguna respuesta contiene datos
  de tarjeta ni credenciales.
- **E5 — Tickets**: folio `T000050-2026` con taller, cliente, vehiculo, servicios y
  total; regenerar devuelve el mismo folio (200); consulta por orden coincide;
  orden sin pago `409 TICKET_REQUIERE_PAGO`.
- **E6 — Panel**: cuatro bloques en 29–116 ms (< 5 s); `recepcion` y `mecanico`
  reciben `403 PANEL_SOLO_ADMIN`; fecha sin datos devuelve arreglos `[]`;
  órdenes del panel = total del listado (2048 vs 2048) y stock bajo = filtro del
  inventario (123 vs 123); las cuatro altas (cita, mantenimiento, refacción y
  orden) aparecen al «Actualizar».
- **E7 — Arranque limpio**: segunda corrida consecutiva de
  `aplicar-migraciones.ps1 -Seeds` con todas las migraciones `[omitida]` y seeds
  idempotentes; conteos idénticos (3 usuarios, 6 clientes/vehículos/órdenes/
  refacciones/mantenimientos, 5 citas), 4 pagos de ejemplo (efectivo y tarjeta
  `PAGADO`, Mercado Pago `PENDIENTE` y `ANULADO`) y tickets `T000001-2026` y
  `T000002-2026`; el panel muestra información desde el primer arranque
  (total 6, citas hoy 2, mantenimientos vencidos 1, alertas 2).

## 5. Decisiones abiertas

1. **Credenciales reales de Mercado Pago**: definir `MP_ACCESS_TOKEN` (producción o
   sandbox) y `MP_PUBLIC_URL` en cada entorno; sin ellas el sistema opera con la
   pasarela simulada.
2. **Reembolsos y pagos parciales**: fuera del MVP; si se requieren, implica un
   nuevo estado/flujo en `payment-transitions` y reglas de anulación adicionales.
3. **PDF del ticket**: hoy es impresión desde el navegador; si se necesita archivo
   persistido habría que evaluar generación en backend (dependencia nueva).
4. **Base `motorix_v2`**: la migración 004 quedó aplicada con aprobación en este
   entorno local; replicar el proceso (con respaldo) en cualquier otro entorno antes
   de desplegar.
5. **Actualización en tiempo real del panel**: D4 lo dejó fuera; si se necesita,
   sería polling o SSE como trabajo futuro.
