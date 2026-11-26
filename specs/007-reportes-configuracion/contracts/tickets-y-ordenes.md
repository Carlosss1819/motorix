# Contrato: cambios en órdenes, mantenimientos y tickets

## POST /api/service-orders/:id/servicios (cambio)

Campo nuevo opcional `tipoServicioId` (entero). Debe ser un tipo **activo**; si no existe o está inactivo: `400 TIPO_SERVICIO_INVALIDO`. Sin él, la línea queda sin tipo (como hasta ahora). Cuando la línea tiene tipo, la respuesta agrega `servicio.tipoServicioId` y `servicio.tipoServicio` (nombre); sin tipo, la respuesta queda igual que antes.

## GET /api/service-orders/:id (cambio)

Cada servicio con tipo agrega `tipoServicioId` y `tipoServicio`; las líneas sin tipo (y las anteriores al sprint) no traen esos campos (el cliente los trata como `null`).

## POST /api/maintenance (cambio)

Sin `antelacionDias`/`antelacionKm` en el cuerpo, se usan los márgenes de la configuración (FR-005) en lugar de 30/500 fijos. La propuesta de fecha y kilometraje (FR-011) la hace el formulario con el tipo elegido; el contrato de guardado no cambia.

## Ticket (cambio en la copia v2)

- `taller`: datos de la configuración vigente al emitir (FR-002).
- `proximosServicios` (solo tickets emitidos desde este sprint):

```json
"proximosServicios": [
  { "tipoServicio": "Cambio de aceite", "fecha": "2027-05-25", "kilometraje": 15010 }
]
```

`fecha` = fecha de emisión + `intervaloDias` (o `null`); `kilometraje` = kilometraje de entrada + `intervaloKm` (o `null`). Un elemento por tipo distinto; lista vacía si no hay tipos. `formatoVersion` sigue en `2`. Los tickets anteriores no traen el campo (el cliente lo trata como lista vacía).
