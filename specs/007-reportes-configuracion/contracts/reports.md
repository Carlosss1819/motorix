# Contrato: Reportes (`/api/reports`) — Entrega B

Solo **ADMIN** (FR-038). Query común: `desde`, `hasta` (`AAAA-MM-DD`, obligatorios, `desde <= hasta`, máximo 366 días; si no: `400 RANGO_INVALIDO`), `formato` (`json` por defecto o `csv`).

Con `formato=csv`: `200`, `Content-Type: text/csv; charset=utf-8`, `Content-Disposition: attachment; filename="<reporte>_<desde>_<hasta>.csv"`, BOM al inicio, mismas filas y cifras que el JSON (FR-037).

| Ruta | Periodo | Filas |
|------|---------|-------|
| `GET /api/reports/ingresos` | pagos `PAGADO` por fecha de creación del pago | `total`, `pagos`, `porMetodo[{metodo,total,pagos}]`, `porDia[{fecha,total,pagos}]` |
| `GET /api/reports/servicios` | órdenes que pasaron a `TERMINADO` en el rango | `elementos[{tipoServicio | descripcion, veces, manoDeObra}]`, máximo 50 |
| `GET /api/reports/productividad` | mismo | `elementos[{mecanicoId, mecanico, ordenesTerminadas, manoDeObra}]` |
| `GET /api/reports/refacciones` | mismo | `elementos[{refaccionId, codigo, nombre, cantidad, costo | null, venta, margen | null, aviso}]`, `totales{costo, venta, margen}` (sin las líneas "sin costo registrado") |
| `GET /api/reports/rotacion` | movimientos `SALIDA` del rango | `elementos[{refaccionId, codigo, nombre, salidas, existencia, rotacion | null, aviso}]` ("sin existencia" si existencia 0) |

Importes como número con 2 decimales, calculados en centavos enteros (FR-032, CA-7).
