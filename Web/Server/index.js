// index.js — PUNTO DE ARRANQUE DEL SERVIDOR
// Se ejecuta con:  npm start   (o  node index.js)
// Lee la configuración del archivo .env, crea la app con el ejecutarSP real
// Db.js y se pone a escuchar peticiones.
import 'dotenv/config';
import { crearApp } from './app.js';
import { ejecutarSP } from './Db.js';

const secreto = process.env.SESION_SECRETO;
if (!secreto) {
  // Sin secreto no se puede firmar la cookie de sesión: mejor no arrancar.
  console.error('Falta SESION_SECRETO en el archivo .env');
  process.exit(1);
}

const puerto = Number(process.env.PUERTO) || 3001;
const app = crearApp(ejecutarSP, { secreto, produccion: process.env.NODE_ENV === 'production' });

app.listen(puerto, () => console.log(`Servidor escuchando en http://localhost:${puerto}`));