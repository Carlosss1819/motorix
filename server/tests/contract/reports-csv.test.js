// Contrato de la exportación CSV de los reportes (Sprint 7, Entrega B, US7,
// FR-037, SC-007): cabeceras HTTP, BOM y las mismas filas y cifras que el
// JSON en los cinco reportes.
import { api, bearer } from '../helpers/api.js';
import { prepareTestDatabase } from '../helpers/db.js';
import { crearContexto } from '../helpers/fixtures.js';
import { ventanaLibre, marcarTerminada, insertarPago, insertarSalida } from '../helpers/report-fixtures.js';

let ctx;
let rango;
const nombreConComa = `Balata "cerámica", piñón ${Date.now()}`;

// Lector CSV mínimo para la prueba: comillas dobles, comillas duplicadas y CRLF.
function parseCsv(texto) {
  const filas = [];
  let fila = [];
  let campo = '';
  let entreComillas = false;
  for (let i = 0; i < texto.length; i += 1) {
    const c = texto[i];
    if (entreComillas) {
      if (c === '"' && texto[i + 1] === '"') {
        campo += '"';
        i += 1;
      } else if (c === '"') {
        entreComillas = false;
      } else {
        campo += c;
      }
    } else if (c === '"') {
      entreComillas = true;
    } else if (c === ',') {
      fila.push(campo);
      campo = '';
    } else if (c === '\r' && texto[i + 1] === '\n') {
      fila.push(campo);
      filas.push(fila);
      fila = [];
      campo = '';
      i += 1;
    } else {
      campo += c;
    }
  }
  return filas;
}

const dinero = (v) => (v === null ? '' : v.toFixed(2));

beforeAll(async () => {
  await prepareTestDatabase();
  ctx = await crearContexto('Reporte CSV');
  rango = await ventanaLibre(40, 2);

  const orden = await ctx.crearOrden({ asignarMecanico: true });
  const s = await api
    .post(`/api/service-orders/${orden}/servicios`)
    .set(bearer(ctx.tokens.admin))
    .send({ descripcion: 'Afinación con bujías', duracionMinutos: 60, precio: 850.5, tipoServicioId: 70002 });
  expect(s.status).toBe(201);
  const conCosto = await ctx.crearRefaccion({ precioVenta: 75.5, precioCompra: 40, stock: 20 });
  const sinCosto = await ctx.crearRefaccion({ precioVenta: 20, stock: 20 });
  // Nombre con comillas, coma y eñe para revisar el escape.
  await api.put(`/api/parts/${sinCosto}`).set(bearer(ctx.tokens.admin)).send({ nombre: nombreConComa });
  expect((await ctx.agregarRefaccion(orden, conCosto, 2)).status).toBe(201);
  expect((await ctx.agregarRefaccion(orden, sinCosto, 1)).status).toBe(201);
  await marcarTerminada(orden, `${rango.desde} 12:00:00`);
  await insertarPago(orden, { monto: '1021.50', metodo: 'TARJETA', fechaHora: `${rango.hasta} 09:00:00` });
  await insertarPago(orden, { monto: '10.00', metodo: 'EFECTIVO', fechaHora: `${rango.desde} 09:00:00` });
  await insertarSalida(conCosto, 2, `${rango.desde} 12:00:00`);
  await insertarSalida(sinCosto, 1, `${rango.desde} 12:00:00`);
});

async function ambos(reporte) {
  const query = `desde=${rango.desde}&hasta=${rango.hasta}`;
  const json = await api.get(`/api/reports/${reporte}?${query}`).set(bearer(ctx.tokens.admin));
  const csv = await api
    .get(`/api/reports/${reporte}?${query}&formato=csv`)
    .set(bearer(ctx.tokens.admin))
    .buffer(true)
    .parse((res, cb) => {
      let data = '';
      res.setEncoding('utf8');
      res.on('data', (chunk) => {
        data += chunk;
      });
      res.on('end', () => cb(null, data));
    });
  expect(json.status).toBe(200);
  expect(csv.status).toBe(200);
  return { json: json.body, csv };
}

test.each(['ingresos', 'servicios', 'productividad', 'refacciones', 'rotacion'])(
  'test_el_csv_de_%s_tiene_cabeceras_bom_y_crlf',
  async (reporte) => {
    const { csv } = await ambos(reporte);
    expect(csv.headers['content-type']).toBe('text/csv; charset=utf-8');
    expect(csv.headers['content-disposition']).toBe(
      `attachment; filename="${reporte}_${rango.desde}_${rango.hasta}.csv"`,
    );
    expect(csv.body.charCodeAt(0)).toBe(0xfeff);
    expect(csv.body.endsWith('\r\n')).toBe(true);
  },
);

test('test_ingresos_csv_tiene_las_mismas_filas_y_cifras_que_el_json', async () => {
  const { json, csv } = await ambos('ingresos');
  expect(parseCsv(csv.body.slice(1))).toEqual([
    ['seccion', 'clave', 'total', 'pagos'],
    ['Total', `${rango.desde} a ${rango.hasta}`, dinero(json.total), String(json.pagos)],
    ...json.porMetodo.map((m) => ['Por método', m.metodo, dinero(m.total), String(m.pagos)]),
    ...json.porDia.map((d) => ['Por día', d.fecha, dinero(d.total), String(d.pagos)]),
  ]);
  expect(json.total).toBe(1031.5);
});

test('test_servicios_y_productividad_csv_coinciden_con_el_json', async () => {
  const servicios = await ambos('servicios');
  expect(servicios.json.elementos).toHaveLength(1);
  expect(parseCsv(servicios.csv.body.slice(1))).toEqual([
    ['tipo_servicio', 'descripcion', 'veces', 'mano_de_obra'],
    ...servicios.json.elementos.map((e) => [
      e.tipoServicio ?? '',
      e.descripcion ?? '',
      String(e.veces),
      dinero(e.manoDeObra),
    ]),
  ]);
  expect(servicios.csv.body).toContain('Afinación');

  const productividad = await ambos('productividad');
  expect(parseCsv(productividad.csv.body.slice(1))).toEqual([
    ['mecanico', 'ordenes_terminadas', 'mano_de_obra'],
    ...productividad.json.elementos.map((e) => [e.mecanico, String(e.ordenesTerminadas), dinero(e.manoDeObra)]),
  ]);
});

test('test_refacciones_csv_coincide_con_el_json_incluido_el_total_y_el_escape', async () => {
  const { json, csv } = await ambos('refacciones');
  expect(json.elementos).toHaveLength(2);
  expect(parseCsv(csv.body.slice(1))).toEqual([
    ['codigo', 'nombre', 'cantidad', 'costo', 'venta', 'margen', 'aviso'],
    ...json.elementos.map((e) => [
      e.codigo,
      e.nombre,
      String(e.cantidad),
      dinero(e.costo),
      dinero(e.venta),
      dinero(e.margen),
      e.aviso ?? '',
    ]),
    [
      'TOTAL',
      'Sin las líneas "sin costo registrado"',
      '',
      dinero(json.totales.costo),
      dinero(json.totales.venta),
      dinero(json.totales.margen),
      '',
    ],
  ]);
  expect(json.elementos.map((e) => e.nombre)).toContain(nombreConComa);
});

test('test_rotacion_csv_coincide_con_el_json', async () => {
  const { json, csv } = await ambos('rotacion');
  expect(json.elementos).toHaveLength(2);
  expect(parseCsv(csv.body.slice(1))).toEqual([
    ['codigo', 'nombre', 'salidas', 'existencia', 'rotacion', 'aviso'],
    ...json.elementos.map((e) => [
      e.codigo,
      e.nombre,
      String(e.salidas),
      String(e.existencia),
      e.rotacion === null ? '' : e.rotacion.toFixed(2),
      e.aviso ?? '',
    ]),
  ]);
});
