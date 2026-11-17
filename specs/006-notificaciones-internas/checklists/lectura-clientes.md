# Lista de calidad de requisitos: lectura, identidad del aviso y clientes por avisar

**Propósito**: comprobar que los requisitos de lectura por usuario, identidad de los avisos y «Clientes por avisar» estén completos y sin contradicciones (no prueba la implementación).
**Creada**: 2026-11-16
**Funcionalidad**: [spec.md](../spec.md)

> Un `[x]` significa que el revisor dio por buena la calidad del requisito, no que esté implementado. Evaluación hecha por el agente a pedido de Carlos (2026-11-16).

## Completitud

- [x] CHK001 - ¿Está definida la clave de cada tipo de aviso, con el «estado» que entra en ella? [Completitud, Spec §FR-015]
- [x] CHK002 - ¿Se define cómo distinguir un ciclo de mantenimiento del siguiente, dado que cada mantenimiento es un solo registro que se actualiza? [Gap → resuelto, Spec §FR-015, FR-021] (corregido: el objetivo vigente entra en la clave y en el hecho)
- [x] CHK003 - ¿Están definidos los datos que se guardan al marcar un cliente como avisado? [Completitud, Spec §FR-020, Entidades clave]
- [x] CHK004 - ¿Se define dónde está «Clientes por avisar», su orden y sus estados de carga, vacío y error? [Gap → resuelto, Spec §FR-029] (corregido)

## Claridad

- [x] CHK005 - ¿Está claro qué cuenta como «hecho» para cada motivo (orden, cita o mantenimiento con su objetivo)? [Claridad, Spec §FR-021]
- [x] CHK006 - ¿Está claro que los avisos leídos siguen visibles y que el contador solo cuenta los no leídos? [Claridad, Spec §FR-014]
- [x] CHK007 - ¿Está definido cuándo se actualiza el contador, sin consultas por intervalo? [Claridad, Spec §FR-017]

## Coherencia

- [x] CHK008 - ¿«Un aviso empeora y vuelve como no leído» es coherente con la clave tipo + objeto + estado? [Coherencia, Spec §FR-015, Clarifications]
- [x] CHK009 - ¿El caso límite «marcar un aviso que ya no existe» es coherente con FR-030? [Coherencia] (corregido: antes no había regla en los requisitos)
- [x] CHK010 - ¿La regla de «una sola vez por hecho» es coherente con «un hecho nuevo vuelve a aparecer»? [Coherencia, Spec §FR-020, FR-021]

## Cobertura de escenarios

- [x] CHK011 - ¿Se cubren la marcación doble y la concurrente del mismo hecho (409)? [Excepción, Spec §FR-020]
- [x] CHK012 - ¿Se cubre una cita reprogramada (nueva clave por fecha)? [Casos límite, Spec §FR-015]
- [x] CHK013 - ¿Se cubre una orden detenida que cambia de estado y vuelve a detenerse? [Casos límite]
- [x] CHK014 - ¿Está excluido de forma explícita deshacer un «avisado» y el historial de avisos? [Alcance, Spec §FR-023, Fuera de alcance]

## Medibilidad

- [x] CHK015 - ¿Se pueden medir el efecto de marcar como leído y la no repetición de un hecho avisado? [Medibilidad, Spec §SC-004, SC-005]

## Notas

- Correcciones aplicadas a la spec durante la revisión: FR-015 y FR-021 (objetivo vigente del mantenimiento), FR-029 (ubicación, orden y estados de la lista), FR-030 (claves ajenas o inexistentes).
