-- Migración 006: Sprint 5 — datos del precio congelado y copia de los tickets (SOLO DATOS).
-- Script INMUTABLE: no editar tras aplicarse; los cambios van en nuevos scripts numerados.
-- Fuente de verdad: specs/005-precios-refacciones-cobro/data-model.md y research.md (R-03, R-04).
--
-- Va dentro de una transacción: si algo falla, se revierte completo y se puede
-- volver a correr. Es repetible: solo escribe donde las columnas nuevas del 005
-- siguen en NULL, así que una segunda ejecución no cambia nada.
-- Sin DELIMITER ni procedimientos: tests/helpers/db.js lo ejecuta con mysql2
-- (multipleStatements) y aplicar-migraciones.ps1 con SOURCE.

START TRANSACTION;

-- (a) FR-010, SC-011: cada línea con refacción del catálogo toma el precio de
--     venta vigente al migrar. Si la refacción no tiene precio, la línea queda
--     en NULL («sin precio registrado»). Las líneas heredadas sin part_id no
--     entran en el JOIN y también quedan en NULL.
UPDATE order_parts op
JOIN parts p ON p.id = op.part_id
SET op.unit_price = p.sale_price
WHERE op.unit_price IS NULL;

-- (b) FR-019, FR-020, SC-012: copia de cada ticket existente en la versión 1
--     («formato anterior»), con la forma del ticket del Sprint 4 y los precios
--     congelados del paso (a).
--     - `total` es SIEMPRE lo cobrado (payments.amount).
--     - Si el desglose (mano de obra + refacciones) no suma lo cobrado, la copia
--       lleva `desgloseNoCoincide: true` y la nota.
--     - Las refacciones van anidadas en el primer servicio, como las armaba el
--       Sprint 4; sin servicios, se abre el concepto «Refacciones».
UPDATE tickets t
JOIN payments pa ON pa.id = t.payment_id
JOIN service_orders so ON so.id = t.service_order_id
JOIN clients c ON c.id = so.client_id
JOIN vehicles v ON v.id = so.vehicle_id
JOIN users u ON u.id = t.issued_by
LEFT JOIN (
  SELECT service_order_id, SUM(COALESCE(price, 0)) AS subtotal
  FROM order_labor
  GROUP BY service_order_id
) mo ON mo.service_order_id = t.service_order_id
LEFT JOIN (
  SELECT service_order_id,
         SUM(IF(part_id IS NULL OR unit_price IS NULL, 0, unit_price * quantity)) AS subtotal
  FROM order_parts
  GROUP BY service_order_id
) rf ON rf.service_order_id = t.service_order_id
SET t.content = JSON_OBJECT(
      'folio', t.folio,
      'ordenId', t.service_order_id,
      'pagoId', t.payment_id,
      'emitidoPor', u.username,
      'emitidoEn', DATE_FORMAT(t.issued_at, '%Y-%m-%d %H:%i:%s'),
      'taller', JSON_OBJECT(
        'nombre', 'Motorix',
        'direccion', 'Av. Ejemplo 123, Col. Centro',
        'telefono', '55-0000-0000'),
      'cliente', JSON_OBJECT('id', c.id, 'nombre', c.name, 'telefono', c.phone),
      'vehiculo', JSON_OBJECT(
        'id', v.id, 'marca', v.brand, 'modelo', v.model, 'anio', v.year,
        'placas', v.plates, 'kilometraje', so.entry_mileage),
      'servicios', COALESCE(
        (SELECT JSON_ARRAYAGG(JSON_OBJECT(
                  'descripcion', l.description,
                  'manoDeObra', COALESCE(l.price, 0),
                  'avisoManoDeObra', IF(l.price IS NULL, 'sin precio registrado', NULL),
                  'refacciones', IF(
                    l.id = (SELECT MIN(l2.id) FROM order_labor l2
                            WHERE l2.service_order_id = t.service_order_id),
                    COALESCE(
                      (SELECT JSON_ARRAYAGG(JSON_OBJECT(
                                'codigo', cat.code,
                                'nombre', COALESCE(cat.name, lp.description),
                                'cantidad', lp.quantity,
                                'precioUnitario', IF(lp.part_id IS NULL OR lp.unit_price IS NULL, 0, lp.unit_price),
                                'subtotal', IF(lp.part_id IS NULL OR lp.unit_price IS NULL, 0, lp.unit_price * lp.quantity),
                                'aviso', IF(lp.part_id IS NULL OR lp.unit_price IS NULL, 'sin precio registrado', NULL)))
                       FROM order_parts lp
                       LEFT JOIN parts cat ON cat.id = lp.part_id
                       WHERE lp.service_order_id = t.service_order_id),
                      JSON_ARRAY()),
                    JSON_ARRAY())))
         FROM order_labor l
         WHERE l.service_order_id = t.service_order_id),
        (SELECT JSON_ARRAY(JSON_OBJECT(
                  'descripcion', 'Refacciones',
                  'manoDeObra', 0,
                  'avisoManoDeObra', NULL,
                  'refacciones', JSON_ARRAYAGG(JSON_OBJECT(
                    'codigo', cat.code,
                    'nombre', COALESCE(cat.name, lp.description),
                    'cantidad', lp.quantity,
                    'precioUnitario', IF(lp.part_id IS NULL OR lp.unit_price IS NULL, 0, lp.unit_price),
                    'subtotal', IF(lp.part_id IS NULL OR lp.unit_price IS NULL, 0, lp.unit_price * lp.quantity),
                    'aviso', IF(lp.part_id IS NULL OR lp.unit_price IS NULL, 'sin precio registrado', NULL)))))
         FROM order_parts lp
         LEFT JOIN parts cat ON cat.id = lp.part_id
         WHERE lp.service_order_id = t.service_order_id
         HAVING COUNT(*) > 0),
        JSON_ARRAY()),
      'subtotalManoDeObra', COALESCE(mo.subtotal, 0),
      'subtotalRefacciones', COALESCE(rf.subtotal, 0),
      'total', pa.amount,
      'metodoPago', pa.method,
      'fecha', DATE_FORMAT(t.issued_at, '%Y-%m-%d'),
      'formatoVersion', 1,
      'desgloseNoCoincide', IF(
        COALESCE(mo.subtotal, 0) + COALESCE(rf.subtotal, 0) <> pa.amount,
        CAST('true' AS JSON), CAST('false' AS JSON)),
      'nota', IF(
        COALESCE(mo.subtotal, 0) + COALESCE(rf.subtotal, 0) <> pa.amount,
        'El desglose no coincide con lo cobrado', NULL)
    ),
    t.format_version = 1
WHERE t.content IS NULL;

COMMIT;
