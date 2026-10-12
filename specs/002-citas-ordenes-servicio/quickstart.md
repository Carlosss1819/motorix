# Guía de Validación Rápida (Fase 1)

**Funcionalidad**: Gestión de Citas y Órdenes de Servicio (`002-citas-ordenes-servicio`)
**Fecha**: 2026-10-12 | **Plan**: [plan.md](plan.md) | **Contratos**: [contracts/](contracts/)

Guía de ejecución y verificación de extremo a extremo. No incluye código de
implementación; los detalles de construcción quedan en `tasks.md`.

## Requisitos previos

- Node.js LTS instalado.
- Flutter SDK instalado.
- MySQL local (instalación nativa) y PowerShell disponible.
- Copia de `.env.example` como `.env` con `DB_HOST`, `DB_PORT`, `DB_USER`,
  `DB_PASSWORD`, `DB_NAME` (usuario dedicado `motorix_app`, nunca `root`).

## Preparación del entorno

| Paso | Comando / acción | Resultado esperado |
|------|------------------|--------------------|
| 1 | `database/scripts/aplicar-migraciones.ps1 -DbPassword '<contraseña>'` | Tablas del Sprint 1 y las 6 nuevas (`appointments`, `service_orders`, `order_status_history`, `order_services`, `order_labor`, `order_parts`) registradas en `schema_migrations` |
| 2 | `database/scripts/aplicar-migraciones.ps1 -DbPassword '<contraseña>' -Seeds` | ≥ 5 citas y ≥ 4 órdenes de ejemplo en estados variados (SC‑006) |
| 3 | Arrancar el backend desde `server/` (`npm run dev`) | API escuchando en el puerto configurado |
| 4 | Arrancar el frontend desde `client/` (`flutter run`) | Aplicación abierta en el login |

> Los pasos 1 y 2 deben poder repetirse sin duplicar registros (SC‑006, FR‑021).

## Escenarios de validación

### V1 — Flujo demostrable completo del sprint (SC‑005)

1. Entrar como `recepcion` y crear una cita (cliente, vehículo, fecha, hora, motivo).
2. Marcar la cita como recibida.
3. Crear la orden desde la precarga (confirma o ajusta el motivo) → estado `RECIBIDO`.
4. Asignar el mecánico desde el detalle de la orden.
5. Entrar como `mecanico`, abrir **Mis órdenes** y pasar la orden a `DIAGNOSTICO`.
6. Guardar diagnóstico, agregar un servicio con su duración, un repuesto y una
   recomendación.
7. Avanzar a `EN_REPARACION` y luego a `TERMINADO`.
8. Volver como `recepcion` y entregar → `ENTREGADO` con fecha de entrega.

**Esperado**: la secuencia completa se completa sin errores en una sola pasada; cada
cambio quedó en el historial con usuario y fecha (SC‑004, SC‑005).
Ver [contracts/service-orders.md](contracts/service-orders.md).

### V2 — Órdenes sin cliente o vehículo huérfanos (SC‑002, FR‑002)

1. Intentar crear una orden con un cliente que no tiene vehículos.
2. Intentar crear una orden enviando un `vehiculoId` que pertenezca a otro cliente
   (por ejemplo con `curl`).

**Esperado**: en ambos casos `400` con mensaje en español y ninguna orden creada.

### V3 — Aislamiento por rol del mecánico (SC‑003, FR‑010)

1. Con `mecanico` autenticado, abrir **Mis órdenes**.
2. Pedir `GET /api/service-orders` con su token vía `curl`.
3. Pedir `GET /api/service-orders/<id-de-otro-mecanico>` con su token.

**Esperado**: solo aparecen sus órdenes; el intento 3 responde `403`.

### V4 — Transiciones de estado válidas e inválidas (SC‑004, FR‑014, CA‑5)

1. Sobre una orden `RECIBIDO`, intentar pasarla directamente a `ENTREGADO`.
2. Intentar que un `RECEPTIONIST` pase una orden a `EN_REPARACION`.
3. Recorrer la secuencia correcta hasta `ENTREGADO` y luego intentar cambiar su estado.

**Esperado**: `409` con mensaje claro en los intentos 1 y 4, `403` en el intento 2, y
`200` con historial actualizado en el recorrido correcto.

### V5 — Kilometraje de entrada (SC‑008, FR‑018, RN‑04)

1. Crear la primera orden de un vehículo con kilometraje 60000 → se acepta.
2. Crear una segunda orden del mismo vehículo con kilometraje 50000 → `400`.
3. Repetir el paso 2 como `ADMIN` incluyendo `correccionKilometraje` con motivo.

**Esperado**: el primer valor se guarda, el segundo se rechaza y el tercero se guarda
con el motivo registrado en la orden.

### V6 — Citas: conflictos, cancelación y no presentadas (FR‑006, FR‑008)

1. Crear dos citas con la misma fecha, hora y vehículo → `409` con aviso; reenviar con
   `confirmar: true`.
2. Cancelar una cita `PROGRAMADA` con motivo opcional y verificar que sale del listado
   activo del día.
3. Dejar una cita `PROGRAMADA` de días anteriores y volver a consultar el listado.

**Esperado**: aviso de conflicto sin guardar a la primera; `CANCELADA` tras confirmar
(esta acción pide confirmación en la interfaz); la cita vieja aparece como
`NO_PRESENTADA` (escenarios 2‑5 de la HU2).

### V7 — Panel de recepción con datos reales (HU6)

1. Entrar como `recepcion` con citas de hoy y órdenes abiertas creadas.
2. Abrir **Inicio**; cambiar el día a uno sin actividades.

**Esperado**: citas del día con hora, cliente, vehículo y estado; órdenes pendientes
con estado y mecánico; mensaje de "sin actividades" (y no un error) cuando no hay nada.

### V8 — Órdenes entregadas son inmutables (SC‑007, RN‑09, FR‑016)

1. Sobre una orden `ENTREGADO`, intentar editarla, agregar servicios o repuestos y
   cambiar su estado vía `curl`.

**Esperado**: `409` en todos los intentos y sin cambios en la interfaz.

## Pruebas automatizadas

| Capa | Comando | Cobertura exigida del sprint |
|------|---------|------------------------------|
| Unitarias (backend) | `cd server && npm run test:unit` | Máquina de transiciones (todas las válidas y varias inválidas, CA‑8), validadores de cita y orden, permisos por transición |
| Integración y contrato (backend) | `cd server && npm run test:integration` | Citas y órdenes de extremo a extremo contra `motorix_v2_test` (nunca la base principal) |
| Backend completo + lint | `cd server && npm test` y `cd server && npm run lint` | Sin regresiones del Sprint 1 |
| Frontend | `cd client && flutter test` | Providers y widgets nuevos de citas y órdenes |

## Checklist de cierre del Sprint 2 (`docs/guia-spec-kit.md`)

- [ ] Registrar/consultar/modificar/cancelar cita.
- [ ] Crear orden de servicio asociada a cliente y vehículo.
- [ ] Mecánico ve sus órdenes asignadas.
- [ ] Mecánico registra diagnóstico, servicios y recomendaciones.
- [ ] Cambios de estado respetan `RECIBIDO → DIAGNOSTICO → EN_REPARACION → TERMINADO → ENTREGADO` (con `ESPERANDO_REFACCION` disponible).
- [ ] Kilometraje de entrada registrado y validado (no menor al previo sin corrección explícita).
- [ ] Pruebas pasan; sin secretos.
