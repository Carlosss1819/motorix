-- Datos del Sprint 7 (Entrega A): configuración inicial, tipos de servicio y la
-- versión 1.0 de los términos y condiciones y del aviso de privacidad.
-- Script IDEMPOTENTE: puede ejecutarse varias veces sin duplicar registros.
-- Fuente de verdad: specs/007-reportes-configuracion/data-model.md (Seed 007).
--
-- Reglas del seed:
--   * Ids fijos en el rango 70001 a 70099.
--   * La configuración inicial repite los valores de respaldo del código, así
--     que cargar el seed no cambia los tickets ni las pruebas existentes.
--     INSERT IGNORE: si el administrador ya cambió un valor, se conserva.
--   * Tipos de servicio: INSERT IGNORE por id y por nombre único.
--   * Términos: la versión 1.0 se inserta una sola vez y queda vigente. Para
--     publicar una versión nueva se agrega OTRO seed que inserte la versión
--     2.0 con is_current = 1 y apague is_current de las anteriores; nunca se
--     edita el texto de una versión ya aceptada.
--   * No registra aceptaciones: los usuarios existentes aceptan en su
--     siguiente inicio de sesión (aclaración de la spec).

INSERT IGNORE INTO settings (setting_key, setting_value) VALUES
  ('shop.name', 'Motorix'),
  ('shop.address', 'Av. Ejemplo 123, Col. Centro'),
  ('shop.phone', '55-0000-0000'),
  ('maintenance.advance_days', '30'),
  ('maintenance.advance_km', '500');

INSERT IGNORE INTO service_types (id, name, interval_days, interval_km, is_active) VALUES
  (70001, 'Cambio de aceite', 180, 5000, 1),
  (70002, 'Afinación', 365, 20000, 1),
  (70003, 'Rotación de llantas', 180, 10000, 1),
  (70004, 'Revisión de frenos', 365, NULL, 1),
  (70005, 'Cambio de anticongelante', 730, 40000, 1);

INSERT IGNORE INTO terms_versions (id, version, published_at, terms_text, privacy_text, is_current) VALUES
(70001, '1.0', '2026-11-26 00:00:00',
'TÉRMINOS Y CONDICIONES DE USO DEL SISTEMA MOTORIX

Plantilla académica: este texto es un ejemplo para un proyecto escolar y no constituye asesoría legal. Un taller real debe revisarlo con quien corresponda.

1. Uso permitido. El sistema Motorix es una herramienta interna de Taller Motorix. Solo puede usarse para registrar y consultar clientes, vehículos, citas, órdenes de servicio, mantenimientos, inventario, pagos y tickets del taller, de acuerdo con el rol asignado a cada cuenta (administración, recepción o mecánico).

2. Cuentas personales. Cada cuenta es personal e intransferible. La persona usuaria es responsable de las acciones realizadas con su cuenta, debe mantener su contraseña en secreto, no compartirla y cerrar la sesión al terminar. El sistema cierra la sesión tras 30 minutos sin actividad.

3. Confidencialidad. Los datos de clientes y vehículos (nombres, teléfonos, correos, placas, historial y pagos) son confidenciales. Solo se consultan para atender el servicio del taller; no se copian, exportan ni comparten fuera de él sin autorización del administrador.

4. Registro de actividad. El sistema registra en una bitácora las acciones sensibles (inicios de sesión fallidos, cambios de usuarios y roles, cambios de configuración y de precios, y pagos anulados o cancelados) para detectar usos indebidos.

5. Incumplimiento. El uso indebido puede llevar a la desactivación de la cuenta y a las medidas que el taller determine.

6. Cambios. Taller Motorix puede actualizar estos términos; cada versión nueva se debe aceptar al iniciar sesión.',
'AVISO DE PRIVACIDAD INTEGRAL

Plantilla académica: este aviso es un ejemplo para un proyecto escolar, redactado para un responsable ficticio, y no constituye asesoría legal.

Responsable. Taller Motorix (responsable ficticio), con domicilio en Av. Ejemplo 123, Col. Centro, Ciudad de México, C.P. 00000, es responsable del tratamiento de los datos personales que recaba, conforme a la Ley Federal de Protección de Datos Personales en Posesión de los Particulares.

Datos que recabamos. De clientes: nombre, teléfono y correo electrónico; datos del vehículo (marca, modelo, año, placas, número de serie y kilometraje); historial de servicios y pagos (importe, método y fecha). No guardamos datos de tarjetas. Del personal: nombre de usuario, correo electrónico y rol.

Finalidades. Primarias: registrar y dar seguimiento a citas, órdenes de servicio y mantenimientos; cobrar y emitir tickets; avisar al cliente sobre su vehículo; controlar el acceso al sistema. Secundaria: recordar al cliente su próximo mantenimiento. Si no desea el tratamiento para la finalidad secundaria, puede indicarlo en recepción.

Derechos ARCO y revocación del consentimiento. Usted puede acceder a sus datos, rectificarlos, cancelarlos u oponerse a su tratamiento (derechos ARCO), así como revocar su consentimiento, presentando una solicitud por escrito en el domicilio del responsable o al correo privacidad@tallermotorix.example, con su nombre, un medio para responderle, una identificación y la descripción de lo que solicita. Responderemos en un plazo máximo de 20 días hábiles.

Transferencias. No transferimos sus datos a terceros, salvo las excepciones del artículo 37 de la Ley (por ejemplo, requerimientos de una autoridad competente). El procesador de pagos solo recibe los datos necesarios para el cobro.

Cambios al aviso. Cualquier cambio a este aviso se publicará en el sistema como una versión nueva y se informará en recepción.

Fecha de la última actualización: 26 de noviembre de 2026 (versión 1.0).',
1);

-- ===========================================================================
-- Entrega B (T061, FR-040, CA-12): datos para que los reportes del mes en
-- curso muestren cifras. Ids 70001 a 70099, INSERT IGNORE (idempotente).
-- Las fechas son relativas al día en que se aplica el seed y nunca salen del
-- mes en curso (D0 = hace 2 días, D1 = ayer, D2 = hoy; si el mes acaba de
-- empezar, se recortan al día 1). Usuarios del seed 001: admin=1,
-- recepcion=2, mecanico=3; tipos de servicio 70001 (Cambio de aceite) y
-- 70002 (Afinación) de arriba.
--
-- Cifras esperadas en el reporte del mes (si no hay más movimientos):
--   ingresos:      3630.00 en 3 pagos (EFECTIVO 690.00, TARJETA 2690.00,
--                  TRANSFERENCIA 250.00); el pago ANULADO de 690.00 no suma.
--   servicios:     Limpieza de cuerpo de aceleración (sin tipo) 2 veces 500.00,
--                  Afinación 1 vez 900.00, Cambio de aceite 1 vez 350.00.
--   productividad: mecanico 2 órdenes 1500.00; sin mecánico 1 orden 250.00.
--   refacciones:   bujías 5 piezas, costo 1050.00, venta 1700.00, margen
--                  650.00; limpiador 1 pieza, venta 180.00, "sin costo
--                  registrado" (fuera del total).
--   rotación:      bujías 5 salidas / 16 en existencia = 0.31; limpiador
--                  1 salida, "sin existencia".
-- ===========================================================================

SET @s7_d0 = GREATEST(DATE_FORMAT(CURDATE(), '%Y-%m-01'), CURDATE() - INTERVAL 2 DAY);
SET @s7_d1 = GREATEST(DATE_FORMAT(CURDATE(), '%Y-%m-01'), CURDATE() - INTERVAL 1 DAY);
SET @s7_d2 = CURDATE();

INSERT IGNORE INTO clients (id, name, phone, email, status) VALUES
  (70001, 'Laura Méndez (ejemplo de reportes)', '5557000001', NULL, 'ACTIVO');

INSERT IGNORE INTO vehicles (id, client_id, brand, model, year, plates, vin, current_mileage) VALUES
  (70001, 70001, 'Chevrolet', 'Aveo', 2019, 'RPT7001', NULL, 60500);

-- Refacciones: las bujías tienen precio de compra; el limpiador no (margen
-- "sin costo registrado") y se queda sin existencia (rotación "sin
-- existencia"). stock_min 0 en el limpiador para no sumar al stock bajo.
INSERT IGNORE INTO parts (id, code, name, category, brand, stock_current, stock_min, purchase_price, sale_price, is_active) VALUES
  (70001, 'S7-BUJ01', 'Juego de bujías de iridio', 'Motor', 'NGK',   16, 4, 210.00, 340.00, 1),
  (70002, 'S7-LIM01', 'Limpiador de inyectores',   'Motor', 'Wynns',  0, 0,   NULL, 180.00, 1);

-- Órdenes entregadas (ENTREGADO sale de las listas activas del panel y de avisos).
INSERT IGNORE INTO service_orders
  (id, client_id, vehicle_id, appointment_id, status, visit_reason, entry_date, entry_mileage, mechanic_id, diagnosis, diagnosis_draft, recommendations, delivery_date, created_by)
VALUES
  (70001, 70001, 70001, NULL, 'ENTREGADO', 'Cambio de aceite (ejemplo de reportes)',        @s7_d0, 60000, 3,    'Aceite en el límite de su vida útil.', 0, NULL, @s7_d0 + INTERVAL 10 HOUR, 2),
  (70002, 70001, 70001, NULL, 'ENTREGADO', 'Afinación (ejemplo de reportes)',               @s7_d1, 60300, 3,    'Bujías desgastadas y marcha irregular.', 0, 'Revisar inyectores en el siguiente servicio.', @s7_d1 + INTERVAL 10 HOUR, 2),
  (70003, 70001, 70001, NULL, 'ENTREGADO', 'Limpieza de aceleración (ejemplo de reportes)', @s7_d2, 60500, NULL, NULL, 0, NULL, @s7_d2 + INTERVAL 10 HOUR, 2);

-- Historial: el paso a TERMINADO define el periodo de servicios, productividad y margen.
INSERT IGNORE INTO order_status_history (id, service_order_id, from_status, to_status, changed_by, changed_at, note) VALUES
  (70001, 70001, NULL,          'RECIBIDO',    2, @s7_d0 + INTERVAL 480 MINUTE, 'Alta de la orden'),
  (70002, 70001, 'RECIBIDO',    'DIAGNOSTICO', 3, @s7_d0 + INTERVAL 510 MINUTE, NULL),
  (70003, 70001, 'DIAGNOSTICO', 'TERMINADO',   3, @s7_d0 + INTERVAL 570 MINUTE, 'Trabajo finalizado'),
  (70004, 70001, 'TERMINADO',   'ENTREGADO',   2, @s7_d0 + INTERVAL 600 MINUTE, NULL),
  (70005, 70002, NULL,          'RECIBIDO',    2, @s7_d1 + INTERVAL 480 MINUTE, 'Alta de la orden'),
  (70006, 70002, 'RECIBIDO',    'DIAGNOSTICO', 3, @s7_d1 + INTERVAL 510 MINUTE, NULL),
  (70007, 70002, 'DIAGNOSTICO', 'TERMINADO',   3, @s7_d1 + INTERVAL 570 MINUTE, 'Trabajo finalizado'),
  (70008, 70002, 'TERMINADO',   'ENTREGADO',   2, @s7_d1 + INTERVAL 600 MINUTE, NULL),
  (70009, 70003, NULL,          'RECIBIDO',    2, @s7_d2 + INTERVAL 480 MINUTE, 'Alta de la orden'),
  (70010, 70003, 'RECIBIDO',    'DIAGNOSTICO', 1, @s7_d2 + INTERVAL 510 MINUTE, NULL),
  (70011, 70003, 'DIAGNOSTICO', 'TERMINADO',   1, @s7_d2 + INTERVAL 570 MINUTE, 'Trabajo finalizado'),
  (70012, 70003, 'TERMINADO',   'ENTREGADO',   2, @s7_d2 + INTERVAL 600 MINUTE, NULL);

-- Servicios: dos tipificados y la misma línea libre en dos órdenes.
INSERT IGNORE INTO order_services (id, service_order_id, description, service_type_id) VALUES
  (70001, 70001, 'Cambio de aceite sintético',        70001),
  (70002, 70002, 'Afinación mayor',                   70002),
  (70003, 70002, 'Limpieza de cuerpo de aceleración', NULL),
  (70004, 70003, 'Limpieza de cuerpo de aceleración', NULL);

INSERT IGNORE INTO order_labor (id, service_order_id, service_id, description, duration_minutes, price) VALUES
  (70001, 70001, 70001, 'Mano de obra cambio de aceite', 30, 350.00),
  (70002, 70002, 70002, 'Mano de obra afinación',        90, 900.00),
  (70003, 70002, 70003, 'Mano de obra limpieza',         30, 250.00),
  (70004, 70003, 70004, 'Mano de obra limpieza',         30, 250.00);

-- Refacciones con el precio congelado de la línea.
INSERT IGNORE INTO order_parts (id, service_order_id, part_id, description, quantity, unit_price) VALUES
  (70001, 70001, 70001, 'Juego de bujías de iridio', 1, 340.00),
  (70002, 70002, 70001, 'Juego de bujías de iridio', 4, 340.00),
  (70003, 70002, 70002, 'Limpiador de inyectores',   1, 180.00);

-- Pagos: tres aprobados (uno por método) y uno anulado que no suma.
--   orden 70001: 350.00 + 340.00                     =  690.00
--   orden 70002: 900.00 + 250.00 + 1360.00 + 180.00  = 2690.00
--   orden 70003: 250.00                              =  250.00
INSERT IGNORE INTO payments
  (id, service_order_id, amount, method, status, annulment_reason, annulled_by, created_by, created_at, annulled_at)
VALUES
  (70001, 70001,  690.00, 'TARJETA',       'ANULADO', 'Cobro capturado con la terminal equivocada (ejemplo).', 1, 2, @s7_d0 + INTERVAL 575 MINUTE, @s7_d0 + INTERVAL 580 MINUTE),
  (70002, 70001,  690.00, 'EFECTIVO',      'PAGADO',  NULL, NULL, 2, @s7_d0 + INTERVAL 585 MINUTE, NULL),
  (70003, 70002, 2690.00, 'TARJETA',       'PAGADO',  NULL, NULL, 2, @s7_d1 + INTERVAL 585 MINUTE, NULL),
  (70004, 70003,  250.00, 'TRANSFERENCIA', 'PAGADO',  NULL, NULL, 2, @s7_d2 + INTERVAL 585 MINUTE, NULL);

-- Movimientos coherentes con la existencia final (bujías 16, limpiador 0).
INSERT IGNORE INTO inventory_movements (id, part_id, movement_type, quantity, reason, service_order_id, stock_after, created_by, created_at) VALUES
  (70001, 70001, 'ENTRADA', 21, 'Compra inicial (ejemplo de reportes)', NULL,  21, 1, @s7_d0 + INTERVAL 420 MINUTE),
  (70002, 70002, 'ENTRADA',  1, 'Compra inicial (ejemplo de reportes)', NULL,   1, 1, @s7_d0 + INTERVAL 420 MINUTE),
  (70003, 70001, 'SALIDA',   1, 'Uso en orden de servicio',             70001, 20, 3, @s7_d0 + INTERVAL 540 MINUTE),
  (70004, 70001, 'SALIDA',   4, 'Uso en orden de servicio',             70002, 16, 3, @s7_d1 + INTERVAL 540 MINUTE),
  (70005, 70002, 'SALIDA',   1, 'Uso en orden de servicio',             70002,  0, 3, @s7_d1 + INTERVAL 540 MINUTE);
