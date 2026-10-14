# Investigación: Pagos, Tickets y Dashboard (Fase 0)

**Funcionalidad**: `004-pagos-tickets-dashboard` | **Fecha**: 2026-10-13
**Entrada**: [plan.md](plan.md) (Contexto Técnico) y [spec.md](spec.md) (aclaraciones
del 2026-10-13)

Este documento resuelve las decisiones técnicas del sprint antes de diseñar datos y
contratos. La especificación no dejó marcadores `[NEEDS CLARIFICATION]`; aquí se
concretan las decisiones que la spec delegó a la planificación (ticket imprimible,
integración de Mercado Pago y forma del panel).

## D1 — Integración de Mercado Pago (sandbox con confirmación manual)

**Decisión**: se implementa un adaptador aislado en
`server/services/payment_gateway/` con una interfaz única
(`crearPreferencia(orden, monto, referencia)` → `{ idExterno, enlace }`) y dos
implementaciones:

- `mercadopago.js`: llama la API REST de Mercado Pago en modo sandbox con
  `MP_ACCESS_TOKEN` (variables de entorno, CA‑7). Sin SDK: `fetch` nativo de Node LTS.
- `simulado.js`: respaldo local que genera un enlace de prueba y un id externo
  ficticio, para entornos sin credenciales ni internet (demo y pruebas automatizadas).

El backend elige la implementación al arrancar: si existe `MP_ACCESS_TOKEN`, usa la
real; si no, la simulada (y el detalle del pago indica el modo usado). El estado del
pago se confirma de forma manual (aclaración 3): el recepcionista verifica en el panel
del proveedor y marca `PAGADO`, `RECHAZADO` o `CANCELADO`.

**Razón**: la constitución exige aislar la integración de Mercado Pago del dominio
(Principio II); el respaldo simulado permite completar las pruebas automatizadas y la
demostración sin depender de credenciales externas; la confirmación manual evita
endpoints públicos (el MVP corre local, sin hosting ni dominio).

**Alternativas consideradas**:
- Webhook del proveedor: descartado por la aclaración 3 y porque exige un endpoint
  público y validación de firmas, inalcanzables en una instalación local.
- SDK oficial de Mercado Pago: descartado por la regla de no agregar dependencias sin
  necesidad; la API REST usada cubre la creación de preferencias.
- Simulación total sin llamada real: descartada porque el CA‑3 pide integración real
  en sandbox cuando hay credenciales.

## D2 — Cálculo del total de la orden

**Decisión**: módulo puro `server/utils/order-total.js` con
`calcularTotal({ manoDeObra, refacciones })`:

- suma `price` de cada partida de mano de obra (`order_labor.price`), tratando `NULL`
  como 0 (el precio es opcional desde el Sprint 2);
- suma `sale_price × quantity` de cada fila de `order_parts`; las filas heredadas sin
  `part_id` usan su precio registrado en la fila (ver D2.1) y las nuevas usan el
  precio vigente del catálogo al momento de cobrar (aclaración 2, FR‑015).

**D2.1 — Precio de las filas heredadas**: `order_parts` no guarda precio; para no
perder el detalle histórico, el cálculo usa el precio vigente del catálogo cuando la
fila tiene `part_id`, y las filas sin `part_id` (heredadas del Sprint 2) se valoran
como 0 con un aviso en el desglose («sin precio registrado»). No se altera la migración
003; si el equipo desea conservar el precio histórico, sería un cambio de alcance
explícito.

**Razón**: el cálculo vive en un módulo puro para probarlo en unidad (estilo
`maintenance-status.js` y `order-transitions.js` de sprints anteriores); usar precios
vigentes evita datos congelados desactualizados (aclaración 2).

**Alternativas consideradas**:
- Congelar el precio al agregar cada ítem: descartado por la aclaración 2.
- Captura manual del total: descartado por la aclaración 2 y por el riesgo de error
  de caja.
- Alterar `order_parts` para agregar columna de precio: descartado por no editar
  migraciones aplicadas ni ampliar el alcance sin aprobación (Principio I).

## D3 — Ticket: persistencia e impresión

**Decisión**: el ticket se persiste en la tabla `tickets` al generarlo (folio único
consecutivo por año, por ejemplo `T000001‑2026`) y la vista se construye en Flutter
(`ticket_screen.dart`) con formato de comprobante; la impresión usa la impresión del
navegador/sistema desde esa vista. No se generan ni se archivan archivos PDF.

**Razón**: la spec asume «ticket imprimible, sin PDF almacenado»; con eso se evitan
dependencias de generación de PDF y de almacenamiento físico, y el CA‑5 (visualizar e
imprimir) queda cubierto. El folio se asigna al generar y no cambia (escenario US4‑2).

**Alternativas consideradas**:
- Generar PDF con librería (pdf, printing): descartado por la regla de no agregar
  dependencias sin necesidad y por el supuesto de la spec.
- Ticket sin persistencia (solo vista): descartado porque la spec pide folio único,
  no duplicado y datos de ejemplo de tickets en los seeds.

## D4 — Forma del panel de control

**Decisión**: un único endpoint `GET /api/dashboard` (solo `ADMIN`) que devuelve el
resumen en una sola respuesta: órdenes por estado, citas de hoy, mantenimientos
próximos/vencidos y alertas de stock bajo, con sus totales. El frontend lo consume con
un provider propio (`dashboard_provider.dart`) y lo refleja en `dashboard_screen.dart`
con bloques y estados vacíos.

**Razón**: SC‑005 exige carga en menos de 5 segundos y coincidencia exacta con los
datos; una sola consulta por bloque, calculada en backend, evita duplicar información
en el cliente (CA‑6) y respeta «sin datos duplicados». Los filtros y estados calculados
ya existentes (mantenimientos, stock bajo) se reutilizan desde sus servicios.

**Alternativas consideradas**:
- Varios endpoints por bloque: descartado por mayor viajes de red sin necesidad y por
  complicar la garantía de coherencia del SC‑005.
- Métricas precalculadas en tablas: descartado por duplicar información (CA‑6) y por
  la escala local del MVP.

## D5 — Regla de entrega condicionada al pago (FR‑014)

**Decisión**: la validación vive en `service_order.service.js`, dentro de
`changeStatus`, justo antes de aplicar la transición a `ENTREGADO`: si la orden no
tiene un pago con estado `PAGADO`, responde `409 PAGO_PENDIENTE` con mensaje claro. La
regla no se toca en `order-transitions.js` (que sigue siendo una función pura del mapa
de estados), para conservar sus pruebas unitarias.

**Razón**: la lógica de negocio vive en `services/` (Principio II); exigir el pago
antes de entregar es la aclaración 1 y protege el cobro (RN‑13 ligado a la orden).

**Alternativas considerada**: evaluarlo en `evaluateTransition`: descartado porque
añadiría una consulta a base de datos a una función pura y rompería sus pruebas.

## D6 — Anulación de pagos (FR‑016)

**Decisión**: `POST /api/payments/:id/anular` con motivo obligatorio, solo `ADMIN`; el
pago pasa a `ANULADO` (nunca se borra), se guarda `anulacion_motivo` y `anulado_por`;
la orden queda libre para registrar un pago nuevo (el cobro se evalúa sobre pagos
`PAGADO`, los anulados no cuentan).

**Razón**: la aclaración 5 exige conservar el historial (RN‑9) y restringir la acción;
el estado `ANULADO` distingue la corrección administrativa del rechazo o cancelación
del proveedor.

**Alternativas consideradas**: edición directa: descartada por perder trazabilidad;
borrado físico: descartado por RN‑9.

## D7 — Estados y transiciones de un pago

**Decisión**: máquina de estados propia del pago (módulo puro
`utils/payment-transitions.js`, estilo `order-transitions.js`):

- `PENDIENTE → PAGADO | RECHAZADO | CANCELADO` (confirmación manual, Mercado Pago);
- `PAGADO → ANULADO` (solo administración, con motivo);
- `RECHAZADO`, `CANCELADO` y `ANULADO` son estados finales (la orden permite un nuevo
  intento).

**Razón**: la spec define los cinco estados y sus salidas; un módulo puro permite
probar la máquina en unidad; los estados finales evitan reintentos ambiguos sobre un
mismo registro.

**Alternativas consideradas**: estados sin máquina (cambios directos): descartado por
consistencia con el patrón de órdenes y para poder probar la regla en unidad.

## D8 — Semillas del sprint

**Decisión**: `004_ejemplos_pagos_tickets.sql` crea pagos de muestra (efectivo pagado,
tarjeta pagada, un Mercado Pago pendiente y uno anulado) y tickets de las órdenes de
ejemplo ya pagadas, con ids fijos y sentencias idempotentes (estilo 003).

**Razón**: la constitución (Principio III) exige que la aplicación muestre información
al instalar y que los seeds no dupliquen al correr varias veces; el dashboard y el
ticket necesitan datos reales para la demostración.

**Alternativas consideradas**: sin seeds: descartado por la constitución; seeds no
idempotentes: descartado explícitamente por el insumo del sprint.
