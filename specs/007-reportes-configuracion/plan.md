# Plan de implementación: Reportes y configuración del taller

**Rama**: `007-reportes-configuracion` | **Fecha**: 2026-11-26 | **Spec**: [spec.md](./spec.md)
**Entrada**: especificación de `specs/007-reportes-configuracion/spec.md` (aclarada el 2026-11-26)

## Resumen

El sprint se entrega en dos partes. La **Entrega A** (US1, US2, US3, US8, US9, US10) agrega la configuración del taller (datos del ticket y márgenes de "Próximo"), el catálogo de tipos de servicio con intervalos (enlazable a las líneas de servicio de la orden y usado para proponer el próximo mantenimiento), el próximo servicio en la copia del ticket, la aceptación obligatoria de términos y aviso de privacidad (validada en backend), la bitácora de acciones sensibles y las cabeceras de seguridad con `helmet`. La **Entrega B** (US4 a US7) agrega cinco reportes de solo lectura calculados de los datos existentes, con exportación CSV. Todo el esquema nuevo va en la migración `008` (solo DDL, aditiva) y los datos en el seed `007` (ids 70001 a 70099, idempotente).

## Contexto técnico

**Lenguaje/versión**: Node.js 24 LTS (ES Modules) + Express 4; Dart/Flutter (Material 3).
**Dependencias principales**: existentes (`express`, `mysql2`, `zod`, `jsonwebtoken`, `bcryptjs`; `provider`, `http`, `data_table_2`, `lucide_icons_flutter`). **Nueva**: `helmet` (backend, ver "Registro de complejidad").
**Almacenamiento**: MySQL 8 local, InnoDB, `utf8mb4`; `motorix_v2` (desarrollo) y `motorix_v2_test` (pruebas).
**Pruebas**: Jest + supertest (unitarias, contrato e integración contra `motorix_v2_test`); `flutter test`.
**Plataforma**: escritorio/web (Flutter web servido aparte, la API en `/api` por proxy).
**Tipo de proyecto**: web (cliente Flutter + API REST).
**Metas de rendimiento**: reportes de 1 año de datos de ejemplo en < 3 s (SC-008); la validación de términos agrega 1 consulta por petición.
**Restricciones**: migraciones aditivas; centavos enteros en los cálculos; sin trazas al cliente; permisos en backend; la Entrega B no se implementa en esta corrida.
**Escala**: taller pequeño (decenas de usuarios, miles de órdenes al año).

## Revisión de la constitución

| Principio | Cumplimiento | Nota |
|-----------|--------------|------|
| I. Alcance y fuente de verdad | ✅ | Sprint 7 dentro del alcance oficial (enmienda 1.1.0). Se actualiza `docs/project-context.md` (FR-041). |
| II. Arquitectura separada | ✅ | Lógica en `services/` (`settings`, `service_type`, `terms`, `audit`, `report`); controladores delgados. |
| III. Stack y base local | ✅ | Migración 008 + seed 007 versionados; pruebas contra `motorix_v2_test`. Una dependencia nueva justificada (`helmet`). |
| IV. Seguridad | ✅ | Bitácora sin contraseñas, hashes, tokens ni tarjetas; aceptación y roles validados en backend; cabeceras de seguridad. |
| V. Reglas de negocio | ✅ | RN-11/RN-12: intervalos por catálogo, propuestos y corregibles; el ticket emitido no cambia (RN-9). |
| VI. API consistente | ✅ | Mismo formato `{error: {mensaje, codigo}}`; nuevos códigos documentados en `contracts/`. |
| VII. Pruebas | ✅ | Pruebas primero por historia; suite completa al inicio (79/649 y 186) y al final. |
| VIII. UX/UI | ✅ | Pantallas nuevas con los tokens de `docs/design-system.md`; sin librerías de UI nuevas. CSV sin librería. |

**Resultado**: sin violaciones. Revisado de nuevo tras el diseño (Fase 1): sin cambios.

## Estructura del proyecto

### Documentación (esta funcionalidad)

```text
specs/007-reportes-configuracion/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── settings.md
│   ├── service-types.md
│   ├── terms.md
│   ├── audit-log.md
│   ├── tickets-y-ordenes.md
│   └── reports.md          (Entrega B)
├── checklists/
└── tasks.md
```

### Código fuente

```text
database/
├── migrations/008_configuracion_terminos_bitacora.sql   (nuevo, solo DDL)
└── seeds/007_ejemplos_configuracion_terminos.sql        (nuevo, ids 70001-70099)

server/
├── app.js                       (helmet)
├── middlewares/auth.js          (aceptación de términos, 403 TERMINOS_PENDIENTES)
├── models/      settings.js, service_type.js, terms.js, audit_log.js, report.js (B)
├── services/    settings.service.js, service_type.service.js, terms.service.js,
│                audit.service.js, report.service.js (B); cambios en auth, user,
│                part, payment, maintenance, service_order y ticket
├── utils/       settings-defaults.js, next-service.js, csv.js (B), report-range.js (B)
├── validators/  settings, service-type, terms, audit, report (B)
├── controllers/ + routes/  settings, service_types, terms, audit_log, reports (B)
└── tests/       unit/, contract/, integration/ nuevos; helpers/api.js y global-setup.js

client/lib/
├── models/      shop_settings.dart, service_type.dart, terms.dart, audit_entry.dart
├── services/    settings_service.dart, service_types_service.dart, terms_service.dart, audit_service.dart
├── providers/   auth_provider.dart (términos pendientes)
├── screens/     settings_screen.dart, service_types_screen.dart, terms_acceptance_screen.dart,
│                terms_screen.dart, audit_log_screen.dart; cambios en maintenance_form,
│                service_order_detail, ticket_screen
└── main.dart, utils/app_routes.dart, widgets/app_shell.dart
```

**Decisión de estructura**: se conserva la estructura existente (sin `src/`); cada recurso nuevo sigue el patrón ruta → controlador → servicio → modelo.

## Orden de entrega

1. **Fundamentos** (bloquean todo): migración 008, seed 007, helper de pruebas con aceptación, servicio de bitácora y de configuración.
2. **Entrega A**: US1 → US2 → US3 → US8 → US9 → US10 (US9 antes del cierre porque cambia el login de todas las pruebas).
3. **Entrega B** (otra corrida): US4 → US5 → US6 → US7, con seed de datos para reportes.

## Registro de complejidad

| Decisión | Por qué se necesita | Alternativa más simple descartada |
|----------|---------------------|-----------------------------------|
| Dependencia `helmet` (backend) | FR-030 pide cabeceras de seguridad estándar; `helmet` es la referencia para Express, sin dependencias transitivas, mantenida y pequeña; evita que el equipo mantenga a mano una lista de ~12 cabeceras y sus valores recomendados. Carlos la pidió expresamente para US10. | Escribir las cabeceras a mano en un middleware: posible, pero hay que conocer y actualizar cada cabecera; la constitución permite la dependencia si se justifica (H-S7-05). |
| Una consulta extra por petición para validar términos (FR-020) | La aceptación debe validarse en backend en cada operación, igual que el rol y el estado de la cuenta. | Guardar la aceptación en el token: no reflejaría una versión nueva hasta volver a iniciar sesión. |
| Columna nueva `order_services.service_type_id` | FR-010 pide enlazar líneas al tipo. Es aditiva y nullable; no toca filas existentes. | Buscar el tipo por texto de la descripción: ambiguo y frágil. |
