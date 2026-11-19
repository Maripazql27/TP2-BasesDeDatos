// envío por correo de los comprobantes
//
// sp_AplicarMovimiento deja cada comprobante listo en dbo.Comprobante (a quién
// va, asunto y texto), dentro de la transacción del movimiento. El correo se
// envía DESPUÉS, desde aquí, fuera de esa transacción: un correo no se puede
// deshacer, así que nunca se manda mientras la base de datos todavía podría
// echar el movimiento para atrás.
//
// Modo de envío, según el archivo .env (si no se pone nada, "archivo"):
//
//   CORREO_MODO=archivo
//     No sale nada a internet. Cada correo se guarda como un archivo .eml en
//     la carpeta CORREO_CARPETA (por defecto Web/Server/correos_enviados).
//     Un .eml se abre con Outlook, Thunderbird o el Bloc de notas.
//
//   CORREO_MODO=smtp
//     Envío real por un servidor SMTP, por ejemplo Gmail con una contraseña
//     de aplicación:
//       SMTP_HOST=smtp.gmail.com
//       SMTP_PUERTO=465
//       SMTP_SEGURO=si                     (con el puerto 465)
//       SMTP_USUARIO=cuenta@gmail.com
//       SMTP_CLAVE=contraseña-de-aplicación
//       CORREO_REMITENTE=Banco TP3 <cuenta@gmail.com>     (opcional)
//       CORREO_REDIRIGIR_A=correo-de-prueba@gmail.com
//     Los correos del XML son ficticios (@ejemplo.com, un dominio que no es
//     nuestro). Por eso, en este modo, todos los comprobantes van a
//     CORREO_REDIRIGIR_A y el texto dice a quién iban dirigidos. Para
//     mandarlos al dueño real de cada cuenta hay que quitar CORREO_REDIRIGIR_A
//     y poner CORREO_DESTINO_REAL=si.

import nodemailer from 'nodemailer';
import { mkdir, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

// Carpeta de este archivo (Web/Server), para ubicar CORREO_CARPETA.
const carpetaServidor = path.dirname(fileURLToPath(import.meta.url));

// Remitente por defecto. ".invalid" es un dominio reservado que no existe.
const REMITENTE_DEFECTO = 'Banco TP3 <comprobantes@banco-tp3.invalid>';

function esSi(valor) {
  return String(valor ?? '').trim().toLowerCase() === 'si';
}

// Arma el correo de un comprobante (una fila de sp_ConsultarComprobantes).
//   para: a quién se manda de verdad (el dueño, o la dirección de prueba).
function armarCorreo(comprobante, remitente, para) {
  const redirigido = para !== comprobante.EmailDestino;
  const aviso = redirigido
    ? `[Correo de prueba: este comprobante iba dirigido a ${comprobante.EmailDestino}]\r\n\r\n`
    : '';
  return {
    from: remitente,
    to: para,
    subject: `Comprobante N.º ${comprobante.IdComprobante}: ${comprobante.Asunto}`,
    text: aviso + comprobante.TextoEmail,
  };
}

// Devuelve { modo, descripcion, enviar(comprobante) }. enviar() lanza un
// error si el correo no salió. Si la configuración del .env está incompleta,
// lanza el error aquí mismo, al arrancar el servidor.
export function crearEnviadorCorreo(entorno = process.env) {
  const modo = String(entorno.CORREO_MODO || 'archivo').trim().toLowerCase();

  if (modo === 'archivo') {
    const carpeta = path.resolve(carpetaServidor, entorno.CORREO_CARPETA || 'correos_enviados');
    const remitente = entorno.CORREO_REMITENTE || REMITENTE_DEFECTO;
    // streamTransport: nodemailer arma el correo completo, pero no lo manda.
    const transporte = nodemailer.createTransport({
      streamTransport: true,
      buffer: true,
      newline: 'windows',
    });

    return {
      modo,
      descripcion: `archivo .eml en la carpeta ${carpeta} (no sale nada a internet)`,
      async enviar(comprobante) {
        const correo = armarCorreo(comprobante, remitente, comprobante.EmailDestino);
        const info = await transporte.sendMail(correo);
        await mkdir(carpeta, { recursive: true });
        const nombre = `comprobante-${String(comprobante.IdComprobante).padStart(6, '0')}.eml`;
        await writeFile(path.join(carpeta, nombre), info.message);
        return { para: correo.to, archivo: nombre };
      },
    };
  }

  if (modo === 'smtp') {
    const host = String(entorno.SMTP_HOST || '').trim();
    const redirigirA = String(entorno.CORREO_REDIRIGIR_A || '').trim();
    if (!host) {
      throw new Error('CORREO_MODO=smtp necesita SMTP_HOST en el archivo .env.');
    }
    if (!redirigirA && !esSi(entorno.CORREO_DESTINO_REAL)) {
      throw new Error(
        'CORREO_MODO=smtp necesita CORREO_REDIRIGIR_A en el archivo .env, porque los ' +
          'correos del XML son ficticios. Para enviar al dueño real de cada cuenta, ' +
          'ponga CORREO_DESTINO_REAL=si.'
      );
    }

    const usuario = entorno.SMTP_USUARIO;
    const remitente =
      entorno.CORREO_REMITENTE || (usuario ? `Banco TP3 <${usuario}>` : REMITENTE_DEFECTO);
    const transporte = nodemailer.createTransport({
      host,
      port: Number(entorno.SMTP_PUERTO) || 587,
      secure: esSi(entorno.SMTP_SEGURO),
      auth: usuario ? { user: usuario, pass: entorno.SMTP_CLAVE } : undefined,
      pool: true, // reutiliza la conexión para enviar varios correos seguidos
    });

    return {
      modo,
      descripcion: redirigirA
        ? `SMTP ${host}: todos los comprobantes van a ${redirigirA} (prueba)`
        : `SMTP ${host}: a cada dueño de cuenta`,
      async enviar(comprobante) {
        const para = redirigirA || comprobante.EmailDestino;
        await transporte.sendMail(armarCorreo(comprobante, remitente, para));
        return { para };
      },
    };
  }

  throw new Error(`CORREO_MODO desconocido: "${modo}". Use archivo o smtp.`);
}
