# TP3 — Simulación de cuentas de ahorro

Instituto Tecnológico de Costa Rica · Escuela de Ingeniería en Computación
Bases de Datos 1 · Profesor Franco Quirós Ramírez · Tarea programada 3

| Integrante | Carné |
|---|---|
| Ignacio Lorenzo Martínez | 2019068171 |
| Maripaz Quesada Leitón | 2023073101 |

- Bitácora de trabajo (Blogger): https://tareatp3bd1.blogspot.com
- Informe: documento «TP3 Base de datos1» 

## Qué hace el proyecto

Simula cuatro meses (1 de marzo al 30 de junio de 2026, 122 fechas) de un sistema de cuentas de ahorro a partir de dos XML: los catálogos y las operaciones. Por cada fecha, en orden: da de alta personas, cuentas, beneficiarios y usuarios; aplica los movimientos (con la comisión SINPE cuando corresponde); y cierra y abre los estados de cuenta que vencen ese día (intereses, multas y cargos). Una página web permite consultar los estados de cuenta, sus movimientos y, solo al administrador, el control de la simulación y el envío de comprobantes por correo.

La base de datos es la misma de la TP2 (`CuentaAhorrosTP2`), ampliada con el modelo financiero de la TP3.

## Ambiente

| | Versión usada |
|---|---|
| SQL Server | [2022] |
| SQL Server Management Studio (SSMS) | [2022] |
| Node.js | [26.13.0] |

## 1. Instalar la base de datos

Abrir cada script en SSMS y ejecutarlo completo, **en este orden**. Todos usan `USE CuentaAhorrosTP2`.

| # | Script | Para qué |
|---|---|---|
| 1 | `Sql/TP2/TP2/CreaBasesTablas.sql` | Crea la base `CuentaAhorrosTP2` y las tablas base |
| 2 | `Sql/TP3/01_ModeloFisicoFinanciero.sql` | Amplía el modelo: `TipoMovimiento`, `Movimiento` y columnas nuevas de `EstadoCuenta` |
| 3 | `Sql/TP2/TP2/bdpermisos.sql` | Solo la **parte 1** (crea la tabla `dbo.ErrorBD`). Los `GRANT` de la parte 2 no son necesarios |
| 4 | `Sql/TP2/TP2/04_RegistrarErrorSP.sql` | `sp_RegistrarError` |
| 5 | `Sql/TP2/TP2/Sp_RegistrarBitacora.sql` | `sp_RegistrarBitacora` |
| 6 | `Sql/TP2/TP2/05_SesionCuentasSP.sql` | Inicio de sesión y cuentas del usuario |
| 7 | `Sql/TP2/TP2/Sp_Beneficiarios.sql` | Beneficiarios |
| 8 | `Sql/TP2/TP2/Sp_ConsultarCatalogos.sql` | Listas de parentescos y tipos de documento |
| 9 | `Sql/TP3/12_ControlSimulacion.sql` | Tablas `CorridaSimulacion` y `ControlSimulacion` (control y reanudación) |
| 10 | `Sql/TP3/13_Comprobantes.sql` | Tabla `Comprobante` y su vínculo con `Movimiento` |
| 11 | `Sql/TP3/Sp_CargarCatalogos.sql` | `sp_CargarCatalogos` |
| 12 | `Sql/TP3/CargarCatalogos.sql` | Carga los catálogos (XML incluido en el script) y prueba un XML inválido y uno nulo |
| 13 | `Sql/TP3/Crear_Admin.sql` | Usuario administrador (el XML no trae uno) |
| 14 | `Sql/TP3/TriggerAperturaEstadoCuenta.sql` | Trigger que abre el primer estado de cuenta |
| 15 | `Sql/TP3/Sp_CargarAltasDia.sql` | Altas de un día |
| 16 | `Sql/TP3/Sp_AplicarMovimiento.sql` | Aplicación de un movimiento |
| 17 | `Sql/TP3/Sp_CerrarYAbrirEstadoCuenta.sql` | Cierre y apertura de estado de cuenta |
| 18 | `Sql/TP3/Sp_ConsultarEstadosCuenta3.sql` | Consulta de estados de cuenta (reemplaza la de la TP2) |
| 19 | `Sql/TP3/Sp_ConsultarMovimientoEstadoCuenta.sql` | Consulta de movimientos de un estado |
| 20 | `Sql/TP3/Sp_ConsultarControlSimulacion.sql` | Datos de la página de control |
| 21 | `Sql/TP3/Sp_ConsultarComprobantes.sql` | Lista de comprobantes |
| 22 | `Sql/TP3/Sp_RegistrarEnvioComprobante.sql` | Registro del envío de un comprobante |

**No ejecutar** estos scripts de la TP2, porque los reemplazan los de la TP3: `06_EstadoscuentaSP.sql`, `Sp_Cargar.sql`, `CargarCatalogos.sql` (el de `Sql/TP2`), `EjecutarCargaCatalogos.sql`, `EjecutarCargaNoCatalogos.sql` y `Pruebas_BD.sql`.

## 2. Correr la simulación

1. Abrir `Sql/TP3/Simulacion_TP3.sql` en SSMS (contiene el XML de operaciones) y ejecutarlo completo.
2. Correrlo desde **una sola ventana** a la vez.
3. Al terminar devuelve un resumen. Resultado esperado de la corrida completa:

| Dato | Valor |
|---|---|
| Fechas procesadas | 122 |
| Movimientos del XML | 100 |
| Movimientos en total (con comisiones y cargos del sistema) | 161 |
| Cierres de estado de cuenta | 27 |
| Estados de cuenta | 37 |
| Comprobantes | 100 |

**Control y reanudación.** Cada fecha queda registrada en `ControlSimulacion` y cada ejecución en `CorridaSimulacion`. Si la ejecución se interrumpe, volver a correr el script continúa desde la última fecha, el último movimiento y el último cierre procesados, sin repetir nada. Si todo ya estaba terminado, el script no hace nada (código de resultado 1).

**Repetir desde cero.** `Sql/TP3/Limpiar_DatosTP3.sql` borra **todos** los datos de cuentas, movimientos, comprobantes y control (y vacía `ErrorBD`); conserva catálogos, SP y trigger, y vuelve a crear el administrador. No ejecutarlo sobre la base de entrega si no se quiere perder la simulación.

## 3. Pruebas

| Script | Qué prueba |
|---|---|
| `Sql/TP3/Pruebas_ModeloFisico.sql` | Restricciones del modelo físico (5 pruebas; terminan en ROLLBACK) |
| `Sql/TP3/Pruebas_AltasDia.sql` | `sp_CargarAltasDia` con el día 2026-03-01 del XML real (5 casos; terminan en ROLLBACK) |
| `Sql/TP3/Prueba_ReanudarSimulacion.sql` | Corre la simulación en 4 corridas cortadas y compara contra la corrida completa. Las instrucciones están al inicio del script |
| `Web/Server/pruebas_servidor.js` | Rutas del servidor contra una base falsa (no necesita SQL Server): `node pruebas_servidor.js` |

## 4. Levantar la página web

### Servidor (puerto 3001)

```bash
cd Web/Server
npm install
copy .env.example .env      # en Linux/macOS: cp .env.example .env
```

Editar `.env` con los datos de la base (ver `.env.example`). El `.env` **no se sube a GitHub**. El servidor lo lee solo al arrancar: si se cambia, hay que reiniciarlo.

```bash
npm start
```

### Interfaz (puerto 5173)

```bash
cd Web/client
npm install
npm run dev
```

Abrir http://localhost:5173. Vite redirige `/api` al servidor del puerto 3001, así que el servidor debe estar corriendo.

### Usuarios de prueba

| Usuario | Clave | Qué ve |
|---|---|---|
| `fquiros` | `admin1234` | Administrador: todas las cuentas y la página «Control de la simulación» |
| `amora` | `AnaMora2026*` | Cliente: solo sus cuentas (los demás clientes vienen en el XML de operaciones) |

Un cliente que intente abrir `/simulacion` es redirigido a sus cuentas, y sin sesión se redirige al inicio de sesión.

## 5. Comprobantes por correo

Los movimientos cuyo tipo tiene `flagGeneraComprobante` generan un comprobante, que se guarda en `dbo.Comprobante` dentro de la misma transacción del movimiento. El correo se envía después, desde el servidor, con el botón «Enviar comprobantes pendientes» de la página de control (solo administrador). Los que fallan quedan pendientes y se reintentan con el mismo botón.

Se configura en el `.env`:

- `CORREO_MODO=archivo` (por defecto): no sale nada a Internet; cada correo se guarda como `.eml` en `Web/Server/correos_enviados/`. En este modo el comprobante queda registrado como enviado aunque solo se generó el archivo.
- `CORREO_MODO=smtp`: envío real por SMTP (`SMTP_HOST`, `SMTP_PUERTO`, `SMTP_SEGURO`, `SMTP_USUARIO`, `SMTP_CLAVE`). Los correos del XML son ficticios (`@ejemplo.com`), por eso todos se redirigen a `CORREO_REDIRIGIR_A`, y el texto indica a quién iban dirigidos. La prueba de SMTP se hizo con un buzón de pruebas de Ethereal (ver la bitácora).

## Notas

- Las contraseñas del `.env` y de SMTP nunca se suben al repositorio.
- Los códigos de resultado (`@outResultCode`) de cada procedimiento están documentados en el encabezado de su script.
- Los errores de SQL se guardan en `dbo.ErrorBD`.