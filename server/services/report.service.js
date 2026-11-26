// Reportes del taller (Sprint 7, Entrega B, US4 a US7, FR-031 a FR-039).
// Toda la aritmética se hace en centavos enteros (FR-032, CA-7) y solo al
// responder se convierte a número de dos decimales. Cada reporte devuelve los
// datos JSON y, para la exportación, las mismas filas en forma de tabla
// (FR-037: el CSV tiene las mismas filas y cifras que la pantalla).
// Fuente de verdad: specs/007-reportes-configuracion/contracts/reports.md.
import * as reportModel from '../models/report.js';
import { toCents, fromCents } from '../utils/money.js';
import { csvMoney } from '../utils/csv.js';

// FR-039: listas acotadas. Servicios frecuentes: máximo 50 (contrato); el
// resto, un tope alto que en un taller no se alcanza.
export const SERVICES_LIMIT = 50;
export const LIST_LIMIT = 500;

export const AVISO_SIN_COSTO = 'sin costo registrado';
export const AVISO_SIN_EXISTENCIA = 'sin existencia';
export const SIN_MECANICO = 'Sin mecánico asignado';

const cents = (value) => toCents(value ?? 0) ?? 0;

// --- Ingresos (US4, FR-032) -------------------------------------------------
export async function incomeReport(range) {
  const [porMetodo, porDia] = await Promise.all([
    reportModel.incomeByMethod(range),
    reportModel.incomeByDay(range),
  ]);
  let totalCents = 0;
  let pagos = 0;
  const metodos = porMetodo.map((row) => {
    const total = cents(row.total);
    totalCents += total;
    pagos += Number(row.pagos);
    return { metodo: row.metodo, total: fromCents(total), pagos: Number(row.pagos) };
  });
  const dias = porDia.map((row) => ({
    fecha: row.fecha,
    total: fromCents(cents(row.total)),
    pagos: Number(row.pagos),
  }));
  return { ...range, total: fromCents(totalCents), pagos, porMetodo: metodos, porDia: dias };
}

function incomeTable(data) {
  return {
    headers: ['seccion', 'clave', 'total', 'pagos'],
    rows: [
      ['Total', `${data.desde} a ${data.hasta}`, csvMoney(data.total), data.pagos],
      ...data.porMetodo.map((m) => ['Por método', m.metodo, csvMoney(m.total), m.pagos]),
      ...data.porDia.map((d) => ['Por día', d.fecha, csvMoney(d.total), d.pagos]),
    ],
  };
}

// --- Servicios frecuentes (US5, FR-033) -------------------------------------
export async function servicesReport(range) {
  const rows = await reportModel.frequentServices(range, SERVICES_LIMIT);
  const elementos = rows.map((row) => {
    const base = row.tipo_id
      ? { tipoServicioId: row.tipo_id, tipoServicio: row.tipo, descripcion: null }
      : { tipoServicioId: null, tipoServicio: null, descripcion: row.descripcion };
    return { ...base, veces: Number(row.veces), manoDeObra: fromCents(cents(row.mano_total)) };
  });
  return { ...range, elementos };
}

function servicesTable(data) {
  return {
    headers: ['tipo_servicio', 'descripcion', 'veces', 'mano_de_obra'],
    rows: data.elementos.map((e) => [e.tipoServicio, e.descripcion, e.veces, csvMoney(e.manoDeObra)]),
  };
}

// --- Productividad (US5, FR-034) --------------------------------------------
export async function productivityReport(range) {
  const rows = await reportModel.productivity(range, LIST_LIMIT);
  const elementos = rows.map((row) => ({
    mecanicoId: row.mecanico_id ?? null,
    mecanico: row.mecanico_id ? row.mecanico : SIN_MECANICO,
    ordenesTerminadas: Number(row.ordenes),
    manoDeObra: fromCents(cents(row.mano_total)),
  }));
  return { ...range, elementos };
}

function productivityTable(data) {
  return {
    headers: ['mecanico', 'ordenes_terminadas', 'mano_de_obra'],
    rows: data.elementos.map((e) => [e.mecanico, e.ordenesTerminadas, csvMoney(e.manoDeObra)]),
  };
}

// --- Margen de refacciones (US6, FR-035) ------------------------------------
// Costo = precio de compra vigente × cantidad; venta = precio congelado de
// cada línea × cantidad. Sin precio de compra: "sin costo registrado", costo
// y margen null, y la línea no entra en los totales.
export async function partsReport(range) {
  const rows = await reportModel.partsMargin(range);
  const totales = { costo: 0, venta: 0, margen: 0 };
  const elementos = rows.map((row) => {
    const cantidad = Number(row.cantidad);
    const venta = cents(row.venta);
    const compra = toCents(row.purchase_price);
    if (compra === null) {
      return {
        refaccionId: row.id,
        codigo: row.code,
        nombre: row.name,
        cantidad,
        costo: null,
        venta: fromCents(venta),
        margen: null,
        aviso: AVISO_SIN_COSTO,
      };
    }
    const costo = compra * cantidad;
    totales.costo += costo;
    totales.venta += venta;
    totales.margen += venta - costo;
    return {
      refaccionId: row.id,
      codigo: row.code,
      nombre: row.name,
      cantidad,
      costo: fromCents(costo),
      venta: fromCents(venta),
      margen: fromCents(venta - costo),
      aviso: null,
    };
  });
  return {
    ...range,
    elementos: elementos.slice(0, LIST_LIMIT),
    totales: {
      costo: fromCents(totales.costo),
      venta: fromCents(totales.venta),
      margen: fromCents(totales.margen),
    },
  };
}

function partsTable(data) {
  return {
    headers: ['codigo', 'nombre', 'cantidad', 'costo', 'venta', 'margen', 'aviso'],
    rows: [
      ...data.elementos.map((e) => [
        e.codigo,
        e.nombre,
        e.cantidad,
        csvMoney(e.costo),
        csvMoney(e.venta),
        csvMoney(e.margen),
        e.aviso,
      ]),
      [
        'TOTAL',
        `Sin las líneas "${AVISO_SIN_COSTO}"`,
        '',
        csvMoney(data.totales.costo),
        csvMoney(data.totales.venta),
        csvMoney(data.totales.margen),
        '',
      ],
    ],
  };
}

// --- Rotación (US6, FR-036) -------------------------------------------------
export async function rotationReport(range) {
  const rows = await reportModel.partsRotation(range, LIST_LIMIT);
  const elementos = rows.map((row) => {
    const salidas = Number(row.salidas);
    const existencia = Number(row.stock_current);
    return {
      refaccionId: row.id,
      codigo: row.code,
      nombre: row.name,
      salidas,
      existencia,
      rotacion: existencia > 0 ? Math.round((salidas * 100) / existencia) / 100 : null,
      aviso: existencia > 0 ? null : AVISO_SIN_EXISTENCIA,
    };
  });
  return { ...range, elementos };
}

function rotationTable(data) {
  return {
    headers: ['codigo', 'nombre', 'salidas', 'existencia', 'rotacion', 'aviso'],
    rows: data.elementos.map((e) => [
      e.codigo,
      e.nombre,
      e.salidas,
      e.existencia,
      e.rotacion === null ? '' : e.rotacion.toFixed(2),
      e.aviso,
    ]),
  };
}

// Registro de reportes: nombre de la ruta → cálculo y tabla para el CSV.
export const REPORTS = Object.freeze({
  ingresos: { build: incomeReport, table: incomeTable },
  servicios: { build: servicesReport, table: servicesTable },
  productividad: { build: productivityReport, table: productivityTable },
  refacciones: { build: partsReport, table: partsTable },
  rotacion: { build: rotationReport, table: rotationTable },
});
