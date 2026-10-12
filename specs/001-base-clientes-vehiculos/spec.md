# Especificación de la Funcionalidad: Base del Sistema, Clientes y Vehículos

**Rama de la funcionalidad**: `001-base-clientes-vehiculos`

**Creada**: 2026-10-11

**Estado**: Borrador

**Entrada**: Descripción de la usuario: "Usa la descripcion de @docs/sprints/sprint-1-base-clientes-vehiculos.md"
(Insumo: `docs/sprints/sprint-1-base-clientes-vehiculos.md`; contexto maestro:
`docs/project-context.md`; constitución: `.specify/memory/constitution.md`)

## Clarifications

### Session 2026-10-11

- Q: ¿Cuánto tiempo puede permanecer abierta una sesión sin actividad antes de que el
  sistema cierre el acceso y pida iniciar sesión de nuevo? → A: 30 minutos de
  inactividad y luego expira.
- Q: Cuando el administrador desactiva un usuario o le cambia el rol, ¿qué ocurre con la
  sesión que ese usuario tenga abierta en ese momento? → A: efecto inmediato: la sesión
  del usuario desactivado se cierra y el nuevo rol se aplica en su siguiente operación.
- Q: ¿Qué campos son obligatorios al registrar un cliente? → A: nombre y teléfono; el
  correo electrónico es opcional.
- Q: ¿Pueden existir dos vehículos registrados con las mismas placas o el mismo VIN? →
  A: no; placas únicas y VIN único cuando exista, el duplicado se rechaza con mensaje.
- Q: ¿Qué pantallas puede usar el rol mecánico en el Sprint 1: solo su inicio y su
  cuenta, o también clientes y vehículos en modo consulta? → A: solo Inicio (bienvenida)
  y Mi cuenta; no accede a clientes ni vehículos.

## Escenarios de usuario y pruebas *(obligatorio)*

### Historia de usuario 1 - Inicio de sesión con usuario o correo (US1) (Prioridad: P1)

Como usuario del taller (administrador, recepcionista o mecánico), quiero iniciar sesión
con mi usuario o mi correo electrónico y mi contraseña para acceder a las funciones que
corresponden a mi rol.

**Por qué esta prioridad**: Sin acceso no se puede usar ningún módulo del sistema; es la
puerta de entrada de todas las demás historias.

**Prueba independiente**: Puede probarse por completo iniciando sesión con la cuenta
`admin` usando el nombre de usuario, y luego con el mismo correo, verificando que en
ambos casos se entra al sistema y se muestran las funciones del rol administrador.

**Escenarios de aceptación**:

1. **Dado** una cuenta activa existente, **Cuando** el usuario escribe su nombre de
   usuario y contraseña correctos, **Entonces** se abre la sesión y se muestran las
   funciones de su rol.
2. **Dado** una cuenta activa existente con correo registrado, **Cuando** el usuario
   escribe ese correo en el mismo campo del usuario y la contraseña correcta, **Entonces**
   se abre la sesión con las mismas funciones.
3. **Dado** un intento de acceso con datos inexistentes o una contraseña incorrecta,
   **Cuando** el usuario confirma el inicio de sesión, **Entonces** la sesión no se abre
   y se muestra un mensaje de error claro en español.
4. **Dado** un usuario sin sesión, **Cuando** intenta llegar a una pantalla protegida,
   **Entonces** se le redirige al inicio de sesión.
5. **Dado** un usuario con sesión abierta, **Cuando** cierra la sesión, **Entonces**
   pierde de inmediato el acceso a las pantallas protegidas.
6. **Dado** un usuario con sesión abierta sin actividad durante 30 minutos, **Cuando**
   vuelve a usar el sistema, **Entonces** la sesión ya está cerrada y se le pide iniciar
   sesión de nuevo.
7. **Dado** un usuario con rol mecánico que inició sesión, **Cuando** navega el sidebar,
   **Entonces** solo ve las secciones Inicio y Mi cuenta.

---

### Historia de usuario 2 - Registro y consulta de clientes (US3) (Prioridad: P2)

Como recepcionista, quiero registrar clientes y consultarlos para mantener actualizada la
información de los propietarios que atiende el taller.

**Por qué esta prioridad**: El cliente es el propietario de los vehículos; sin clientes
no es posible registrar vehículos ni mostrar el flujo demostrable del sprint.

**Prueba independiente**: Puede probarse registrando un cliente nuevo con nombre,
teléfono y correo, y luego encontrándolo en la lista y en su ficha de detalle.

**Escenarios de aceptación**:

1. **Dado** un formulario de cliente vacío, **Cuando** el recepcionista completa los
   datos obligatorios y guarda, **Entonces** el cliente queda registrado con su fecha de
   registro y aparece en la lista de clientes.
2. **Dado** clientes registrados, **Cuando** el recepcionista busca o navega la lista,
   **Entonces** ve los clientes con su información básica y puede abrir el detalle.
3. **Dado** un cliente recién registrado sin vehículos, **Cuando** se abre su ficha,
   **Entonces** se muestra su información y la lista de vehículos vacía, sin error.
4. **Dado** un intento de guardar un cliente con datos incompletos o inválidos,
   **Cuando** se confirma el guardado, **Entonces** no se crea el registro y se indica
   qué dato debe corregirse.
5. **Dado** un cliente con nombre pero sin teléfono, **Cuando** se confirma el guardado,
   **Entonces** no se crea el registro y se pide el teléfono; con el correo vacío, en
   cambio, sí se crea.

---

### Historia de usuario 3 - Registro de vehículos con su propietario (US5 y US6)
(Prioridad: P3)

Como recepcionista, quiero registrar un vehículo y asociarlo a su propietario para
llevar el control de los automóviles que atiende el taller.

**Por qué esta prioridad**: Completa el flujo demostrable del sprint
(cliente → vehículo → asociación) y respeta la regla de negocio que prohíbe vehículos
sin propietario.

**Prueba independiente**: Puede probarse dando de alta un vehículo seleccionando un
cliente ya registrado como propietario y verificando que el vehículo aparece en la ficha
del cliente.

**Escenarios de aceptación**:

1. **Dado** un cliente registrado, **Cuando** el recepcionista registra un vehículo
   eligiéndolo como propietario y completa marca, modelo, año y placas, **Entonces** el
   vehículo queda guardado y aparece en la lista de vehículos de ese cliente.
2. **Dado** un formulario de vehículo sin propietario seleccionado, **Cuando** se intenta
   guardar, **Entonces** el registro se rechaza con un mensaje que pide seleccionar el
   propietario.
3. **Dado** un vehículo registrado, **Cuando** se abre su ficha, **Entonces** se muestran
   sus datos y el propietario al que pertenece.
4. **Dado** un vehículo con kilometraje registrado, **Cuando** se vuelve a consultar,
   **Entonces** se conserva el kilometraje dado de alta.
5. **Dado** un vehículo ya registrado con ciertas placas, **Cuando** se intenta registrar
   otro vehículo con esas mismas placas, **Entonces** no se crea y se informa que las
   placas ya están en uso.

---

### Historia de usuario 4 - Edición de la información de clientes (US4) (Prioridad: P4)

Como recepcionista, quiero editar los datos de un cliente para corregir o actualizar su
información sin perder la relación con sus vehículos.

**Por qué esta prioridad**: Es una corrección sobre datos ya existentes; el flujo base
de registro y consulta ya funciona sin ella, pero evita datos desactualizados.

**Prueba independiente**: Puede probarse cambiando el teléfono de un cliente que ya tiene
vehículos y verificando que el dato se actualiza y los vehículos siguen asociados.

**Escenarios de aceptación**:

1. **Dado** un cliente registrado con vehículos asociados, **Cuando** el recepcionista
   modifica su teléfono y guarda, **Entonces** el cliente muestra el nuevo teléfono y
   conserva sus vehículos.
2. **Dado** un cliente en modo edición, **Cuando** el recepcionista cancela, **Entonces**
   no se modifica ningún dato.
3. **Dado** datos inválidos en el formulario de edición, **Cuando** se guarda,
   **Entonces** no se aplica el cambio y se señala el dato a corregir.

---

### Historia de usuario 5 - Gestión de usuarios y roles (US2) (Prioridad: P5)

Como administrador, quiero crear usuarios, asignarles un rol y activarlos o
desactivarlos para controlar quién puede usar el sistema.

**Por qué esta prioridad**: Las cuentas iniciales del sprint ya permiten trabajar; la
gestión de usuarios amplía el control pero no bloquea el flujo demostrable.

**Prueba independiente**: Puede probarse creando un usuario nuevo con rol recepcionista,
usándolo para iniciar sesión y verificando que solo ve las funciones de ese rol.

**Escenarios de aceptación**:

1. **Dado** un administrador con sesión abierta, **Cuando** crea un usuario con nombre de
   usuario, correo y rol, **Entonces** el usuario queda guardado y aparece en la lista
   de usuarios.
2. **Dado** un nombre de usuario o correo que ya existe, **Cuando** se intenta crear otro
   con ese dato, **Entonces** no se crea el usuario y se informa que el dato ya está en
   uso.
3. **Dado** un usuario existente, **Cuando** el administrador le cambia el rol o lo
   desactiva, **Entonces** el cambio se aplica y el usuario afectado deja de tener las
   funciones anteriores.
4. **Dado** un usuario con rol que no es administrador, **Cuando** intenta acceder a la
   gestión de usuarios, **Entonces** la operación se le deniega, aunque la pantalla no
   esté visible para él.
5. **Dado** un usuario con sesión abierta, **Cuando** el administrador lo desactiva,
   **Entonces** su sesión se cierra de inmediato y cualquier operación posterior se
   deniega hasta que vuelva a iniciar sesión.

---

### Casos límite

- ¿Qué ocurre cuando se intenta registrar un cliente con un correo o nombre de usuario
  ya existente? → Se rechaza con un mensaje que identifica el dato duplicado.
- ¿Qué ocurre cuando el inicio de sesión usa datos que no existen o una contraseña
  incorrecta? → Se deniega el acceso con un mensaje genérico que no revela cuál de los
  dos datos es el incorrecto.
- ¿Qué ocurre cuando se intenta guardar un vehículo sin propietario? → Se bloquea el
  guardado (RN-1).
- ¿Qué ocurre al consultar un cliente que todavía no tiene vehículos? → Se muestra su
  ficha con la lista de vehículos vacía, sin error.
- ¿Qué ocurre cuando un rol sin permiso (por ejemplo, mecánico) intenta crear usuarios o
  modificar registros? → La operación se deniega por completo, no solo se oculta en la
  interfaz (RN-5 y RN-15).
- ¿Qué ocurre cuando la sesión expira por 30 minutos de inactividad o se cierra y el
  usuario vuelve a una pantalla protegida? → Se redirige al inicio de sesión.
- ¿Qué ocurre si se vuelve a ejecutar la preparación inicial de datos? → Los datos de
  ejemplo no se duplican.
- ¿Qué ocurre si un campo de búsqueda o de texto contiene caracteres especiales o
  intentos de consulta malintencionada? → Se tratan como texto normal y no afectan los
  datos.
- ¿Qué ocurre cuando se intenta cambiar una contraseña que no cumple la política mínima?
  → No se guarda y se indica qué requisito falta.
- ¿Qué ocurre si dos personas editan el mismo cliente en momentos distintos? → Se
  conserva la última información confirmada y nunca se pierden los vehículos asociados.
- ¿Qué ocurre si un usuario desactivado o con rol cambiado tiene la sesión abierta? →
  La desactivación cierra su sesión de inmediato y el nuevo rol rige en su siguiente
  operación.
- ¿Qué ocurre al registrar un vehículo con placas (o VIN) que ya tiene otro vehículo? →
  Se rechaza el registro y se indica que ese dato ya está en uso.
- ¿Qué ocurre si el rol mecánico intenta abrir una pantalla de clientes, vehículos o
  usuarios por cualquier vía? → Se le deniega el acceso, igual que en el resto de
  operaciones sin permiso.

## Requisitos *(obligatorio)*

### Requisitos Funcionales

- **FR-001**: El sistema DEBE permitir iniciar sesión indicando el nombre de usuario o
  el correo electrónico en un mismo campo, junto con la contraseña.
- **FR-002**: El sistema DEBE identificar al usuario por correo cuando el valor escrito
  contiene "@" y por nombre de usuario en cualquier otro caso, para todos los roles.
- **FR-003**: El sistema DEBE denegar el acceso con credenciales inválidas usando un
  mensaje que no revele cuál de los dos datos es el incorrecto.
- **FR-004**: El sistema DEBE permitir cerrar la sesión y DEBE cerrarla automáticamente
  tras 30 minutos de inactividad; en ambos casos el acceso a las pantallas protegidas
  queda bloqueado de inmediato.
- **FR-005**: El sistema DEBE ofrecer los roles administrador, recepcionista y mecánico,
  cada uno con su conjunto de funciones permitidas.
- **FR-006**: El sistema DEBE verificar el rol autorizado en cada operación protegida
  antes de ejecutarla, sin depender de lo que la interfaz muestre u oculte (RN-15).
- **FR-007**: El sistema DEBE proteger las contraseñas para que nunca se almacenen ni se
  muestren en texto plano.
- **FR-008**: El sistema DEBE permitir cambiar la contraseña de la cuenta propia
  validando la política mínima: 8 caracteres como mínimo y al menos una mayúscula, una
  minúscula y un número (RN-17).
- **FR-009**: El sistema DEBE entregar las cuentas iniciales `admin`, `recepcion` y
  `mecanico` listas para usar tras la instalación inicial (CA-10).
- **FR-010**: El administrador DEBE poder crear usuarios con nombre de usuario y correo
  únicos, asignarles un rol y verlos en una lista de usuarios.
- **FR-011**: El administrador DEBE poder cambiar el rol de un usuario y activarlo o
  desactivarlo; este sprint no elimina usuarios de forma definitiva. El cambio DEBE
  aplicarse de inmediato: al desactivar un usuario se cierra su sesión abierta y el
  nuevo rol rige en la siguiente operación que realice.
- **FR-012**: El sistema DEBE impedir que dos cuentas compartan el mismo nombre de
  usuario o el mismo correo, informando el motivo del rechazo.
- **FR-013**: El sistema DEBE permitir registrar clientes con nombre, teléfono, correo
  electrónico, fecha de registro y estado. Nombre y teléfono son obligatorios; el correo
  electrónico es opcional.
- **FR-014**: El sistema DEBE permitir consultar la lista de clientes y la ficha de un
  cliente con sus vehículos asociados (CA-4).
- **FR-015**: El sistema DEBE permitir editar la información de un cliente existente
  conservando sus vehículos asociados.
- **FR-016**: El sistema DEBE permitir registrar vehículos con propietario, marca,
  modelo, año, placas, VIN cuando esté disponible y kilometraje actual.
- **FR-017**: El sistema DEBE impedir el registro de un vehículo sin un propietario
  seleccionado (RN-1).
- **FR-018**: El sistema DEBE permitir consultar los vehículos de un cliente y la ficha
  de un vehículo con su propietario.
- **FR-019**: El sistema DEBE conservar los registros entre sesiones, reinicios de la
  aplicación y reinicios del equipo.
- **FR-020**: El sistema DEBE entregar datos de ejemplo suficientes al instalarse para
  que la interfaz muestre información al arrancar, y su preparación DEBE ser repetible
  sin duplicar registros.
- **FR-021**: El sistema DEBE organizar el acceso desde un sidebar con las secciones
  Inicio (bienvenida), Clientes, Vehículos, Usuarios y "Mi cuenta" (cambio de
  contraseña), mostrando las secciones según el rol: administrador ve todas; recepcionista
  ve Inicio, Clientes, Vehículos y Mi cuenta; mecánico ve solo Inicio y Mi cuenta.
- **FR-022**: El sistema DEBE ofrecer las pantallas del Sprint 1: inicio de sesión,
  lista y detalle de cliente, lista y detalle de vehículo, lista de usuarios y cambio de
  contraseña. El rol mecánico solo usa inicio de sesión, Inicio y Mi cuenta: las
  pantallas de gestión no están disponibles para él.
- **FR-023**: El sistema DEBE impedir que dos vehículos compartan las mismas placas, y
  que compartan el mismo VIN cuando este se registre, informando el motivo del rechazo.

### Entidades clave

- **Usuario**: persona con cuenta de acceso al sistema. Atributos clave: nombre de
  usuario único, correo electrónico único, rol (administrador, recepcionista o mecánico),
  estado (activo o inactivo) y contraseña protegida. Relación: es quien realiza todas las
  operaciones del sistema.
- **Cliente**: propietario de los vehículos atendidos por el taller; no usa el sistema
  con sesión propia. Atributos clave: nombre (obligatorio), teléfono (obligatorio), correo
  electrónico (opcional), fecha de registro y estado. Relación: puede tener uno o varios
  vehículos.
- **Vehículo**: automóvil registrado en el taller. Atributos clave: propietario
  (obligatorio), marca, modelo, año, placas (únicas), VIN cuando esté disponible (único
  cuando exista) y kilometraje actual. Relación: pertenece a un único cliente en este
  sprint.

## Criterios de éxito *(obligatorio)*

### Resultados medibles

- **SC-001**: Con las cuentas iniciales, un usuario del taller completa el flujo
  completo (iniciar sesión → registrar cliente → registrar vehículo → asociarlo →
  consultar la información) en menos de 3 minutos.
- **SC-002**: El 100% de las operaciones intentadas sin sesión o sin el rol requerido se
  deniega, incluidas las que no pasan por la interfaz.
- **SC-003**: El 100% de los registros creados (clientes, vehículos y usuarios) sigue
  disponible después de cerrar sesión, reiniciar la aplicación y reiniciar el equipo.
- **SC-004**: Después de la instalación inicial, la interfaz muestra al menos 3 clientes,
  3 vehículos y 3 usuarios de ejemplo sin capturar datos a mano.
- **SC-005**: Preparar la base de datos dos veces produce exactamente los mismos datos
  iniciales, con 0 registros duplicados.
- **SC-006**: El repositorio contiene 0 credenciales o secretos reales, verificado por
  revisión automatizada.
- **SC-007**: El 90% de los usuarios de prueba registra un cliente y un vehículo sin
  asistencia y en el primer intento.
- **SC-008**: El 100% de las operaciones denegadas o fallidas muestra un mensaje claro,
  en español y sin detalles internos del sistema.

## Fuera de alcance

- Citas.
- Órdenes de servicio.
- Inventario y refacciones.
- Pagos y Mercado Pago.
- Tickets.
- Dashboard.
- Chatbot de WhatsApp.
- Recuperación de contraseña (incluida la recuperación por correo).
- Registro público de usuarios.
- Modo oscuro.
- Borrado definitivo de usuarios o clientes.

## Supuestos

- El alcance corresponde únicamente al Sprint 1, según el insumo
  `docs/sprints/sprint-1-base-clientes-vehiculos.md`.
- Las decisiones de stack, estructura de carpetas y herramientas ya resueltas para el MVP
  (constitución e insumo del sprint) se asumen fijas y no se reabren en esta
  especificación.
- La elección de librerías de interfaz y del set de íconos es una decisión de
  implementación, no de alcance; queda fuera de esta especificación y puede tratarse en
  `/speckit.clarify`.
- El estándar de cuentas y contraseñas iniciales aplica solo a entornos locales del MVP.
- El cliente es un registro del taller y no tiene cuenta ni sesión propia en este sprint.
- El kilometraje se registra al dar de alta el vehículo; su evolución se controla en
  sprints posteriores.
- Los datos de ejemplo son ficticios y suficientes para demostrar el flujo del sprint.
- El VIN es opcional porque no todos lo vehículos lo tienen disponible.
- Los registros se eliminan de forma lógica o se desactivan; no hay borrado físico en
  este sprint.
