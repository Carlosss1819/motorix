// Pruebas unitarias del cálculo del total de la orden al cobrar (Sprint 4,
// FR-015, D2 y D2.1). Módulo puro: sin base de datos.
// Fuente de verdad: specs/004-pagos-tickets-dashboard/research.md (D2).
import { calcularTotal } from '../../utils/order-total.js';

describe('calcularTotal — mano de obra (FR-015)', () => {
  test('suma las partidas de mano de obra con su precio vigente', () => {
    const total = calcularTotal({
      manoDeObra: [
        { id: 1, descripcion: 'Cambio de aceite', precio: 450 },
        { id: 2, descripcion: 'Rotación', precio: 200.5 },
      ],
    });

    expect(total.subtotalManoDeObra).toBe(650.5);
    expect(total.subtotalRefacciones).toBe(0);
    expect(total.total).toBe(650.5);
  });

  test('trata el precio NULL de la mano de obra como 0 (opcional desde el Sprint 2)', () => {
    const total = calcularTotal({
      manoDeObra: [
        { id: 1, descripcion: 'Sin precio registrado', precio: null },
        { id: 2, descripcion: 'Con precio', precio: 300 },
      ],
    });

    expect(total.subtotalManoDeObra).toBe(300);
    expect(total.desglose.manoDeObra[0].aviso).toBe('sin precio registrado');
    expect(total.desglose.manoDeObra[1].aviso).toBeNull();
  });
});

describe('calcularTotal — refacciones (FR-015, precios vigentes)', () => {
  test('multiplica el precio de venta vigente del catálogo por la cantidad usada', () => {
    const total = calcularTotal({
      refacciones: [
        { id: 1, descripcion: 'Pastillas', cantidad: 2, partId: 3, precioUnitario: 320 },
        { id: 2, descripcion: 'Aceite', cantidad: 4, partId: 1, precioUnitario: 180.5 },
      ],
    });

    expect(total.subtotalManoDeObra).toBe(0);
    expect(total.subtotalRefacciones).toBe(640 + 722);
    expect(total.total).toBe(1362);
    expect(total.desglose.refacciones[0].subtotal).toBe(640);
    expect(total.desglose.refacciones[1].subtotal).toBe(722);
  });

  test('las filas heredadas sin part_id se valoran en 0 con el aviso (D2.1)', () => {
    const total = calcularTotal({
      refacciones: [
        { id: 1, descripcion: 'Filtro de aceite', cantidad: 1, partId: null, precioUnitario: null },
      ],
    });

    expect(total.subtotalRefacciones).toBe(0);
    expect(total.total).toBe(0);
    expect(total.desglose.refacciones[0].precioUnitario).toBe(0);
    expect(total.desglose.refacciones[0].subtotal).toBe(0);
    expect(total.desglose.refacciones[0].aviso).toBe('sin precio registrado');
    // La cantidad sí se conserva en el desglose, aunque el valor sea 0.
    expect(total.desglose.refacciones[0].cantidad).toBe(1);
  });
});

describe('calcularTotal — combinación y redondeo', () => {
  test('combina mano de obra y refacciones en el total', () => {
    const total = calcularTotal({
      manoDeObra: [{ id: 1, descripcion: 'Mantenimiento mayor', precio: 900 }],
      refacciones: [
        { id: 1, descripcion: 'Aceite', cantidad: 3, partId: 1, precioUnitario: 180.33 },
      ],
    });

    expect(total.subtotalManoDeObra).toBe(900);
    expect(total.subtotalRefacciones).toBe(540.99);
    expect(total.total).toBe(1440.99);
  });

  test('una orden sin servicios ni refacciones tiene total 0', () => {
    const total = calcularTotal({});
    expect(total.total).toBe(0);
    expect(total.desglose.manoDeObra).toEqual([]);
    expect(total.desglose.refacciones).toEqual([]);
  });

  test('el total siempre sale redondeado a dos decimales', () => {
    const total = calcularTotal({
      refacciones: [
        // 666.67 × 3 = 2000.0099999… en flotantes; debe salir 2000.01.
        { id: 1, descripcion: 'Servicio mixto', cantidad: 3, partId: 5, precioUnitario: 666.67 },
      ],
    });

    expect(total.subtotalRefacciones).toBe(2000.01);
    expect(total.total).toBe(2000.01);
  });
});
