<!--
Insumo de especificación para /speckit.specify.
Sprint 7 post-MVP de Motorix: reportes y configuración del taller.
Borrador para revisión: las decisiones de la sección 9 no están resueltas.
-->

# Insumo de especificación - Sprint 7: Reportes y configuración

> Referencias obligatorias para el agente:
> - Contexto maestro: `docs/project-context.md`
> - Constitución: `docs/reglas.md` y `.specify/memory/constitution.md`
> - Este documento describe únicamente el alcance del Sprint 7.

## 1. Contexto del sprint

Verificado en el código antes de redactar este sprint:

- **Configuración:** no existe módulo ni tabla de configuración. Los datos del taller del ticket son la constante `TALLER` de `server/services/ticket.service.js` (nombre, dirección y teléfono fijos en el código) y los márgenes de "Próximo" del mantenimiento son `DEFAULT_ADVANCE_DAYS = 30` y `DEFAULT_ADVANCE_KM = 500` en `server/utils/maintenance-status.js`; además, cada registro de `maintenance` guarda su propia antelación (`advance_days`, `advance_km`). Cambiar cualquiera de esos valores exige modificar el código y reiniciar el servidor; ninguno vive en `.env`.
- **Intervalos de mantenimiento:** la regla de negocio 12 pide intervalos configurables. Cada registro de `maintenance` ya guarda `interval_days` e `interval_km` (migración 003) y se capturan a mano; no hay catálogo de tipos de servicio que proponga esos valores, y las líneas de `order_services` son texto libre.
- **Reportes:** no existe un módulo de reportes ni exportación. El dashboard solo muestra ingresos pagados por mes y por método, y órdenes por estado.
- **Costeo:** el Sprint 5 dejó fuera el costo, el margen y la utilidad, aunque ya guarda el precio de compra y de venta de las refacciones y el precio de venta en cada línea de orden.

- **Términos y seguridad:** no hay pantalla de términos y condiciones ni de aviso de privacidad, y no hay bitácora de acciones sensibles. Sí existen bcrypt, JWT con vigencia de 8 horas, el bloqueo temporal por intentos fallidos, la validación de permisos en backend, la política de contraseñas (`server/validators/auth.validator.js` y `server/validators/user.validator.js`: 8 caracteres, mayúscula, minúscula y número) y el cierre por inactividad (`SESSION_IDLE_MS`, 30 minutos, `server/utils/sessionStore.js`). `helmet` NO está instalado.

Este sprint cubre esas cuatro deudas. Es el más amplio de los posteriores al MVP; si el tiempo no alcanza, se puede dividir en dos entregas: primero configuración, términos y seguridad, y después reportes.

## 2. Objetivo

Que el administrador configure desde la aplicación los datos del taller y los márgenes de mantenimiento, mantenga un catálogo de tipos de servicio con intervalos, y consulte y exporte reportes de ingresos, servicios, productividad e inventario; y que todo usuario acepte los términos y condiciones al ingresar y la información del sistema quede protegida con bitácora, política de contraseñas y cierre de sesión por inactividad.

## 3. Historias de usuario del sprint

- **US1** - Como administrador, quiero editar el nombre, la dirección y el teléfono del taller para que el ticket muestre datos correctos sin tocar el servidor.
- **US2** - Como administrador, quiero ajustar los márgenes de "Próximo" del mantenimiento para adaptarlos a la operación del taller.
- **US3** - Como administrador, quiero mantener un catálogo de tipos de servicio con su intervalo en días y en kilómetros para que el próximo mantenimiento se proponga sin asumir intervalos universales.
- **US4** - Como administrador, quiero consultar los ingresos por periodo para conocer cómo avanza el taller.
- **US5** - Como administrador, quiero ver los servicios más frecuentes y la productividad por mecánico para tomar decisiones de operación.
- **US6** - Como administrador, quiero ver el costo, el precio y el margen de las refacciones usadas y la rotación del inventario para controlar la rentabilidad.
- **US7** - Como administrador, quiero exportar cada reporte para compartirlo o archivarlo.
- **US8** - Como cliente, quiero que mi ticket indique cuándo toca mi próximo servicio para recordarlo sin que nadie me escriba.
- **US9** - Como usuario del taller, quiero leer y aceptar los términos y condiciones y el aviso de privacidad al ingresar al sistema para conocer las reglas de uso y cómo se protege la información de los clientes.
- **US10** - Como administrador, quiero que la información del sistema esté protegida (bitácora de acciones sensibles, política de contraseñas, cierre de sesión por inactividad y respuestas sin datos reservados) para detectar usos indebidos y proteger los datos del taller y de sus clientes.

## 4. Flujo demostrable al cierre del sprint

    Administrador cambia el nombre y teléfono del taller en Configuración
    -> genera un ticket nuevo y muestra los datos actualizados; los tickets anteriores no cambian
    -> define un tipo de servicio "Cambio de aceite" con intervalo de 180 días y 5,000 km
    -> al terminar una orden con ese servicio se propone el próximo mantenimiento y el ticket muestra "Próximo servicio" con esa fecha y kilometraje
    -> abre Reportes, elige el mes y ve ingresos, servicios frecuentes y productividad
    -> consulta el margen de refacciones y la rotación
    -> exporta el reporte y el archivo coincide con la pantalla

Flujo de términos y seguridad:

    Un usuario inicia sesión por primera vez (o tras publicarse una nueva versión de los términos)
    -> el sistema le muestra los términos y condiciones y el aviso de privacidad
    -> si no los acepta, no entra; si los acepta, queda registrada la versión, la fecha y el usuario
    -> el usuario cambia a una contraseña que cumple la política
    -> el administrador abre la bitácora y ve quién cambió un precio, un rol o la configuración, y cuándo
    -> tras el tiempo de inactividad configurado, la sesión se cierra y pide iniciar sesión de nuevo

## 5. Entidades y tablas que toca este sprint

> Basado en las secciones 6.6, 6.7, 6.8, 6.10 y 6.11 de `project-context.md`.

| Entidad / tabla | Acción en este sprint |
|-----------------|-----------------------|
| `settings` | crear tabla de configuración clave-valor (datos del taller y márgenes de mantenimiento) |
| `service_types` | crear catálogo de tipos de servicio con intervalo en días y en kilómetros; propone los valores de `maintenance.interval_days` e `interval_km`, no los duplica |
| `order_services` | consultar; enlazar opcionalmente con el tipo de servicio |
| `maintenance` | consultar y proponer el próximo mantenimiento a partir del intervalo |
| `payments`, `order_parts`, `parts`, `inventory_movements`, `service_orders` | consultar para los reportes; sin cambios de estructura |
| `tickets` | consultar; los tickets emitidos conservan los datos del taller con los que se emitieron; el ticket nuevo agrega la línea de próximo servicio |
| `terms_versions` | crear tabla con el texto vigente de los términos y del aviso de privacidad, su versión y su fecha |
| `terms_acceptances` | crear tabla con el usuario, la versión aceptada y la fecha de aceptación |
| `audit_log` | crear bitácora de acciones sensibles: usuario, acción, entidad afectada, fecha (sin guardar contraseñas ni datos de pago) |
| `users` | consultar; la política de contraseñas se aplica al crear o cambiar la contraseña |
| migración `008_...sql` y seed `007_...sql` del sprint | crear (la migración 007 ya la usa el Sprint 6) |

## 6. Reglas de negocio aplicables

- RN-5: Solo usuarios autorizados pueden modificar registros.
- RN-9: Una orden entregada debe conservarse como historial.
- RN-10: No duplicar información: los reportes se calculan de datos existentes.
- RN-11: Los próximos mantenimientos se basan en fecha, kilometraje o ambos.
- RN-12: Los intervalos de mantenimiento son configurables; no asumir valores universales.
- RN-14: Los datos sensibles no se almacenan en la aplicación.
- RN-15: Los permisos deben validarse en backend.

## 7. Criterios de aceptación

- [ ] CA-1: El administrador edita nombre, dirección y teléfono del taller desde la aplicación y los tickets nuevos los usan; los tickets ya emitidos no cambian.
- [ ] CA-2: Los márgenes de "Próximo" (días y kilómetros) se editan desde la aplicación con límites válidos, y la lista de Mantenimientos y el dashboard los respetan.
- [ ] CA-3: Si no hay valor guardado, se usan los predeterminados del código (30 días y 500 km, `server/utils/maintenance-status.js`), de modo que una instalación existente sigue funcionando.
- [ ] CA-4: El catálogo de tipos de servicio se crea, edita y desactiva sin borrar tipos ya usados en órdenes.
- [ ] CA-5: Al registrar el próximo mantenimiento de una orden con un tipo de servicio que tiene intervalo, la fecha y el kilometraje se proponen y el usuario puede corregirlos.
- [ ] CA-6: Existen reportes de ingresos por periodo, servicios más frecuentes, productividad por mecánico y rotación de inventario, con filtro por rango de fechas.
- [ ] CA-7: Los importes de los reportes se calculan en centavos enteros y coinciden con los pagos y órdenes que los originan.
- [ ] CA-8: El reporte de refacciones muestra costo, precio de venta y margen; el precio de compra solo lo ve el administrador.
- [ ] CA-9: Cada reporte se exporta a un archivo y su contenido coincide con la pantalla.
- [ ] CA-10: Configuración y reportes son exclusivos de ADMIN, validado en backend; RECEPTIONIST y MECHANIC reciben 403.
- [ ] CA-11: Los reportes con muchos datos responden en un tiempo razonable y paginan o limitan el rango.
- [ ] CA-12: Los seeds incluyen configuración inicial, tipos de servicio y datos suficientes para que los reportes muestren información; son idempotentes.
- [ ] CA-13: Existen y pasan pruebas de reglas de configuración, cálculo de reportes, permisos por rol y exportación.
- [ ] CA-14: El ticket nuevo muestra el próximo servicio (fecha o kilometraje) cuando la orden tiene un tipo de servicio con intervalo, y no lo muestra cuando no lo tiene; los tickets ya emitidos no cambian.
- [ ] CA-15: `docs/project-context.md` y `docs/design-system.md` se actualizan y se documenta que la constante `TALLER` y los márgenes del código quedan como valores de respaldo (no hay nada que retirar de `.env.example`).
- [ ] CA-16: Al iniciar sesión, un usuario que no ha aceptado la versión vigente de los términos y condiciones y del aviso de privacidad ve la pantalla de aceptación antes de usar el sistema; si la rechaza, se cierra la sesión y no accede.
- [ ] CA-17: La aceptación guarda usuario, versión y fecha; no se vuelve a pedir mientras la versión no cambie, y se pide de nuevo cuando el administrador publica una versión nueva.
- [ ] CA-18: Los términos describen el uso permitido del sistema, la confidencialidad de los datos de clientes y vehículos, la responsabilidad de las cuentas personales y el aviso de privacidad. El administrador puede consultar la versión vigente y las aceptaciones.
- [ ] CA-19: La aceptación se valida en backend: sin aceptación vigente, la API rechaza las operaciones del usuario (excepto aceptar, ver los términos y cerrar sesión), no solo la pantalla.
- [ ] CA-20: La bitácora registra, como mínimo, inicios de sesión fallidos y bloqueos, altas, bajas y cambios de rol de usuarios, cambios de configuración y de precios, y pagos cancelados; ADMIN la consulta con filtros por fecha, usuario y acción; nadie puede editarla ni borrarla desde la aplicación.
- [ ] CA-21: La bitácora no guarda contraseñas, hashes, tokens ni datos de tarjeta.
- [ ] CA-22: La política de contraseñas existente (8 caracteres, mayúscula, minúscula y número) se aplica al crear y al cambiar la contraseña, con un mensaje claro; las contraseñas siguen guardándose solo con hash. En este sprint se agregan las pruebas que lo demuestran.
- [ ] CA-23: La sesión se cierra tras 30 minutos de inactividad (ya existe en backend con `SESSION_IDLE_MS`) y Flutter regresa al inicio de sesión al recibir ese rechazo (`401`); la expiración del token se mantiene validada en backend.
- [ ] CA-24: Ninguna respuesta de la API incluye el hash de contraseña, el token ni los precios reservados al rol; existen pruebas que lo verifican en cada endpoint de usuarios, refacciones, órdenes, pagos y tickets.
- [ ] CA-25: Las consultas usan parámetros (sin concatenar texto del usuario) y las entradas se validan en backend; una prueba automática comprueba intentos de inyección en los campos de búsqueda.
- [ ] CA-26: Existen y pasan pruebas de aceptación de términos, bitácora, política de contraseñas, inactividad y no exposición de datos.

## 8. Fuera de alcance de este sprint

- Gráficas avanzadas, tableros personalizables y analítica predictiva.
- Impuestos, facturación electrónica y contabilidad.
- Gestión de usuarios y roles (ya existe desde el Sprint 1).
- Configuración de credenciales de Mercado Pago o de proveedores externos; siguen en variables de entorno.
- Notificaciones (Sprint 6) y mensajes al cliente (fuera del alcance del proyecto).
- Programación o envío automático de reportes por correo.
- Cifrado de la base de datos en disco, respaldos, HTTPS y despliegue (se descartó el antiguo Sprint 8).
- Autenticación de dos factores y recuperación de contraseña por correo.
- Asesoría legal: el texto de los términos es una plantilla que el taller debe revisar con quien corresponda.

## 9. Decisiones pendientes que deben resolverse en /speckit.clarify

- Formato de exportación: ¿CSV, Excel o PDF? ¿Con qué librería, si no es CSV?
- Prioridad si el sprint se divide: ¿configuración y catálogo primero, reportes después?
- Si los datos del taller deben guardarse además en cada ticket emitido (instantánea) para que un cambio posterior no altere los tickets.
- Si el tipo de servicio se enlaza a las líneas de `order_services` (que hoy son texto libre) y qué pasa con las líneas existentes sin tipo.
- Cómo se calcula el margen cuando una refacción no tiene precio de compra (líneas anteriores al Sprint 5 con precio 0).
- Periodos disponibles en los reportes (día, semana, mes, rango libre) y huso horario de corte.
- Definición de productividad por mecánico: ¿órdenes terminadas, importe de mano de obra o tiempo promedio?
- Definición de rotación de inventario: ¿salidas del periodo sobre existencia promedio u otra?
- Si se muestran los reportes también a RECEPTIONIST en una versión reducida.
- Términos y condiciones: ¿quién redacta el texto y en qué idioma y extensión? ¿Se edita desde la aplicación o se publica con una migración? ¿Se acepta una sola vez por versión o en cada sesión?
- Qué hacer con los usuarios ya existentes: ¿deben aceptar en su siguiente inicio de sesión?
- Bitácora: ¿qué acciones exactas se registran, cuánto tiempo se conserva y si se pagina o se exporta?
- Política de contraseñas: longitud mínima, complejidad y si se obliga a cambiar la contraseña de los usuarios sembrados.
- Tiempo de inactividad para cerrar la sesión (por ejemplo, 15 o 30 minutos) y si aplica igual a todos los roles.
- Prioridad si el sprint no alcanza: ¿términos y seguridad antes que reportes?

## 10. Restricciones técnicas heredadas

- Backend en ES Modules, nunca CommonJS.
- Solo el backend accede a MySQL; el frontend nunca se conecta directo.
- Permisos validados en backend, no solo en UI.
- Sin secretos en el repositorio.
- Idioma: español en chat, docs, comentarios y pruebas.
- MySQL local, InnoDB, llaves foráneas, `utf8mb4`.
- Login acepta usuario o correo electrónico en el mismo campo.
- Ya existen bcrypt para las contraseñas, JWT con vigencia de 8 horas, el cierre por inactividad, la política de contraseñas y el bloqueo temporal por intentos fallidos desde el Sprint 1; este sprint los complementa y no los reemplaza. `helmet` no está instalado: se agrega en US10.
- Toda pantalla del frontend sigue `docs/design-system.md`.
- Pruebas de integración contra `motorix_v2_test`, nunca contra la base principal.
- Los seeds del sprint DEBEN incluir datos de ejemplo suficientes para que la aplicación muestre información al arrancar. La base no puede quedar vacía tras la instalación.
- Los seeds DEBEN ser idempotentes: si se corren de nuevo, no duplican registros.
- Los importes se calculan en centavos enteros y se guardan como `DECIMAL(10,2)`, igual que en los Sprints 4 y 5.
- Las migraciones son aditivas y numeradas; no modifican las migraciones anteriores. El Sprint 6 usa la `007`, así que este sprint usa la migración `008` y el seed `007`.

## 11. Verificación contra el código (2026-11-26)

Revisión hecha sobre la rama `007-reportes-configuracion` (creada desde `main`, commit `d1fc2db`). Línea base antes de empezar: backend 79 suites y 649 pruebas en verde; `flutter test` 186 pruebas en verde (evidencia en `docs/evidencias/sprint 7/s7-inicial-*.txt`).

### 11.1 Correcciones aplicadas a este insumo

| # | Decía | Dice ahora (verificado) |
|---|-------|-------------------------|
| a | Migración `007_...sql` | La migración 007 ya la usa el Sprint 6 (`007_notificaciones_internas.sql`): este sprint usa la migración `008` y el seed `007`. |
| b | Base de pruebas `motorix_test` | `motorix_v2_test` (`server/tests/helpers/env.js`). |
| c | Referencia a `docs/sprints/propuesta-sprints-post-mvp.md` | El archivo no existe: se quitó la referencia. |
| d | Datos del taller en `.env` (`SHOP_NAME`, `SHOP_ADDRESS`, `SHOP_PHONE`) | Son la constante `TALLER` de `server/services/ticket.service.js`. |
| e | Márgenes de "Próximo" en `.env` y predeterminado de 1,000 km | Son `DEFAULT_ADVANCE_DAYS = 30` y `DEFAULT_ADVANCE_KM = 500` en `server/utils/maintenance-status.js`, y `maintenance` guarda `advance_days`/`advance_km` por registro. CA-3 usa 30 días y 500 km. |
| f | "El próximo mantenimiento se captura a mano; no hay intervalos" | `maintenance` ya tiene `interval_days` e `interval_km` (migración 003): `service_types` propone esos valores, no los duplica. |
| g | "No hay política de contraseñas" | Ya existe (`server/validators/auth.validator.js` y `user.validator.js`): CA-22 = lo existente + pruebas. |
| h | "La sesión solo expira por la vigencia del token" | La inactividad ya existe en backend (`SESSION_IDLE_MS`, 30 min, `server/utils/sessionStore.js`) y en Flutter (`AuthProvider.inactivityTimeout`): CA-23 = verificar que Flutter regrese al login al recibir ese rechazo. |
| i | "Ya existe `helmet`" | `helmet` NO está instalado (`server/package.json`): se agrega en US10. |

### 11.2 Otros hallazgos (no encajan con el código o con la constitución)

- **H-S7-01 — Márgenes globales vs. antelación por registro.** Cada mantenimiento guarda su propia antelación (`advance_days`/`advance_km`, `NOT NULL`, 30/500 por defecto en la migración 003), y la lista, el dashboard y los avisos del Sprint 6 usan la del registro. Por eso el margen configurable de US2 solo puede ser el **valor por defecto de los registros nuevos** (y el respaldo cuando un registro no trae valor); cambiarlo no altera los registros ya creados. CA-2 se interpreta así.
- **H-S7-02 — Ticket y copia.** Desde el Sprint 5 el ticket ya guarda una copia (`tickets.content`, `FORMATO_ACTUAL = 2`) que incluye `taller`. La decisión 3 de la sección 9 ya está resuelta por el código: basta con que la copia tome los datos de la configuración al emitirse; los tickets anteriores no cambian. La línea de próximo servicio se agrega como campo opcional de la copia v2.
- **H-S7-03 — Dos tipos de "pago cancelado".** En el código existen `ANULADO` (anulación de ADMIN, `POST /api/payments/:id/anular`) y `CANCELADO` (cobro de Mercado Pago rechazado o desfasado, `POST /api/payments/:id/confirmar`). CA-20 debe registrar ambos.
- **H-S7-04 — Publicación de términos.** CA-17 dice "cuando el administrador publica una versión nueva", pero los términos se publican con migración/seed y el administrador no los edita (decisión de clarify). Una versión nueva se publica con un seed o migración posterior.
- **H-S7-05 — `helmet` y la constitución.** La constitución pide justificar toda dependencia nueva y no agregar librerías para lo que se resuelve con pocas líneas. `helmet` es pequeño, sin dependencias y estándar para Express; la justificación queda en el plan.
- **H-S7-06 — US8 "Como cliente".** El cliente del taller no es usuario del sistema; la historia se cumple con el ticket impreso o mostrado, sin acceso del cliente.
- **H-S7-07 — Aceptación de términos y pruebas.** Al exigir la aceptación en backend (CA-19), las pruebas existentes que inician sesión fallarían; el helper de pruebas debe dejar a los usuarios de prueba con la aceptación vigente.
- **H-S7-08 — CA-15 y `.env.example`.** `.env.example` no tiene variables del taller ni de márgenes: no hay nada que retirar; se documenta el respaldo en el código.
- **H-S7-09 — Alcance.** El Sprint 7 está dentro del alcance oficial (enmienda 1.1.0, principio I), y el aviso de privacidad visible en la app es parte de ese alcance. No requiere enmienda.
- **H-S7-10 — Intermitencia en `dashboard.test.js` (pendiente de investigar).** En la primera corrida completa con los cambios del sprint falló una vez «los conteos del panel coinciden con la base y el listado» con «No se obtuvo una ventana estable para comparar los conteos» (la prueba compara conteos mientras otras suites escriben en paralelo). Las tres corridas completas siguientes pasaron (98/98 suites). No se modificó la prueba; queda registrado según la regla 7 de `CLAUDE.md`. Entrega B (2026-11-26): 0 fallos en 4 corridas completas (una inicial de 98 suites y tres finales de 105 suites y 849 pruebas; evidencia `docs/evidencias/sprint 7/s7-entrega-b-npm-test-*.txt`).
- **H-S7-11 — Antelación en el formulario de mantenimiento.** El cliente enviaba siempre 30/500 en el alta, lo que habría anulado el margen configurable (US2). Ahora el alta deja la antelación vacía y el backend aplica el margen del taller; la edición sigue mostrando la del registro.
- **H-S7-12 — Menú lateral del administrador.** Con las cuatro secciones nuevas, el menú se desbordaba en 1280×720 y 1366×768 (lo detectó `notification_bell_test.dart`). Se hizo desplazable; no se quitó ninguna prueba.
- **H-S7-13 — El costo del margen no está congelado (Entrega B).** `order_parts` congela el precio de venta (`unit_price`, Sprint 5), pero no el de compra. El reporte de margen (US6) usa el `purchase_price` vigente de la refacción, como pide la spec («costo (precio de compra)»): si el administrador cambia el precio de compra, el margen de periodos ya cerrados cambia. Congelarlo requeriría una columna nueva (migración aditiva) y queda como propuesta para un sprint posterior; no se cambió en este sprint.
- **H-S7-14 — Ids de seeds y `AUTO_INCREMENT` en `motorix_v2_test` (Entrega B).** Los seeds usan `INSERT IGNORE` con ids fijos. En `motorix_v2_test` los contadores avanzan con cada corrida (por ejemplo, `service_orders` iba en 64,311 y la prueba de rendimiento de reportes consume 1,500 ids por corrida aunque borre sus filas). Los ids 70001 a 70099 estaban libres y el seed 007 ya los ocupó, pero un seed futuro con un rango que la base de pruebas ya rebasó se saltaría filas en silencio. Además, tras insertar el id 70001, el contador sigue en 70002 y las demás suites crean filas dentro del rango (la prueba del seed cuenta solo los ids exactos del seed). Recomendación: que los seeds futuros usen rangos muy por encima del uso de la base de pruebas, o recrear `motorix_v2_test` antes de agregarlos.
