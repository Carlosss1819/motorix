// Controlador de los reportes (Sprint 7, Entrega B). Delgado: valida el
// rango, pide el cálculo al servicio y responde en JSON o en CSV.
import { REPORTS } from '../services/report.service.js';
import { parseReportRange } from '../utils/report-range.js';
import { toCsv } from '../utils/csv.js';
import { sendOk } from '../utils/response.js';

export function reportHandler(name) {
  const report = REPORTS[name];
  return async (req, res) => {
    const range = parseReportRange(req.query);
    const { desde, hasta } = range;
    const data = await report.build({ desde, hasta });
    if (req.query.formato === 'csv') {
      const { headers, rows } = report.table(data);
      res
        .status(200)
        .set('Content-Type', 'text/csv; charset=utf-8')
        .set('Content-Disposition', `attachment; filename="${name}_${desde}_${hasta}.csv"`)
        .send(toCsv(headers, rows));
      return;
    }
    sendOk(res, data);
  };
}
