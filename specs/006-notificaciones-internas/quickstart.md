# Guía de validación: Notificaciones internas (Sprint 6)

## 1. Preparación

```powershell
# Migración 007 y seed 006 en desarrollo (te pide la contraseña de motorix_app)
./database/scripts/aplicar-migraciones.ps1 -DbPassword '<contraseña de motorix_app>'
./database/scripts/aplicar-migraciones.ps1 -DbPassword '<contraseña de motorix_app>' -Seeds
```

El seed usa fechas relativas a hoy: si la demostración es otro día, vuelve a correr el segundo comando ese día (es idempotente).

Comprobar que no se duplica:

```sql
SELECT COUNT(*) FROM clients WHERE id BETWEEN 60001 AND 60099;  -- igual antes y después de recargar
SELECT COUNT(*) FROM parts WHERE code LIKE 'NOT-%';               -- 2
```

## 2. Pruebas automatizadas

```powershell
cd server; npm test; npm run lint
cd ../client; flutter test
```

Esperado: la línea base (64 suites y 545 pruebas; 155 en Flutter) más las nuevas, todas aprobadas, sin timeouts. Guardar las salidas en `docs/evidencias/sprint 6/`.

## 3. Recorrido demostrable (spec, pasos 1 a 9)

| Paso | Quién | Acción | Resultado esperado |
|---|---|---|---|
| 1 | — | Seed cargado hoy | Existen mantenimiento vencido, cita de hoy (23:30), refacción en stock bajo y orden detenida. |
| 2 | admin | Iniciar sesión | La campana muestra el total de no leídos. |
| 3 | admin | Abrir la campana | Grupos: mantenimiento vencido, orden detenida, stock agotado, stock bajo, cita de hoy, mantenimiento próximo. |
| 4 | admin | Tocar el aviso de stock | Abre el detalle de la refacción. |
| 5 | admin | Marcar un aviso como leído | El contador baja en 1; el aviso queda atenuado. |
| 6 | recepcion | Iniciar sesión y abrir la campana | Solo mantenimientos, cita de hoy y órdenes detenidas; sin stock. |
| 7 | mecanico | Iniciar sesión y abrir la campana | Solo la orden detenida asignada a él; sin importes. |
| 8 | recepcion | Abrir «Clientes por avisar» y marcar al cliente de la orden terminada | Diálogo de confirmación; el renglón sale de la lista. |
| 9 | recepcion | Recargar la lista | El cliente ya no aparece por esa orden; en la base queda quién y cuándo (`client_notices`). |

Comprobaciones adicionales (por API o pruebas):

- Mecánico: `GET /api/client-notices` → 403.
- Coherencia: el número de stock bajo coincide con el panel (`/api/dashboard`) y con `GET /api/parts?stockBajo=true`.
- Lectura por usuario: lo que marca admin sigue sin leer para recepción.
- Empeora: un mantenimiento leído como Próximo que pasa a Vencido vuelve como no leído.

Meta: el recorrido completo en menos de 10 minutos (SC-008).
