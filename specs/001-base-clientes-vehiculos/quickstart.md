# Guía de Validación Rápida (Fase 1)

**Funcionalidad**: Base del Sistema, Clientes y Vehículos (`001-base-clientes-vehiculos`)
**Fecha**: 2026-10-11 | **Plan**: [plan.md](plan.md) | **Contratos**: [contracts/](contracts/)

Guía de ejecución y verificación de extremo a extremo. No incluye código de
implementación; los detalles de construcción quedan en `tasks.md`.

## Requisitos previos

- Node.js LTS instalado.
- Flutter SDK instalado.
- MySQL local (instalación nativa) y PowerShell disponible.
- Copia de `.env.example` como `.env` con `DB_HOST`, `DB_PORT`, `DB_USER`,
  `DB_PASSWORD`, `DB_NAME` (usuario dedicado `motorix_app`, nunca `root`).
  `.env` debe estar en `.gitignore` (SC‑006).

## Preparación del entorno

| Paso | Comando / acción | Resultado esperado |
|------|------------------|--------------------|
| 1 | Ejecutar `database/scripts/crear-entorno.ps1` | Base local y usuario `motorix_app` creados |
| 2 | Ejecutar `database/scripts/aplicar-migraciones.ps1` | Tablas `users`, `clients`, `vehicles` creadas; registro en `schema_migrations` (CA‑6) |
| 3 | Ejecutar los seeds de `database/seeds/` | ≥ 3 clientes, 3 vehículos y 3 usuarios de ejemplo con contraseñas con hash (SC‑004, FR‑009) |
| 4 | Arrancar el backend desde `server/` (`npm run dev` o equivalente) | API escuchando en el puerto configurado |
| 5 | Arrancar el frontend desde `client/` (`flutter run`) | Aplicación abierta en el login |

> Los pasos 2 y 3 deben poder repetirse sin duplicar registros (SC‑005).

## Escenarios de validación

### V1 — Flujo demostrable del sprint (SC‑001)

1. Iniciar sesión con `admin` (usuario) y cerrar sesión.
2. Iniciar sesión con el correo de `admin` en el mismo campo (FR‑002).
3. Registrar un cliente nuevo (nombre y teléfono obligatorios).
4. Registrar un vehículo eligiéndolo como propietario (RN‑1).
5. Abrir la ficha del cliente: el vehículo aparece asociado (CA‑4).

**Esperado**: todo el recorrido en menos de 3 minutos y los datos persisten tras
reiniciar la aplicación (SC‑003). Ver [contracts/clients.md](contracts/clients.md) y
[contracts/vehicles.md](contracts/vehicles.md).

### V2 — Autorización por rol (SC‑002)

1. Iniciar sesión como `recepcion`: ve Inicio, Clientes, Vehículos y Mi cuenta.
2. Intentar `GET /api/users` con el token de recepcionista (por ejemplo, con curl).
3. Iniciar sesión como `mecanico`: solo ve Inicio y Mi cuenta.
4. Intentar `GET /api/clients` con el token de mecánico.

**Esperado**: `403` en los intentos 2 y 4, no importa que la pantalla no esté visible.

### V3 — Credenciales y bloqueo (FR‑003, R‑03)

1. Intentar iniciar sesión con una contraseña incorrecta 5 veces seguidas.
2. Reintentar con la contraseña correcta.

**Esperado**: mensaje genérico en los 5 intentos (no revela si falló el usuario o la
contraseña) y `423` cuenta bloqueada 15 minutos en el intento 6.

### V4 — Sesión (FR‑004, aclaración Q1)

1. Iniciar sesión y dejar la aplicación sin usar 30 minutos.
2. Volver a usar una pantalla protegida.

**Esperado**: redirección al inicio de sesión.

### V5 — Desactivación con efecto inmediato (FR‑011, aclaración Q2)

1. Con `admin`, crear un usuario recepcionista y usarlo en una segunda ventana.
2. Desactivar ese usuario con `admin`.
3. Intentar una operación desde la segunda ventana.

**Esperado**: la sesión desactivada queda cerrada y la operación se deniega.

### V6 — Duplicados y validaciones (FR‑012, FR‑013, FR‑023)

1. Crear un usuario con el `username` ya existente → `409`.
2. Registrar un cliente sin teléfono → `400` indicando el dato.
3. Registrar un vehículo con placas ya usadas → `409`.
4. Registrar un vehículo sin propietario → `400` "Seleccione el propietario".

### V7 — Política de contraseña (FR‑008)

1. Cambiar la contraseña a una de 6 caracteres → rechazo.
2. Cambiarla a una sin número → rechazo indicando qué falta.
3. Cambiarla a una válida → `200` y nuevo inicio de sesión con ella.

### V8 — Pruebas automatizadas (Principio VII)

| Ámbito | Comando | Esperado |
|--------|---------|----------|
| Backend unit | `npm test` en `server/` (Jest) | Todas pasan |
| Backend integración/contrato | `npm run test:integration` en `server/` (Jest + supertest contra `motorix_test`) | Todas pasan; nunca contra la base principal |
| Frontend | `flutter test` en `client/` | Todas pasan |

### V9 — Instalación limpia (SC‑005, FR‑020)

1. Eliminar/recrear la base local.
2. Repetir los pasos 1 a 3 de la preparación dos veces.

**Esperado**: mismos datos iniciales en ambas ejecuciones, 0 duplicados, y la interfaz
muestra información al arrancar sin capturar datos a mano.

## Criterios de éxito verificables aquí

- SC‑001: V1 en menos de 3 minutos.
- SC‑002: V2 con 100% de denegaciones.
- SC‑003: datos persistentes tras reinicio (V1).
- SC‑004 y SC‑005: seeds visibles e idempotentes (V9).
- SC‑006: revisión de que no hay secretos en el repositorio y `.env` está ignorado.
- SC‑008: mensajes en español y sin trazas internas en todos los errores de V3, V6 y V7.
