# Inicio Rápido (Fase 1)

**Funcionalidad**: Pagos, Tickets y Dashboard (`004-pagos-tickets-dashboard`)
**Fecha**: 2026-10-13 | **Plan**: [plan.md](plan.md)

Guion de validación manual del sprint, pensado para ejecutarse en orden sobre una
instalación local ya funcionando (sprints 1 a 3). Todo se verifica desde el navegador
(Flutter en escritorio o web) con el backend corriendo; las credenciales de los tres
roles son las del seed. Los escenarios llevan prefijo **E** (del sprint 4) para no
confundirse con los **V** del sprint 3.

## Requisitos previos

- Base de datos local aplicada al día (`aplicar-migraciones.ps1` crea la tabla
  `schema_migrations` y aplica `004_pagos_tickets_dashboard.sql` + su seed de forma
  idempotente).
- Backend arrancado (`npm run dev` en `server/`) y frontend (`flutter run` en
  `client/`).
- Sesiones de prueba: `admin` / `Admin2026!`, `recepcion` / `Recepcion2026!`,
  `mecanico` / `Mecanico2026!`.
- Variables de entorno opcionales de Mercado Pago (`MP_ACCESS_TOKEN`, `MP_PUBLIC_URL`
  de retorno): sin ellas el sistema usa el modo simulado (D1); no guardar ningún
  secreto en el repositorio (CA‑7).

## Escenarios de validación

### E1 — Registrar el pago de una orden terminada (HU1, HU2, FR‑001 a FR‑004, FR‑015)

1. Entrar como `recepcion`, abrir una orden en `TERMINADO` y pulsar «Registrar pago».
2. **Entonces**: el formulario muestra el total calculado con los precios vigentes
   (mano de obra + refacciones × cantidad) y su desglose.
3. Capturar monto (coincidente con el total), método `EFECTIVO` y fecha → guardar.
4. **Entonces**: el pago queda `PAGADO`, ligado a la orden, visible en el detalle
   junto al total (monto, método, fecha y estado), en menos de 1 minuto (SC‑001).
5. Repetir con `TARJETA` y `TRANSFERENCIA` en otra orden → cada método guardado con su
   etiqueta legible; sin método → mensaje de validación y no guarda (HU2‑3).

### E2 — Rechazos del cobro y entrega condicionada al pago (HU1, FR‑004, FR‑014)

1. Con la orden ya liquidada del E1, intentar registrar otro pago → `409` «orden ya
   liquidada».
2. Abrir una orden en `RECIBIDO` (u otro estado no cobrable) → «Registrar pago»
   rechaza con mensaje claro (HU1‑4).
3. Abrir una orden en `TERMINADO` **sin pago** y llevarla a `ENTREGADO` → rechazo
   indicando que primero debe registrarse el pago (HU1‑5, SC‑001).
4. Registrar su pago y repetir el paso anterior → la orden pasa a `ENTREGADO` y su
   fecha de entrega se llena (FR‑014).

### E3 — Anulación de un pago erróneo (HU1, FR‑016, RN‑9, RN‑15)

1. Como `recepcion`, anular un pago (endpoint o acción desde la interfaz) → sin
   permiso: `403`.
2. Como `admin`, anular el mismo pago **sin motivo** → rechazo; con motivo → el pago
   queda `ANULADO` con su motivo, **no se borra** y aparece en el historial.
3. **Entonces**: la orden queda libre y admite registrar un pago nuevo correcto; el
   pago anulado no cuenta como liquidación.
4. Intentar anular un pago de una orden ya `ENTREGADO` → `409` (historial
   inmutable).

### E4 — Flujo de Mercado Pago en sandbox (HU3, FR‑005, FR‑006, SC‑004)

1. Como `recepcion`, en una orden `TERMINADO` elegir método `MERCADO_PAGO` → el pago
   nace `PENDIENTE` y la respuesta incluye referencia externa, enlace de pago y modo
   (`sandbox` con credenciales, `simulado` sin ellas).
2. Abrir el enlace, verificar el cobro en el panel del proveedor y marcarlo
   **aprobado** en el sistema → el pago pasa a `PAGADO` y la orden queda liquidada
   (flujo completo en menos de 5 minutos, SC‑004).
3. Repetir con un pago marcado **rechazado** y con otro **cancelado manualmente**
   (pendiente que nunca se confirma) → `RECHAZADO` y `CANCELADO`; en ambos casos la
   orden permite otro intento (HU3‑3, HU3‑4).
4. Revisar tablas y respuestas del flujo completo → **no existe** ningún dato de
   tarjeta ni credencial del proveedor en el sistema ni en el repositorio (RN‑14,
   SC‑004, HU3‑5).

### E5 — Ticket de servicio (HU4, FR‑007 a FR‑009, CA‑4, CA‑5)

1. Como `recepcion`, en una orden pagada → «Generar ticket».
2. **Entonces**: se crea con folio único consecutivo (`T000001-2026`) e incluye folio,
   datos del taller, cliente, vehículo, placas, kilometraje, servicios, refacciones,
   mano de obra, subtotales, total, método de pago, estado del pago y fecha (SC‑003).
3. Volver a generar para la misma orden → devuelve **el mismo** folio (no se
   duplica, HU4‑2).
4. Abrir el ticket → formato de comprobante; imprimir → diálogo de impresión del
   navegador/sistema con la vista completa (FR‑008).
5. Intentar generar el ticket de una orden sin pago → «primero debe registrarse el
   pago» (FR‑009, HU4‑4).

### E6 — Panel de control y dashboard (HU5, HU6, FR‑010, FR‑011, SC‑005, SC‑006)

1. Entrar como `admin` → sección «Panel» → abrir el panel.
2. **Entonces**: carga en menos de 5 segundos (SC‑005) con cuatro bloques: resumen de
   órdenes por estado, citas de hoy/próximas, mantenimientos próximos y vencidos, y
   alertas de stock bajo; los números coinciden al 100 % con los registros
   individuales (SC‑005, HU5‑3).
3. Comparar cada bloque con sus pantallas de origen → sin datos duplicados (CA‑6).
4. Entrar como `recepcion` o `mecanico` → la sección «Panel» no existe en la
   navegación; forzar `GET /api/dashboard` con ese token (panel de red o `curl`) →
   `403 PANEL_SOLO_ADMIN` (HU5‑2, SC‑006).
5. Probar con un bloque vacío (taller recién instalado o sin citas) → estado vacío
   amigable, sin errores (HU6‑4).
6. Registrar una orden, una cita, un mantenimiento próximo/vencido y una refacción en
   stock bajo → cada uno aparece en su bloque al pulsar «Actualizar» (HU6‑1 a HU6‑3).

### E7 — Datos de ejemplo y arranque limpio (FR‑013, SC‑007)

1. Aplicar migraciones + seeds dos veces seguidas.
2. **Entonces**: la segunda corrida no duplica nada (`[omitida] … ya aplicada`); al
   entrar aparecen pagos de ejemplo (efectivo y tarjeta pagados, uno Mercado Pago
   pendiente y uno anulado) y tickets emitidos con folios fijos, sin capturar datos a
   mano (SC‑007); el dashboard muestra información desde el primer arranque.

## Comprobaciones automáticas

- `npm test` en `server/` (Jest: unitarias de `order-total.js`,
  `payment-transitions.js` y la regla de entrega; integración de pagos, tickets y
  dashboard; contrato de las rutas nuevas) en verde.
- `flutter test` en `client/` (providers y widgets nuevos) en verde.
- ESLint del backend en 0 errores y `flutter analyze` en 0 problemas.
