// Pruebas unitarias del cálculo del total de la orden al cobrar (Sprint 4,
// FR-015, D2 y D2.1). Módulo puro: sin base de datos.
// Fuente de verdad: specs/004-pagos-tickets-dashboard/research.md (D2).
import {
  calcularTotal,
  LIMITE_TOTAL_CENTAVOS,
  excedeLimite,
} from '../../utils/order-total.js';

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

describe('calcularTotal — refacciones (FR-015; Sprint 5: precio congelado de la línea)', () => {
  test('multiplica el precio unitario congelado de la línea por la cantidad usada', () => {
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

// ---------------------------------------------------------------------------
// Sprint 5 (FR-008, FR-009, R-06): cálculo en centavos enteros con el precio
// congelado de cada línea (`order_parts.unit_price`).
// ---------------------------------------------------------------------------

describe('calcularTotal — centavos y precio congelado (Sprint 5)', () => {
  test('el_importe_de_linea_usa_el_precio_unitario_congelado_de_la_linea', () => {
    // mysql2 entrega DECIMAL como cadena: el cálculo la acepta sin flotantes.
    const total = calcularTotal({
      refacciones: [
        { id: 1, descripcion: 'Pastillas', cantidad: 2, partId: 3, precioUnitario: '320.00' },
      ],
    });
    expect(total.desglose.refacciones[0].precioUnitario).toBe(320);
    expect(total.desglose.refacciones[0].subtotal).toBe(640);
    expect(total.total).toBe(640);
  });

  test('una_linea_sin_precio_vale_0_con_aviso_sin_precio_registrado', () => {
    const total = calcularTotal({
      manoDeObra: [{ id: 1, descripcion: 'Revisión', precio: '100.00' }],
      refacciones: [
        { id: 1, descripcion: 'Sin precio', cantidad: 3, partId: 9, precioUnitario: null },
      ],
    });
    expect(total.desglose.refacciones[0].subtotal).toBe(0);
    expect(total.desglose.refacciones[0].aviso).toBe('sin precio registrado');
    expect(total.total).toBe(100);
  });

  test('tres_por_33_33_suma_99_99_exacto', () => {
    const total = calcularTotal({
      refacciones: [
        { id: 1, descripcion: 'Tornillo', cantidad: 3, partId: 1, precioUnitario: '33.33' },
      ],
    });
    expect(total.subtotalRefacciones).toBe(99.99);
    expect(total.total).toBe(99.99);
  });

  test('una_orden_de_10_lineas_suma_igual_que_a_mano_SC_003', () => {
    const precios = ['0.10', '0.20', '0.30', '19.99', '33.33', '45.05', '120.01', '0.07', '999.99', '1.11'];
    const refacciones = precios.map((precio, index) => ({
      id: index + 1,
      descripcion: `Línea ${index + 1}`,
      cantidad: index + 1,
      partId: index + 1,
      precioUnitario: precio,
    }));
    // A mano, en centavos: Σ cantidad × precio.
    const centavos = precios.reduce(
      (suma, precio, index) => suma + (index + 1) * Math.round(Number(precio) * 100),
      0,
    );
    const total = calcularTotal({
      manoDeObra: [{ id: 1, descripcion: 'Mano de obra', precio: '0.30' }],
      refacciones,
    });
    expect(total.subtotalRefacciones).toBe(centavos / 100);
    expect(total.total).toBe((centavos + 30) / 100);
  });

  test('el_total_de_mano_de_obra_y_refacciones_no_tiene_un_precio_de_servicio_aparte_FR_009', () => {
    const total = calcularTotal({
      manoDeObra: [{ id: 1, descripcion: 'Frenos', precio: '750.00' }],
      refacciones: [
        { id: 1, descripcion: 'Pastillas', cantidad: 2, partId: 3, precioUnitario: '320.00' },
      ],
    });
    expect(total.total).toBe(1390);
  });

  test('excedeLimite_es_verdadero_por_encima_de_9999999999_centavos', () => {
    expect(LIMITE_TOTAL_CENTAVOS).toBe(9999999999);
    expect(excedeLimite(9999999999)).toBe(false);
    expect(excedeLimite(10000000000)).toBe(true);
  });
});
