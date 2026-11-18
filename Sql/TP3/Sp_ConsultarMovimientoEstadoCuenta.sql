USE CuentaAhorrosTP2;
GO

--sp para consultar los movimientos de un estado de cuenta
--valida persmisos, registra bitacora y ordena por fecha

CREATE OR ALTER PROCEDURE dbo.sp_ConsultarMovimientosEstadoCuenta
	@inIdUsuario INT,
	@inNumeroCuenta VARCHAR(16),
	@inIdEstadoCuenta INT,
	@outResultCode INT OUTPUT
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @idCuenta INT;
	DECLARE @flagEsAdministrador BIT;
	DECLARE @codigoBitacora INT;
	DECLARE @NombreMoneda VARCHAR (32);
	DECLARE @SimboloMoneda NVARCHAR(4);

	SET @outResultCode = 0;

	--Validacion de parametrox

	IF @inIdUsuario IS NULL
		OR @inNumeroCuenta IS NULL
		OR LTRIM(RTRIM(@inNumeroCuenta)) = ''
		OR @inIdEstadoCuenta IS NULL
		OR @inIdEstadoCuenta <= 0
	BEGIN
		SET @outResultCode = 50002;
		RETURN;
	END;

	BEGIN TRY

		--identificador usuario
		SELECT
			@flagEsAdministrador = U.EsAdministrador
			FROM dbo.Usuario AS U
			WHERE U.Id = @inIdUsuario;


		--identifica cuanta y moneda
        SELECT
            @idCuenta = C.Id,
            @NombreMoneda = TM.Nombre,
            @SimboloMoneda = TM.Simbolo
        FROM dbo.Cuenta AS C
        INNER JOIN dbo.TipoCuentaAhorro AS TC
            ON TC.Id = C.IdTipoCuentaAhorro
        INNER JOIN dbo.TipoMoneda AS TM
            ON TM.Id = TC.IdTipoMoneda
        WHERE C.NumeroCuenta = @inNumeroCuenta;

        IF @flagEsAdministrador IS NULL
           OR @idCuenta IS NULL
        BEGIN
            SET @outResultCode = 50002;
            RETURN;
        END;


		--admin cualquier cuenta y cliente solo las autorizadas
		IF @flagEsAdministrador = 0
			AND NOT EXISTS (
				SELECT 1
				FROM dbo.UsuarioPuedeVer
				WHERE IdUsuario = @inIdUsuario
					AND IdCuenta = @idCuenta
			)
			BEGIN
				SET @outResultCode = 50002;
				RETURN;
			END;


			--Ver que el estado pertenece a cuenta
			IF NOT EXISTS (
				SELECT 1
				FROM dbo.EstadoCuenta
				WHERE Id = @inIdEstadoCuenta
					AND IdCuenta = @idCuenta
			)
			BEGIN
				SET @outResultCode = 50002;
				RETURN;
			END;

			--aqui se registra la conulta del detalle en bitacora (8)
			EXEC dbo.sp_RegistrarBitacora
			    @inIdUsuario = @inIdUsuario,
				@inIdTipoOperacion = 8,
				@inIP = NULL,
				@inJsonAntes = NULL,
				@inJsonDespues = NULL,
				@outResultCode = @codigoBitacora OUTPUT;

			IF @codigoBitacora IS NULL
			   OR @codigoBitacora <> 0
			BEGIN
				SET @outResultCode = ISNULL(@codigoBitacora, 50000);
				RETURN;
			END;


			--detalle crologico, fecha e identificador
			SELECT
				M.Id AS IdMovimiento,
				M.FechaMovimiento,
				M.Monto,
				TM.Accion,
				CASE
					WHEN TM.Accion = 'Debito'
						THEN -M.Monto
					ELSE M.Monto
				END AS MontoConSigno,
				M.Descripcion,
				M.SaldoPosterior,
				TM.Nombre AS TipoMovimiento,
				@NombreMoneda AS NombreMoneda,
				@SimboloMoneda AS SimboloMoneda
			FROM dbo.Movimiento AS M
			INNER JOIN dbo.TipoMovimiento AS TM
				ON TM.Id = M.IdTipoMovimiento
			WHERE M.IdEstadoCuenta = @inIdEstadoCuenta
			ORDER BY M.FechaMovimiento ASC, M.Id ASC;

			SET @outResultCode = 0;

		END TRY
		BEGIN CATCH

			EXEC dbo.sp_RegistrarError;

			SET @outResultCode = 50000;

		END CATCH;
END;
GO