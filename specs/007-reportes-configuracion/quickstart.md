# Guía de validación: Reportes y configuración del taller

## Requisitos previos

- MySQL 8 local con `motorix_v2_test` (las pruebas la preparan solas: aplican la migración 008 y el seed 007).
- Para la demostración en `motorix_v2`: **Carlos** hace el respaldo y aplica la migración 008 y el seed 007 (ver el reporte final del sprint).

## Pruebas automáticas

```powershell
cd server
npm test        # esperado: todas las suites en verde (línea base 79/649 + las nuevas)
npm run lint    # esperado: sin errores
cd ..\client
flutter test    # esperado: todas en verde (línea base 186 + las nuevas)
flutter analyze # esperado: No issues found!
```

## Escenarios manuales (Entrega A)

1. **US9 — Términos**: inicia sesión como `recepcion`. Aparece la pantalla de términos y aviso (con la nota "plantilla académica"). "Rechazar" regresa al inicio de sesión; "Aceptar" entra. Al volver a iniciar sesión ya no se pide. Ver [contracts/terms.md](./contracts/terms.md).
2. **US1 — Datos del taller**: como `admin`, Configuración → cambia nombre y teléfono → Guardar. Cobra una orden terminada y abre su ticket: muestra los datos nuevos; un ticket anterior conserva los suyos.
3. **US2 — Márgenes**: en Configuración pon 15 días; programa un mantenimiento sin tocar la antelación: queda con 15 días.
4. **US3 — Catálogo**: Tipos de servicio → crea "Cambio de aceite prueba" (180 días, 5,000 km). En Programar mantenimiento elige el tipo: se proponen intervalo, fecha (hoy + 180) y kilometraje (actual + 5,000), editables. Desactiva el tipo: ya no aparece en las listas.
5. **US8 — Próximo servicio**: en una orden agrega un servicio eligiendo "Cambio de aceite", termina, cobra y abre el ticket: sección "Próximo servicio" con fecha y kilometraje. Una orden sin tipo no la muestra.
6. **US10 — Bitácora**: provoca un login fallido, cambia un rol, cambia el precio de una refacción y anula un pago. Bitácora (solo ADMIN): aparecen las 4 acciones con usuario y fecha; filtra por acción y por usuario.
7. **US10 — Inactividad**: deja la app 30 minutos sin uso y haz clic en cualquier sección: regresa al inicio de sesión con el aviso de sesión expirada.
8. **Permisos**: como `recepcion` o `mecanico`, las secciones Configuración, Tipos de servicio y Bitácora no aparecen y la API responde `403`.

## Escenarios manuales (Entrega B)

Ver [contracts/reports.md](./contracts/reports.md): Reportes → mes actual → ingresos, servicios, productividad, margen y rotación; exportar cada uno y comparar con la pantalla.
