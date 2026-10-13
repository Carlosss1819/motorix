# Inicio Rápido (Fase 1)

**Funcionalidad**: Historial, mantenimiento e inventario (`003-historial-inventario`)
**Fecha**: 2026-10-13 | **Plan**: [plan.md](plan.md)

Guion de validación manual del sprint, pensado para ejecutarse en orden sobre una
instalación local ya funcionando (sprints 1 y 2). Todo se verifica desde el navegador
(Flutter en escritorio o web) con el backend corriendo; las credenciales de los tres
roles son las del seed.

## Requisitos previos

- Base de datos local aplicada al día (`aplicar-migraciones.ps1` crea la tabla
  `schema_migrations` y aplica `003_historial_mantenimiento_inventario.sql` + su seed
  de forma idempotente).
- Backend arrancado (`npm run dev` en `server/`) y frontend (`flutter run` en
  `client/`).
- Sesiones de prueba: `admin` / `Admin2026!`, `recepcion` / `Recepcion2026!`,
  `mecanico` / `Mecanico2026!`.

## Escenarios de validación

### V1 — Historial desde una orden terminada (HU1, FR‑001 a FR‑004)

1. Entrar como `mecanico`, abrir una orden suya en `TERMINADO` y pulsar «Ver
   historial del vehículo».
2. **Entonces**: se listan las órdenes terminadas/entregadas del vehículo en orden
   cronológico inverso, cada una con fecha, kilometraje, orden, diagnóstico,
   servicios, refacciones, observaciones y recomendaciones; la orden en curso (si
   hay) no aparece.
3. Cambiar `?porPagina=1` en la URL de la llamada (o usar el paginador de la
   pantalla) y comprobar que la paginación respeta 10 por defecto / máximo 50.

### V2 — Vehículo sin servicios y kilometraje (HU2, FR‑005 a FR‑007)

1. Abrir el historial de un vehículo que nunca visitó el taller.
2. **Entonces**: mensaje de "aún no hay servicios registrados", sin error.
3. Abrir una orden nueva con kilometraje menor al de la orden anterior sin
   corrección → rechazo; como `admin`, repetir con `correccionKilometraje` → acepta.

### V3 — Mantenimientos: alta, estados y renovación (HU3, FR‑008 a FR‑015)

1. Entrar como `mecanico` → «Mantenimientos» → «Nuevo mantenimiento» con tipo, fecha
   objetivo y kilometraje objetivo, sin tocar antelaciones.
2. **Entonces**: se guarda con antelación 30 días / 500 km y estado calculado;
   intentar otro con el mismo vehículo y tipo → `409` "ya existe".
3. Guardar uno solo con kilometraje → válido; sin fecha ni km → rechazo con mensaje.
4. Poner un objetivo ya alcanzado (fecha pasada o km menor al actual) → aparece
   **VENCIDO** destacado en el listado; acercarlo a la ventana de antelación →
   **PRÓXIMO**.
5. Pulsar «Servicio realizado» con el kilometraje del servicio → el mismo registro se
   renueva (último servicio actualizado, nuevo objetivo = servicio + intervalo) y
   vuelve a **NORMAL**; verificar que no se creó un segundo registro.
6. Como `recepcion`, abrir «Mantenimientos» → puede filtrar y ver los estados, pero
   los botones de edición no existen y `PUT`/`POST` con su token devuelven `403`.

### V4 — Catálogo y stock bajo (HU5, HU6, HU8, FR‑016 a FR‑021)

1. Entrar como `admin` → «Inventario» → registrar una refacción con código nuevo.
2. **Entonces**: aparece de inmediato en el listado; intentar otra con el mismo
   código → `409` con mensaje claro.
3. Dejar una refacción con `stock_actual <= stock_minimo` → se marca con el semáforo
   de stock bajo en menos de 10 segundos de abrir la pantalla; una con
   `stock_minimo = 0` no se marca nunca.
4. Buscar por nombre y por código → solo coincidencias.
5. Desactivar una refacción usada en órdenes → desaparece de las opciones para órdenes
   nuevas pero su historial de uso sigue visible.

### V5 — Uso en órdenes y concurrencia de stock (HU7, FR‑023 a FR‑027, RN‑6 a RN‑8)

1. Entrar como `mecanico` con una orden abierta suya → agregar una refacción del
   catálogo con cantidad 2.
2. **Entonces**: el stock baja en 2, queda un movimiento `SALIDA` ligado a la orden y
   la fila de la orden muestra el nombre del catálogo.
3. Intentar una cantidad mayor que el stock (o una refacción con stock 0) → `409`
   "stock insuficiente" y el stock **no** cambia (nunca negativo).
4. Agregar una refacción desactivada o un id inexistente → `409`/`404` con mensaje.
5. Retirar la refacción de la orden → el stock se repone y aparece el movimiento
   `ENTRADA` de reposición con la orden como referencia.
6. Intentar agregar o retirar refacciones en una orden `TERMINADO` → `409` orden
   cerrada.

### V6 — Movimientos y ajustes solo de administrador (FR‑028 a FR‑030, RN‑15)

1. Como `admin`, en el detalle de una refacción → registrar una `ENTRADA` de
   reabastecimiento y luego un `AJUSTE` **sin motivo** → rechazo; con motivo →
   movimiento creado con su `stockAfter`.
2. Consultar el historial de movimientos de la refacción → cada cambio explicado por
   tipo, cantidad, motivo/fecha y stock resultante.
3. Repetir el `POST` de movimiento con los tokens de `recepcion` y `mecanico` →
   `403` en ambos (SC‑009).

### V7 — Datos de ejemplo y arranque limpio (HU8, FR‑031)

1. Aplicar migraciones + seeds dos veces seguidas.
2. **Entonces**: la segunda corrida no duplica nada (`[omitida] … ya aplicada`); el
   inventario muestra refacciones variadas (algunas en stock bajo, una desactivada) y
   el listado de mantenimientos muestra ejemplos en normal, próximo y vencido; el
   historial muestra las órdenes seed del Sprint 2.

## Comprobaciones automáticas

- `npm test` en `server/` (Jest: unitarias de `maintenance-status.js`, integración de
  partes/inventario/mantenimiento/historial y contrato de las rutas nuevas) en verde.
- `flutter test` en `client/` (providers y widgets nuevos) en verde.
- ESLint del backend en 0 errores y `flutter analyze` en 0 problemas.
