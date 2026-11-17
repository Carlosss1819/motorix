# Contrato: clientes por avisar (`/api/client-notices`)

Rutas con `authenticate` y `authorize('ADMIN', 'RECEPTIONIST')`. MECHANIC recibe **403 `ROL_NO_AUTORIZADO`** (FR-022).

## `GET /api/client-notices`

**200**:

```json
{
  "elementos": [
    {
      "clave": "ORDEN:60003",
      "motivo": "VEHICULO_LISTO",
      "motivoTexto": "Vehículo listo",
      "cliente": { "id": 60001, "nombre": "[Sprint 6] Laura Méndez", "telefono": "5551006001" },
      "vehiculo": { "id": 60002, "descripcion": "Honda Civic 2019", "placas": "NOT0002" },
      "fecha": "2026-11-15",
      "destino": { "pantalla": "ORDEN", "id": 60003 }
    }
  ],
  "total": 1
}
```

- Motivos: `VEHICULO_LISTO` (orden `TERMINADO`), `CITA_MANANA` (cita de mañana `PROGRAMADA`/`RECIBIDA`), `MANT_VENCIDO`, `MANT_PROXIMO`.
- Orden: motivo (en el orden anterior) y luego `fecha` ascendente (FR-029). Sin paginación.
- Excluye los hechos ya avisados. Un cliente puede aparecer varias veces (una por hecho).
- Sin importes.

## `POST /api/client-notices`

**Cuerpo**: `{ "clave": "ORDEN:60003" }`.

**201**:

```json
{
  "id": 60001,
  "clave": "ORDEN:60003",
  "motivo": "VEHICULO_LISTO",
  "clienteId": 60001,
  "avisadoPor": { "id": 2, "nombre": "recepcion" },
  "avisadoEn": "2026-11-16T10:30:00"
}
```

**Errores**:

| HTTP | `codigo` | Cuándo |
|---|---|---|
| 400 | `VALIDACION` | falta `clave` o formato inválido |
| 404 | `HECHO_NO_VIGENTE` | la clave no está en la lista actual (no existe, ya no cumple o es de otro rol) |
| 409 | `YA_AVISADO` | el hecho ya se marcó (incluye la carrera de dos recepcionistas) |
| 403 | `ROL_NO_AUTORIZADO` | MECHANIC |
| 401 | `SESION_REQUERIDA` | sin sesión (código real del middleware `authenticate`) |
