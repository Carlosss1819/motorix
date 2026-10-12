// Pruebas unitarias de las transiciones de estado de usuario (aclaración Q2).
import { resolveStatusTransition } from '../../services/user.service.js';

describe('transiciones de estado de usuario (efecto inmediato)', () => {
  test('desactivar un usuario activo cambia el estado y cierra sus sesiones', () => {
    const result = resolveStatusTransition('ACTIVE', 'INACTIVO');
    expect(result).toEqual({ status: 'INACTIVE', changed: true, closesSessions: true });
  });

  test('reactivar un usuario desactivado no cierra sesiones', () => {
    const result = resolveStatusTransition('INACTIVE', 'ACTIVO');
    expect(result).toEqual({ status: 'ACTIVE', changed: true, closesSessions: false });
  });

  test('asignar el mismo estado no produce cambios ni cierres', () => {
    const result = resolveStatusTransition('ACTIVE', 'ACTIVO');
    expect(result).toEqual({ status: 'ACTIVE', changed: false, closesSessions: false });
  });

  test('una transicion desconocida se resuelve como inactivo', () => {
    const result = resolveStatusTransition('ACTIVE', 'OTRO');
    expect(result.status).toBe('INACTIVE');
  });
});
