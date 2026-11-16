-- Migración 005: Sprint 5 — precios congelados y tickets por pago (SOLO ESQUEMA).
-- Script INMUTABLE: no editar tras aplicarse; los cambios van en nuevos scripts numerados.
-- Fuente de verdad: specs/005-precios-refacciones-cobro/data-model.md y research.md (R-01, R-02).
--
-- Solo DDL, en tres sentencias atómicas (MySQL hace commit implícito en cada
-- DDL, así que los datos van aparte, en el 006, dentro de una transacción).
--
-- Es la PRIMERA migración que reemplaza una restricción: cambia la unicidad de
-- los tickets de «uno por orden» (uq_tickets_service_order) a «uno por pago»
-- (uq_tickets_payment), porque una orden con un pago anulado y otro nuevo
-- necesita dos tickets (FR-033). NO borra ni modifica datos: no se elimina
-- ninguna fila ni columna; solo cambia qué combinación debe ser única
-- (plan, «Registro de complejidad»).
--
-- Antes de aplicarla en una base con datos: respaldo con mysqldump y la
-- consulta de duplicados (debe devolver 0 filas):
--   SELECT payment_id, COUNT(*) AS n FROM tickets GROUP BY payment_id HAVING n > 1;

-- (a) Precio de venta congelado en cada línea de refacción (FR-006, FR-007).
--     NULL = «sin precio registrado» (vale 0 en el total).
ALTER TABLE order_parts
  ADD COLUMN unit_price DECIMAL(10,2) NULL AFTER quantity;

-- (b) Copia del ticket con versión de formato y unicidad por pago (FR-019,
--     FR-033). Una sola sentencia: si hubiera pagos repetidos en tickets, falla
--     completa sin cambiar nada. El índice simple por orden se agrega antes de
--     quitar el único, porque la FK fk_tickets_order lo necesita.
ALTER TABLE tickets
  ADD COLUMN content JSON NULL,
  ADD COLUMN format_version SMALLINT NULL,
  ADD KEY idx_tickets_service_order (service_order_id),
  DROP INDEX uq_tickets_service_order,
  ADD UNIQUE KEY uq_tickets_payment (payment_id);

-- (c) Motivo de la cancelación de un pago (FR-016): IMPORTE_DESFASADO o MANUAL.
ALTER TABLE payments
  ADD COLUMN cancellation_reason VARCHAR(30) NULL;
