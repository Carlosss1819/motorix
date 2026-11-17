// Prueba unitaria de la agrupación de avisos (Sprint 6, FR-007a): grupos en
// orden fijo por urgencia, sin grupos vacíos, no leídos primero y luego por
// fecha de referencia (la más antigua primero).
import { groupNotices } from '../../services/notification.service.js';

const aviso = (tipo, clave, fechaReferencia, leido = false) => ({
  clave,
  tipo,
  titulo: tipo,
  descripcion: '',
  fechaReferencia,
  leido,
  destino: { pantalla: 'ORDEN', id: 1 },
});

test('ordena_los_grupos_por_urgencia_y_omite_los_vacios', () => {
  const r = groupNotices([
    aviso('MANT_PROXIMO', 'a', '2026-11-20'),
    aviso('CITA_HOY', 'b', '2026-11-16'),
    aviso('MANT_VENCIDO', 'c', '2026-11-01'),
    aviso('STOCK_BAJO', 'd', '2026-11-16'),
    aviso('ORDEN_DETENIDA', 'e', '2026-11-10'),
  ]);
  expect(r.grupos.map((g) => g.tipo)).toEqual([
    'MANT_VENCIDO',
    'ORDEN_DETENIDA',
    'STOCK_BAJO',
    'CITA_HOY',
    'MANT_PROXIMO',
  ]);
});

test('dentro_del_grupo_van_primero_los_no_leidos_y_despues_por_fecha', () => {
  const r = groupNotices([
    aviso('STOCK_BAJO', 'leido-viejo', '2026-11-01', true),
    aviso('STOCK_BAJO', 'nuevo-reciente', '2026-11-15'),
    aviso('STOCK_BAJO', 'nuevo-viejo', '2026-11-02'),
  ]);
  expect(r.grupos[0].avisos.map((a) => a.clave)).toEqual([
    'nuevo-viejo',
    'nuevo-reciente',
    'leido-viejo',
  ]);
});

test('calcula_cantidad_no_leidos_y_total_de_avisos', () => {
  const r = groupNotices([
    aviso('STOCK_BAJO', 'x', '2026-11-01', true),
    aviso('STOCK_BAJO', 'y', '2026-11-02'),
    aviso('CITA_HOY', 'z', '2026-11-16'),
  ]);
  expect(r.noLeidos).toBe(2);
  expect(r.totalAvisos).toBe(3);
  expect(r.grupos[0]).toMatchObject({
    tipo: 'STOCK_BAJO',
    titulo: 'Refacciones con stock bajo',
    cantidad: 2,
    noLeidos: 1,
  });
});

test('sin_avisos_responde_vacio', () => {
  expect(groupNotices([])).toEqual({ noLeidos: 0, totalAvisos: 0, grupos: [] });
});
