// Pruebas unitarias del cálculo de estado del mantenimiento (US3, Sprint 3):
// normal/próximo/vencido por fecha y por km con antelación propia (FR-011,
// FR-012, clarificación 1). Fuente de verdad:
// specs/003-historial-inventario/contracts/maintenance.md (sección formato).
import {
  calcMaintenanceState,
  addDays,
} from '../../utils/maintenance-status.js';

// Registro de ejemplo: objetivo 2026-10-30 y 45,000 km, antelación 30 días /
// 500 km (los defectos).
function registro(extra = {}) {
  return {
    targetDate: '2026-10-30',
    targetMileage: 45000,
    advanceDays: 30,
    advanceKm: 500,
    ...extra,
  };
}

describe('estado por kilometraje (FR-012)', () => {
  test('mucho antes del objetivo es NORMAL', () => {
    // 2026-09-15 está a más de 30 días del objetivo y 40,000 km a más de
    // 500 km de 45,000.
    expect(calcMaintenanceState(registro(), '2026-09-15', 40000)).toBe('NORMAL');
  });

  test('dentro de la antelación de 500 km es PROXIMO', () => {
    // 45,000 - 500 = 44,500: a partir de ahí, próximo.
    expect(calcMaintenanceState(registro(), '2026-10-13', 44500)).toBe('PROXIMO');
    expect(calcMaintenanceState(registro(), '2026-10-13', 44999)).toBe('PROXIMO');
  });

  test('alcanzar o superar el objetivo es VENCIDO', () => {
    expect(calcMaintenanceState(registro(), '2026-10-13', 45000)).toBe('VENCIDO');
    expect(calcMaintenanceState(registro(), '2026-10-13', 46200)).toBe('VENCIDO');
  });
});

describe('estado por fecha (FR-011)', () => {
  test('mucho antes de la fecha objetivo es NORMAL', () => {
    expect(calcMaintenanceState(registro(), '2026-09-01', 1000)).toBe('NORMAL');
  });

  test('dentro de la antelación de 30 días es PROXIMO', () => {
    // Objetivo 2026-10-30 menos 30 días = 2026-09-30.
    expect(calcMaintenanceState(registro(), '2026-09-30', 1000)).toBe('PROXIMO');
    expect(calcMaintenanceState(registro(), '2026-10-29', 1000)).toBe('PROXIMO');
  });

  test('el día objetivo y los posteriores son VENCIDO', () => {
    expect(calcMaintenanceState(registro(), '2026-10-30', 1000)).toBe('VENCIDO');
    expect(calcMaintenanceState(registro(), '2026-11-15', 1000)).toBe('VENCIDO');
  });
});

describe('«vence primero lo que se cumple» (FR-012)', () => {
  test('el km vencido gana aunque la fecha aún sea NORMAL', () => {
    expect(calcMaintenanceState(registro(), '2026-09-01', 45000)).toBe('VENCIDO');
  });

  test('la fecha vencida gana aunque el km aún sea NORMAL', () => {
    expect(calcMaintenanceState(registro(), '2026-11-01', 40000)).toBe('VENCIDO');
  });

  test('basta una señal de PROXIMO para marcar PROXIMO', () => {
    expect(calcMaintenanceState(registro(), '2026-10-25', 40000)).toBe('PROXIMO');
    expect(calcMaintenanceState(registro(), '2026-09-01', 44800)).toBe('PROXIMO');
  });
});

describe('antelación propia por registro (clarificación 1)', () => {
  test('una antelación mayor amplía la ventana de PROXIMO', () => {
    const amplia = registro({ advanceDays: 60, advanceKm: 2000 });
    expect(calcMaintenanceState(amplia, '2026-09-05', 40000)).toBe('PROXIMO');
    expect(calcMaintenanceState(amplia, '2026-01-01', 43000)).toBe('PROXIMO');
  });

  test('una antelación menor estrecha la ventana de PROXIMO', () => {
    const corta = registro({ advanceDays: 5, advanceKm: 100 });
    expect(calcMaintenanceState(corta, '2026-10-20', 40000)).toBe('NORMAL');
    // 44,899 km queda justo fuera de la ventana de 100 km.
    expect(calcMaintenanceState(corta, '2026-09-01', 44899)).toBe('NORMAL');
    expect(calcMaintenanceState(corta, '2026-10-26', 40000)).toBe('PROXIMO');
  });
});

describe('mantenimiento solo-por-km o solo-por-fecha (RN-11)', () => {
  test('solo-por-km ignora la fecha por completo', () => {
    const soloKm = registro({ targetDate: null });
    expect(calcMaintenanceState(soloKm, '2030-01-01', 40000)).toBe('NORMAL');
    expect(calcMaintenanceState(soloKm, '2026-11-15', 44600)).toBe('PROXIMO');
    expect(calcMaintenanceState(soloKm, '2026-01-01', 45000)).toBe('VENCIDO');
  });

  test('solo-por-fecha ignora el km por completo', () => {
    const soloFecha = registro({ targetMileage: null });
    expect(calcMaintenanceState(soloFecha, '2026-09-15', 999999)).toBe('NORMAL');
    expect(calcMaintenanceState(soloFecha, '2026-10-29', 1)).toBe('PROXIMO');
    expect(calcMaintenanceState(soloFecha, '2026-10-30', 1)).toBe('VENCIDO');
  });
});

describe('sin objetivos configurados', () => {
  test('un registro sin fecha ni km objetivo se reporta NORMAL (RN-12)', () => {
    const sinObjetivo = registro({ targetDate: null, targetMileage: null });
    expect(calcMaintenanceState(sinObjetivo, '2026-11-15', 999999)).toBe('NORMAL');
  });
});

describe('addDays', () => {
  test('suma días a una fecha ISO cruzando meses y años', () => {
    expect(addDays('2026-10-30', 30)).toBe('2026-11-29');
    expect(addDays('2026-12-15', 20)).toBe('2027-01-04');
    expect(addDays('2026-02-26', 3)).toBe('2026-03-01');
    expect(addDays('2026-10-13', 0)).toBe('2026-10-13');
  });
});
