# Contrato de interfaz (Flutter): precios por rol y marcas del ticket

Relacionado: FR-004, FR-018, FR-020, FR-022, FR-024 a FR-026, FR-032 a FR-034; US5; `docs/design-system.md`.

**Regla general (doble condición)**: una pantalla muestra un precio solo si (1) el rol lo permite y (2) el campo vino en la respuesta. El servidor es la fuente de seguridad (principio IV); Flutter solo evita mostrar columnas vacías o confusas.

## Campos de precio por pantalla y rol

| Pantalla | Campo | ADMIN | RECEPTIONIST | MECHANIC |
|---|---|:-:|:-:|:-:|
| `parts_screen.dart` (listado) | «Compra» | ✔ | — | — |
| | «Venta» | ✔ | ✔ | — |
| `part_detail_screen.dart` | «Precio de compra» | ✔ | — | — |
| | «Precio de venta» | ✔ | ✔ | — |
| `part_form_screen.dart` (solo ADMIN) | precios + aviso D-07 | ✔ | n/a | n/a |
| `service_order_detail_screen.dart` | refacciones: precio unitario e importe | ✔ | ✔ | — |
| | refacciones: «sin precio registrado» | ✔ | ✔ | — |
| | mano de obra: precio (captura y vista) | ✔ | ✔ | ✔ (como hoy) |
| Selector de refacciones al agregar a la orden | precios | ✔ | ✔ | — (ve nombre, código, categoría, marca, existencia, stock mínimo, stock bajo y activa; ningún precio) |
| `payment_form_screen.dart`, `ticket_screen.dart`, panel | todo | ✔ | ✔ (salvo panel) | sin acceso (como hoy) |

«—» = el renglón o la columna no se dibuja (no se muestra «$0.00» ni «—»).

## Validación del precio de la mano de obra (FR-032)

En `utils/validators.dart`, la misma regla que los precios de refacciones: numérico, ≥ 0, máximo dos decimales y ≤ 999,999.99. Mensaje junto al campo; el servidor vuelve a validar.

## Marcas del ticket (`ticket_screen.dart`)

| Marca | Cuándo | Presentación (tokens del sistema de diseño) |
|---|---|---|
| «Formato anterior» | `formatoAnterior: true` | Chip `warning` en el encabezado y texto de ayuda: «Generado a partir de los datos registrados al migrar». |
| «Pago anulado» | `pagoAnulado: true` | Chip `danger` en el encabezado y aviso: «Este comprobante corresponde a un pago anulado; no es el ticket vigente de la orden». |
| Nota del desglose | `desgloseNoCoincide: true` | Aviso `warning` sobre los totales: «El desglose no coincide con lo cobrado». El total mostrado es el importe pagado. |
| «Sin precio registrado» | `refacciones[].aviso` | Texto secundario `warning` en la línea. |

Las marcas se ven en pantalla y en la versión imprimible. Radios de 8 px; transiciones suaves; solo colores de los tokens.

## Varios tickets por orden

En el detalle de la orden, «Ver ticket» abre el **vigente**. Si la orden tiene tickets de pagos anulados, se muestra la lista «Tickets anteriores» con folio, fecha y el chip «Pago anulado».

## Aviso D-07 (`part_form_screen.dart`)

Si la respuesta trae `advertencias` con `PRECIO_VENTA_MENOR_A_COMPRA`, se muestra un aviso `warning`: «Se guardó. El precio de venta es menor que el precio de compra». El guardado no se bloquea.

## Pago pendiente desfasado (`payment_form_screen.dart` o pantalla de confirmación)

Ante `409 IMPORTE_DESFASADO`, se muestra un diálogo con el importe del pago, el total actual y la diferencia, y el recordatorio de revisar en el panel de Mercado Pago si el cliente ya pagó antes de generar un pago nuevo.

## Cambio de rol con la sesión abierta (R-12) — DESCARTADO

> **DESCARTADO (2026-11-14)**: el responsable no aprobó cerrar las sesiones al cambiar el rol. **No se implementa** y no genera tareas, ni en el servidor ni en Flutter.

**Limitación conocida** (Supuestos y Fuera de alcance de la spec): si un administrador cambia el rol de un usuario con la sesión abierta, el servidor aplica el rol nuevo desde la siguiente petición, pero Flutter sigue mostrando la interfaz del rol anterior hasta que la persona vuelva a iniciar sesión. Mientras tanto puede ver menús que responden `403`, o columnas sin datos porque el servidor ya no envía esos campos. Los precios siguen protegidos, porque el servidor decide qué campos envía según el rol actual. No se agrega ningún mensaje nuevo.
