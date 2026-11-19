USE CuentaAhorrosTP2;
GO

CREATE TRIGGER dbo.tr_Cuenta_AperturaEstadoCuenta
ON dbo.Cuenta
AFTER INSERT
AS
BEGIN
	SET NOCOUNT ON;
--inicio con saldo 0
IF EXISTS (
	SELECT 1
	FROM inserted
	WHERE saldo <>0)

BEGIN
	THROW 50110,
	'Las cuentas deben iniciar con saldo 0.', 1;
END;

--primer estado para cada cuenta
INSERT INTO dbo.EstadoCuenta (
	IdCuenta,
	FechaInicio,
	FechaFin,
	SaldoInicial,
	SaldoMinimo,
	SaldoFinal,
	InteresesAcumulados,
	CantRetiros,
	CantDepositos,
	CantSinpeEntrantes,
	CantSinpeSalientes
)
SELECT 
	i.Id,
	i.FechaCreacion,
	DATEADD(MONTH, 1, i.FechaCreacion),
	i.Saldo,
	i.Saldo,
	i.Saldo,
	0,
	0,
	0,
	0,
	0
FROM inserted AS i;
END;
GO