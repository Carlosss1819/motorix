// Servidor auxiliar para ver Motorix en el navegador (solo desarrollo):
// sirve el build de Flutter web y enruta /api al backend en el puerto 3000
// desde el mismo origen, así no hace falta CORS ni modificar el proyecto.
//
// Las rutas se calculan respecto a este archivo, así que el proyecto
// funciona aunque muevas la carpeta del proyecto a otro lado.
const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');

const PUERTO = Number(process.env.WEB_PORT ?? 8080);
const PUERTO_BACKEND = Number(process.env.PORT ?? 3000);
const BUILD = path.resolve(__dirname, '..', 'client', 'build', 'web');
const DESTINO = { host: '127.0.0.1', puerto: PUERTO_BACKEND };

const TIPOS = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.gif': 'image/gif',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
  '.ttf': 'font/ttf',
  '.map': 'application/json',
  '.txt': 'text/plain; charset=utf-8',
  '.wasm': 'application/wasm',
};

if (!fs.existsSync(path.join(BUILD, 'index.html'))) {
  console.error(`No se encontro el build web en:\n  ${BUILD}`);
  console.error('Genera el build primero con:  flutter build web');
  process.exit(1);
}

function enviarProxy(req, res) {
  const opciones = {
    host: DESTINO.host,
    port: DESTINO.puerto,
    method: req.method,
    path: req.url,
    headers: { ...req.headers, host: `${DESTINO.host}:${DESTINO.puerto}` },
  };
  const salida = http.request(opciones, (respuesta) => {
    res.writeHead(respuesta.statusCode, respuesta.headers);
    respuesta.pipe(res);
  });
  salida.on('error', () => {
    res.writeHead(502, { 'Content-Type': 'application/json; charset=utf-8' });
    res.end('{"error":"El backend no esta disponible en el puerto 3000"}');
  });
  req.pipe(salida);
}

function enviarEstatico(req, res) {
  const ruta = decodeURIComponent(req.url.split('?')[0]);
  let archivo = path.join(BUILD, ruta);
  if (!archivo.startsWith(BUILD)) {
    res.writeHead(403);
    res.end('403');
    return;
  }
  if (ruta === '/' || !path.extname(archivo)) archivo = path.join(BUILD, 'index.html');
  fs.readFile(archivo, (error, datos) => {
    if (error) {
      res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
      res.end('404');
      return;
    }
    res.writeHead(200, {
      'Content-Type': TIPOS[path.extname(archivo).toLowerCase()] ?? 'application/octet-stream',
      'Cache-Control': 'no-cache',
    });
    res.end(datos);
  });
}

http
  .createServer((req, res) => {
    if (req.url.startsWith('/api')) enviarProxy(req, res);
    else enviarEstatico(req, res);
  })
  .listen(PUERTO, () => {
    console.log(`Motorix web en http://localhost:${PUERTO} -> API http://localhost:${DESTINO.puerto}`);
  });
