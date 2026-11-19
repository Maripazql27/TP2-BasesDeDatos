USE CuentaAhorrosTP2;
GO

/*
   Cuando se inserta una cuenta, abre su primer estado de cuenta: empieza en
   la fecha de creacion, termina un mes despues, sus saldos son el saldo de
   la cuenta (0) y todos sus contadores empiezan en 0.
   Funciona con varias cuentas en un mismo INSERT (usa la tabla inserted).

   Una cuenta nueva debe iniciar con saldo 0. Si alguna no lo hace, se
   rechaza todo el INSERT con THROW 50110 y no queda nada a medias.

   Se puede ejecutar varias veces: si el trigger ya existe, lo reemplaza.
*/

CREATE OR ALTER TRIGGER dbo.tr_Cuenta_AperturaEstadoCuenta
ON dbo.Cuenta
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    -- Las cuentas inician con saldo 0.
    IF EXISTS (
        SELECT 1
        FROM inserted AS i
        WHERE i.Saldo <> 0
    )
    BEGIN
        THROW 50110, 'Las cuentas deben iniciar con saldo 0.', 1;
    END;

    -- Primer estado de cuenta de cada cuenta insertada.
    INSERT INTO dbo.EstadoCuenta (
        IdCuenta
        , FechaInicio
        , FechaFin
        , SaldoInicial
        , SaldoMinimo
        , SaldoFinal
        , InteresesAcumulados
        , CantRetiros
        , CantDepositos
        , CantSinpeEntrantes
        , CantSinpeSalientes
        , CantOperacionesATM
        , CantRetirosATM
        , CantOperacionesHumano
        , CantRetirosHumano
    )
    SELECT
        i.Id
        , i.FechaCreacion
        , DATEADD(MONTH, 1, i.FechaCreacion)
        , i.Saldo
        , i.Saldo
        , i.Saldo
        , 0
        , 0
        , 0
        , 0
        , 0
        , 0
        , 0
        , 0
        , 0
    FROM inserted AS i;
END;
GO