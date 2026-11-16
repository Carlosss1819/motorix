# Guía de validación (quickstart): Precios de refacciones y cobro completo

**Funcionalidad**: [spec.md](./spec.md) · **Plan**: [plan.md](./plan.md) · **Modelo**: [data-model.md](./data-model.md) · **Contratos**: [contracts/](./contracts/README.md)

Esta guía sirve para comprobar el sprint de extremo a extremo una vez implementado. No contiene código de la aplicación. Los comandos son para Windows (PowerShell), desde la raíz del repositorio.

## 1. Requisitos previos

- MySQL 8 local con las bases `motorix_v2` (desarrollo) y `motorix_v2_test` (pruebas), y el usuario `motorix_app` (ver `database/README.md`).
- Node 24 (LTS) y Flutter instalados.
- `server/.env` con las variables de siempre, más `MP_PREFERENCIA_VIGENCIA_HORAS` (opcional, 24 por defecto; documentada en `server/.env.example`).
- Línea base antes de empezar:
  - en `server/`, `npm test` → **49 suites y 411 pruebas** aprobadas;
  - en `client/`, `flutter test` → **127 pruebas** aprobadas.

## 2. Verificación previa

Antes de aplicar las migraciones en una base con datos (por ejemplo, `motorix_v2`):

1. **Respaldo** (obligatorio). Te pedirá la contraseña de `motorix_app`:
   ```powershell
   mysqldump -u motorix_app -p --single-transaction --routines motorix_v2 > respaldo-motorix_v2-antes-005.sql
   ```
   Debes ver un archivo `.sql` de varios KB. Guárdalo fuera del repositorio; no se versiona.
2. **Sin pagos repetidos en tickets** (condición de R-01). Debe devolver **0 filas**:
   ```sql
   SELECT payment_id, COUNT(*) AS n FROM tickets GROUP BY payment_id HAVING n > 1;
   ```
   Si devuelve filas, **no** apliques el `005` y avisa: hay que revisar esos tickets antes.

## 3. Aplicar migraciones y datos de ejemplo

```powershell
./database/scripts/aplicar-migraciones.ps1 -DbPassword '<contraseña de motorix_app>'
./database/scripts/aplicar-migraciones.ps1 -DbPassword '<contraseña de motorix_app>' -Seeds
```

Resultado esperado: se aplican `005_…` y `006_…` (y aparecen en `schema_migrations`), y después los seeds `001` a `005` sin errores. Volver a correr el segundo comando no duplica registros.

### Si el `005` falla a la mitad

Revisa qué parte ya entró:

```sql
SELECT COLUMN_NAME FROM information_schema.COLUMNS
 WHERE TABLE_SCHEMA = DATABASE()
   AND ((TABLE_NAME = 'order_parts' AND COLUMN_NAME = 'unit_price')
     OR (TABLE_NAME = 'tickets' AND COLUMN_NAME IN ('content', 'format_version'))
     OR (TABLE_NAME = 'payments' AND COLUMN_NAME = 'cancellation_reason'));
SELECT INDEX_NAME FROM information_schema.STATISTICS
 WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'tickets';
```

Restaura el respaldo del paso 2 y vuelve a intentar. No repares la base a mano.

### Si el `006` falla

La transacción se revierte sola. Corrige la causa y vuelve a correr el script; solo actúa donde las columnas nuevas siguen en `NULL`.

## 4. Verificar la migración (SC-011 y SC-012)

```sql
-- SC-011: debe dar 0 en las dos columnas.
SELECT
  SUM(op.part_id IS NOT NULL AND p.sale_price IS NOT NULL AND (op.unit_price IS NULL OR op.unit_price <> p.sale_price)) AS lineas_mal_congeladas,
  SUM(op.part_id IS NOT NULL AND p.sale_price IS NULL AND op.unit_price IS NOT NULL) AS sin_precio_con_valor
FROM order_parts op LEFT JOIN parts p ON p.id = op.part_id;

-- SC-012: debe dar 0.
SELECT COUNT(*) AS tickets_mal_copiados
FROM tickets t JOIN payments pa ON pa.id = t.payment_id
WHERE t.format_version = 1
  AND (t.content IS NULL OR CAST(JSON_EXTRACT(t.content, '$.total') AS DECIMAL(10,2)) <> pa.amount);
```

Esta consulta de SC-011 solo vale **justo después** de migrar. Después, un cambio de precio en el catálogo hace que difieran, y eso es lo correcto.

En `motorix_v2`, el ticket de la orden 5 (pagado 1390.00, desglose 1090.00) debe tener `desgloseNoCoincide: true` y la nota «El desglose no coincide con lo cobrado».

## 5. Pruebas automatizadas

```powershell
cd server; npm test
cd ../client; flutter test
```

Resultado esperado: las 49 suites y 411 pruebas de la línea base, más las nuevas del sprint, todas aprobadas, sin timeouts ni el aviso «A worker process has failed to exit gracefully». Flutter: las 127 de la línea base más las nuevas. Guarda las salidas en `docs/evidencias/sprint 5/`.

## 6. Recorrido demostrable (spec, pasos 1 a 9)

Con la app corriendo (`arrancar.bat`) y los datos de ejemplo:

| Paso | Quién | Acción | Resultado esperado |
|---|---|---|---|
| 1 | admin | Alta de una refacción con precio de venta menor que el de compra | Se guarda con el aviso ámbar (D-07). Con 3 decimales o > 999,999.99 se rechaza. |
| 2 | mecánico | Agregar la refacción a su orden | No ve ningún precio de la refacción; sí ve el precio de la mano de obra. |
| 3 | mecánico | Pasar la orden a Terminada | — |
| 4 | recepción | Ver el total | Mano de obra + refacciones a precio congelado, exacto al centavo. |
| 5 | recepción | Registrar el pago por el total | Se acepta; con otro importe, `MONTO_NO_COINCIDE`. |
| 6 | recepción | Generar el ticket | Desglose con cantidad, precio unitario e importe; sin marcas. |
| 7 | admin | Cambiar el precio de venta en el catálogo | — |
| 8 | recepción | Volver a abrir la orden, el pago y el ticket | No cambian. |
| 9 | recepción | Abrir el ticket de ejemplo con una línea sin precio | Muestra «sin precio registrado». |

Comprobaciones adicionales:
- **Mecánico** (FR-035, FR-036): pagos, tickets y panel responden 403; el catálogo y el detalle de la orden no traen precios de refacción ni totales.
- **Inmovilización** (FR-021, FR-022): con el pago `PAGADO`, agregar un servicio da `ORDEN_PAGADA`. Después de que el admin anula el pago, sí se permite. Al cobrar de nuevo se genera un ticket nuevo y el anterior muestra «Pago anulado».
- **D-04**: con un pago de Mercado Pago pendiente, quitar un servicio y luego confirmarlo da `IMPORTE_DESFASADO`, el pago queda `CANCELADO` con motivo «importe desfasado» y se puede generar uno nuevo.
- **Expiración de Mercado Pago (R-09)**: en sandbox real, crear un cobro y comprobar en la respuesta de la preferencia que trae `expires: true` y `expiration_date_to` a 24 horas. Es una prueba de humo manual, porque la documentación de México no se pudo verificar.
