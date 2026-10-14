USE CuentaAhorrosTP2;
GO

/*
Ejemplo de ejecucion:

DECLARE @outResultCode INT;

EXEC dbo.sp_ListarBeneficiarios
    @inIdUsuario = 1,
    @inNumeroCuenta = '11000001',
    @outResultCode = @outResultCode OUTPUT;

SELECT @outResultCode AS CodigoResultado;
*/

--------------------------------------------------------------------------------------------
--Crea Listar beneficiarios
CREATE OR ALTER PROCEDURE dbo.sp_ListarBeneficiarios
    @inIdUsuario INT,
    @inNumeroCuenta VARCHAR(16),
    @outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    -- ver los parametros recibidos
    IF (@inIdUsuario IS NULL
        OR @inNumeroCuenta IS NULL
        OR LTRIM(RTRIM(@inNumeroCuenta)) = '')
    BEGIN
        SET @outResultCode = 50007;
        RETURN;
    END;

    -- ver el acceso del usuario a la cuenta.
    -- (el administrador puede acceder los datos de cualquier cuenta)
    IF NOT EXISTS (
        SELECT 1
        FROM dbo.Cuenta C
        WHERE C.NumeroCuenta = @inNumeroCuenta
          AND (EXISTS (SELECT 1
                       FROM dbo.UsuarioPuedeVer UV
                       WHERE UV.IdCuenta = C.Id
                         AND UV.IdUsuario = @inIdUsuario)
               OR EXISTS (SELECT 1
                          FROM dbo.Usuario U
                          WHERE U.Id = @inIdUsuario
                            AND U.EsAdministrador = 1))
    )
    BEGIN
        SET @outResultCode = 50002;
        RETURN;
    END;

    BEGIN TRY

        -- Primer resultado beneficiarios activos
        SELECT B.Id AS IdBeneficiario,
               P.Nombre,
               P.ValorDocumentoIdentidad,
               P.FechaNacimiento,
               P.Email,
               B.IdParentezco,
               PA.Nombre AS NombreParentezco,
               B.Porcentaje
        FROM dbo.Beneficiario B
        INNER JOIN dbo.Cuenta C
            ON B.IdCuenta = C.Id
        INNER JOIN dbo.Persona P
            ON B.IdPersona = P.Id
        INNER JOIN dbo.Parentezco PA
            ON B.IdParentezco = PA.Id
        WHERE C.NumeroCuenta = @inNumeroCuenta
          AND B.FlagActivo = 1
        ORDER BY B.Id;

        -- Segundo resultado resumen de porcentajes
        SELECT ISNULL(SUM(B.Porcentaje), 0)
                   AS SumaPorcentajes,
               COUNT(B.Id)
                   AS CantidadBeneficiarios
        FROM dbo.Beneficiario B
        INNER JOIN dbo.Cuenta C
            ON B.IdCuenta = C.Id
        WHERE C.NumeroCuenta = @inNumeroCuenta
          AND B.FlagActivo = 1;

        SET @outResultCode = 0;

    END TRY
    BEGIN CATCH
        SET @outResultCode = 50000;
    END CATCH;
END;
GO

--------------------------------------------------------------------------------------------------
--Crea agregar beneficiario
CREATE OR ALTER PROCEDURE dbo.sp_AgregarBeneficiario
    @inIdUsuario INT,
    @inNumeroCuenta VARCHAR(16),
    @inIdTipoDocuIdentidad INT,
    @inValorDocumentoIdentidad VARCHAR(32),
    @inNombre VARCHAR(64),
    @inFechaNacimiento DATE,
    @inEmail VARCHAR(128),
    @inTelefono1 VARCHAR(16),
    @inTelefono2 VARCHAR(16),
    @inIdParentezco INT,
    @inPorcentaje INT,
    @outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @idCuenta INT;
    DECLARE @idPersona INT;
    DECLARE @idBeneficiario INT;
    DECLARE @cantidadActivos INT;
    DECLARE @sumaPorcentajes INT;
    DECLARE @codigoBitacora INT;
    DECLARE @jsonDespues NVARCHAR(MAX);

    -- ver los datos obligatorios
    IF (@inIdUsuario IS NULL
        OR @inNumeroCuenta IS NULL
        OR LTRIM(RTRIM(@inNumeroCuenta)) = ''
        OR @inIdTipoDocuIdentidad IS NULL
        OR @inValorDocumentoIdentidad IS NULL
        OR LTRIM(RTRIM(@inValorDocumentoIdentidad)) = ''
        OR @inNombre IS NULL
        OR LTRIM(RTRIM(@inNombre)) = ''
        OR @inFechaNacimiento IS NULL
        OR @inEmail IS NULL
        OR @inTelefono1 IS NULL
        OR @inTelefono2 IS NULL
        OR @inIdParentezco IS NULL)
    BEGIN
        SET @outResultCode = 50007;
        RETURN;
    END;

    -- ver formatos segun el modelo fisico
    IF (@inValorDocumentoIdentidad LIKE '%[^0-9]%'
        OR @inTelefono1 = ''
        OR @inTelefono1 LIKE '%[^0-9]%'
        OR @inTelefono2 = ''
        OR @inTelefono2 LIKE '%[^0-9]%'
        OR @inEmail NOT LIKE '%_@_%._%')
    BEGIN
        SET @outResultCode = 50007;
        RETURN;
    END;

    -- ver el porcentaje individual
    IF (@inPorcentaje IS NULL
        OR @inPorcentaje < 0
        OR @inPorcentaje > 100)
    BEGIN
        SET @outResultCode = 50004;
        RETURN;
    END;

    -- ver  acceso a la cuenta
    -- (el administrador puede acceder los datos de cualquier cuenta)
    SELECT @idCuenta = C.Id
    FROM dbo.Cuenta C
    WHERE C.NumeroCuenta = @inNumeroCuenta
      AND (EXISTS (SELECT 1
                   FROM dbo.UsuarioPuedeVer UV
                   WHERE UV.IdCuenta = C.Id
                     AND UV.IdUsuario = @inIdUsuario)
           OR EXISTS (SELECT 1
                      FROM dbo.Usuario U
                      WHERE U.Id = @inIdUsuario
                        AND U.EsAdministrador = 1));

    IF @idCuenta IS NULL
    BEGIN
        SET @outResultCode = 50002;
        RETURN;
    END;

    -- verifica catalogos
    IF NOT EXISTS (
        SELECT 1
        FROM dbo.TipoDocuIdentidad
        WHERE Id = @inIdTipoDocuIdentidad
    )
    OR NOT EXISTS (
        SELECT 1
        FROM dbo.Parentezco
        WHERE Id = @inIdParentezco
    )
    BEGIN
        SET @outResultCode = 50008;
        RETURN;
    END;

    -- Busca si la persona ya existe
    SELECT @idPersona = P.Id
    FROM dbo.Persona P
    WHERE P.ValorDocumentoIdentidad =
          @inValorDocumentoIdentidad;

    -- Verifica consistencia del tipo de documento
    IF @idPersona IS NOT NULL
       AND NOT EXISTS (
           SELECT 1
           FROM dbo.Persona
           WHERE Id = @idPersona
             AND IdTipoDocuIdentidad =
                 @inIdTipoDocuIdentidad
       )
    BEGIN
        SET @outResultCode = 50007;
        RETURN;
    END;

    -- Evita beneficiario activo duplicado
    IF @idPersona IS NOT NULL
       AND EXISTS (
           SELECT 1
           FROM dbo.Beneficiario
           WHERE IdCuenta = @idCuenta
             AND IdPersona = @idPersona
             AND FlagActivo = 1
       )
    BEGIN
        SET @outResultCode = 50005;
        RETURN;
    END;

    -- Calcula cantidad y porcentaje de activos
    SELECT
        @cantidadActivos = COUNT(*),
        @sumaPorcentajes = ISNULL(SUM(Porcentaje), 0)
    FROM dbo.Beneficiario
    WHERE IdCuenta = @idCuenta
      AND FlagActivo = 1;

    -- No permite mas de tres beneficiarios
    IF @cantidadActivos >= 3
    BEGIN
        SET @outResultCode = 50003;
        RETURN;
    END;

    -- No permitite una suma superior a 100
    IF (@sumaPorcentajes + @inPorcentaje) > 100
    BEGIN
        SET @outResultCode = 50009;
        RETURN;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Crea persona si todavia no existe
        IF @idPersona IS NULL
        BEGIN
            INSERT INTO dbo.Persona (
                IdTipoDocuIdentidad,
                ValorDocumentoIdentidad,
                Nombre,
                FechaNacimiento,
                Email
            )
            VALUES (
                @inIdTipoDocuIdentidad,
                @inValorDocumentoIdentidad,
                @inNombre,
                @inFechaNacimiento,
                @inEmail
            );

            SET @idPersona = SCOPE_IDENTITY();

            -- Registra ambos telefonos
            INSERT INTO dbo.Telefono (
                IdPersona,
                Numero
            )
            VALUES
                (@idPersona, @inTelefono1),
                (@idPersona, @inTelefono2);
        END;

        -- Crea la relacion de beneficiario
        INSERT INTO dbo.Beneficiario (
            IdCuenta,
            IdPersona,
            IdParentezco,
            Porcentaje,
            FlagActivo,
            FechaDesactivacion
        )
        VALUES (
            @idCuenta,
            @idPersona,
            @inIdParentezco,
            @inPorcentaje,
            1,
            NULL
        );

        SET @idBeneficiario = SCOPE_IDENTITY();

        -- Preparar JSON con los datos de la relacion
        SET @jsonDespues =
            '{"IdBeneficiario":' +
            CAST(@idBeneficiario AS NVARCHAR(20)) +
            ',"IdCuenta":' +
            CAST(@idCuenta AS NVARCHAR(20)) +
            ',"IdPersona":' +
            CAST(@idPersona AS NVARCHAR(20)) +
            ',"IdParentezco":' +
            CAST(@inIdParentezco AS NVARCHAR(20)) +
            ',"Porcentaje":' +
            CAST(@inPorcentaje AS NVARCHAR(20)) +
            ',"FlagActivo":1,"FechaDesactivacion":null}';

        -- Registra el alta en bitacora
        EXEC dbo.sp_RegistrarBitacora
            @inIdUsuario = @inIdUsuario,
            @inIdTipoOperacion = 3,
            @inJsonDespues = @jsonDespues,
            @outResultCode = @codigoBitacora OUTPUT;

        -- Deshace si falla la auditoria
        IF (@codigoBitacora IS NULL
            OR @codigoBitacora <> 0)
        BEGIN
            ROLLBACK TRANSACTION;
            SET @outResultCode = 50000;
            RETURN;
        END;

        COMMIT TRANSACTION;
        SET @outResultCode = 0;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
        BEGIN
            ROLLBACK TRANSACTION;
        END;

        SET @outResultCode = 50000;
    END CATCH;
END;
GO

----------------------------------------------------------------------------------------------
/*
Ejemplo de ejecucion:

DECLARE @outResultCode INT;

EXEC dbo.sp_ActualizarBeneficiario
    @inIdUsuario = 1,
    @inIdBeneficiario = 1,
    @inNombre = 'Nombre de ejemplo',
    @inIdParentezco = 7,
    @inPorcentaje = 30,
    @outResultCode = @outResultCode OUTPUT;

SELECT @outResultCode AS CodigoResultado;

*/

CREATE OR ALTER PROCEDURE dbo.sp_ActualizarBeneficiario
    @inIdUsuario INT,
    @inIdBeneficiario INT,
    @inNombre VARCHAR(64),
    @inIdParentezco INT,
    @inPorcentaje INT,
    @outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @idCuenta INT;
    DECLARE @idPersona INT;
    DECLARE @nombreAnterior VARCHAR(64);
    DECLARE @parentescoAnterior INT;
    DECLARE @porcentajeAnterior INT;
    DECLARE @sumaOtros INT;
    DECLARE @idTipoOperacion INT;
    DECLARE @codigoBitacora INT;
    DECLARE @jsonAntes NVARCHAR(MAX);
    DECLARE @jsonDespues NVARCHAR(MAX);

    -- ver los datos obligatorios
    IF (@inIdUsuario IS NULL
        OR @inIdBeneficiario IS NULL
        OR @inNombre IS NULL
        OR LTRIM(RTRIM(@inNombre)) = ''
        OR @inIdParentezco IS NULL)
    BEGIN
        SET @outResultCode = 50007;
        RETURN;
    END;

    -- ver porcentaje individual
    IF (@inPorcentaje IS NULL
        OR @inPorcentaje < 0
        OR @inPorcentaje > 100)
    BEGIN
        SET @outResultCode = 50004;
        RETURN;
    END;

    -- Busca beneficiario activo y datos anteriores
    SELECT
        @idCuenta = B.IdCuenta,
        @idPersona = B.IdPersona,
        @nombreAnterior = P.Nombre,
        @parentescoAnterior = B.IdParentezco,
        @porcentajeAnterior = B.Porcentaje
    FROM dbo.Beneficiario B
    INNER JOIN dbo.Persona P
        ON B.IdPersona = P.Id
    WHERE B.Id = @inIdBeneficiario
      AND B.FlagActivo = 1;

    IF @idCuenta IS NULL
    BEGIN
        SET @outResultCode = 50006;
        RETURN;
    END;

    -- ver permiso sobre la cuenta
    IF (NOT EXISTS (
            SELECT 1
            FROM dbo.UsuarioPuedeVer
            WHERE IdUsuario = @inIdUsuario
              AND IdCuenta = @idCuenta
        )
        AND NOT EXISTS (
            SELECT 1
            FROM dbo.Usuario
            WHERE Id = @inIdUsuario
              AND EsAdministrador = 1
        ))
    BEGIN
        SET @outResultCode = 50002;
        RETURN;
    END;

    -- ver parentesco
    IF NOT EXISTS (
        SELECT 1
        FROM dbo.Parentezco
        WHERE Id = @inIdParentezco
    )
    BEGIN
        SET @outResultCode = 50008;
        RETURN;
    END;

    -- Calcula suma excluyendo el beneficiario actual
    SELECT @sumaOtros = ISNULL(SUM(Porcentaje), 0)
    FROM dbo.Beneficiario
    WHERE IdCuenta = @idCuenta
      AND FlagActivo = 1
      AND Id <> @inIdBeneficiario;

    IF (@sumaOtros + @inPorcentaje) > 100
    BEGIN
        SET @outResultCode = 50009;
        RETURN;
    END;

    -- No registra modificaciones si no cambio nada
    IF (@nombreAnterior = @inNombre
        AND @parentescoAnterior = @inIdParentezco
        AND @porcentajeAnterior = @inPorcentaje)
    BEGIN
        SET @outResultCode = 0;
        RETURN;
    END;

    -- Determina tipo de operacion de bitacora
    IF (@nombreAnterior = @inNombre
        AND @parentescoAnterior = @inIdParentezco)
    BEGIN
        SET @idTipoOperacion = 6;
    END
    ELSE
    BEGIN
        SET @idTipoOperacion = 4;
    END;

    -- Prepara estado anterior
    SELECT @jsonAntes = (
        SELECT
            @inIdBeneficiario AS IdBeneficiario,
            @idCuenta AS IdCuenta,
            @idPersona AS IdPersona,
            @nombreAnterior AS Nombre,
            @parentescoAnterior AS IdParentezco,
            @porcentajeAnterior AS Porcentaje,
            CAST(1 AS BIT) AS FlagActivo
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    );

    -- Prepara estado posterior
    SELECT @jsonDespues = (
        SELECT
            @inIdBeneficiario AS IdBeneficiario,
            @idCuenta AS IdCuenta,
            @idPersona AS IdPersona,
            @inNombre AS Nombre,
            @inIdParentezco AS IdParentezco,
            @inPorcentaje AS Porcentaje,
            CAST(1 AS BIT) AS FlagActivo
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    );

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Actualiza nombre si cambio
        UPDATE dbo.Persona
        SET Nombre = @inNombre
        WHERE Id = @idPersona
          AND Nombre <> @inNombre;

        -- Actualiza parentesco y porcentaje si cambiaron
        UPDATE dbo.Beneficiario
        SET IdParentezco = @inIdParentezco,
            Porcentaje = @inPorcentaje
        WHERE Id = @inIdBeneficiario
          AND FlagActivo = 1
          AND (IdParentezco <> @inIdParentezco
               OR Porcentaje <> @inPorcentaje);

        -- Registra modificacion
        EXEC dbo.sp_RegistrarBitacora
            @inIdUsuario = @inIdUsuario,
            @inIdTipoOperacion = @idTipoOperacion,
            @inJsonAntes = @jsonAntes,
            @inJsonDespues = @jsonDespues,
            @outResultCode = @codigoBitacora OUTPUT;

        IF (@codigoBitacora IS NULL
            OR @codigoBitacora <> 0)
        BEGIN
            ROLLBACK TRANSACTION;
            SET @outResultCode = 50000;
            RETURN;
        END;

        COMMIT TRANSACTION;
        SET @outResultCode = 0;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
        BEGIN
            ROLLBACK TRANSACTION;
        END;

        SET @outResultCode = 50000;
    END CATCH;
END;
GO

-----------------------------------------------------------------------------------------------------------
/*
Ejemplo de ejecucion:

DECLARE @outResultCode INT;

EXEC dbo.sp_EliminarBeneficiario
    @inIdUsuario = 1,
    @inIdBeneficiario = 13,
    @outResultCode = @outResultCode OUTPUT;

SELECT @outResultCode AS CodigoResultado;

No ejecutar este ejemplo sobre datos reales.
*/

CREATE OR ALTER PROCEDURE dbo.sp_EliminarBeneficiario
    @inIdUsuario INT,
    @inIdBeneficiario INT,
    @outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @idCuenta INT;
    DECLARE @codigoBitacora INT;
    DECLARE @jsonAntes NVARCHAR(MAX);
    DECLARE @jsonDespues NVARCHAR(MAX);

    -- ver los parametros
    IF (@inIdUsuario IS NULL
        OR @inIdBeneficiario IS NULL)
    BEGIN
        SET @outResultCode = 50007;
        RETURN;
    END;

    -- Busca el beneficiario activo
    SELECT @idCuenta = B.IdCuenta
    FROM dbo.Beneficiario B
    WHERE B.Id = @inIdBeneficiario
      AND B.FlagActivo = 1;

    IF @idCuenta IS NULL
    BEGIN
        SET @outResultCode = 50006;
        RETURN;
    END;

    -- ver permiso del usuario
    IF (NOT EXISTS (
            SELECT 1
            FROM dbo.UsuarioPuedeVer
            WHERE IdUsuario = @inIdUsuario
              AND IdCuenta = @idCuenta
        )
        AND NOT EXISTS (
            SELECT 1
            FROM dbo.Usuario
            WHERE Id = @inIdUsuario
              AND EsAdministrador = 1
        ))
    BEGIN
        SET @outResultCode = 50002;
        RETURN;
    END;

    -- Obtiene el estado anterior
    SELECT @jsonAntes = (
        SELECT
            B.Id AS IdBeneficiario,
            B.IdCuenta,
            B.IdPersona,
            P.Nombre,
            B.IdParentezco,
            B.Porcentaje,
            B.FlagActivo,
            B.FechaDesactivacion
        FROM dbo.Beneficiario B
        INNER JOIN dbo.Persona P
            ON B.IdPersona = P.Id
        WHERE B.Id = @inIdBeneficiario
        FOR JSON PATH, INCLUDE_NULL_VALUES,
            WITHOUT_ARRAY_WRAPPER
    );

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Realiza la baja logica
        UPDATE dbo.Beneficiario
        SET FlagActivo = 0,
            FechaDesactivacion = CAST(SYSDATETIME() AS DATE)
        WHERE Id = @inIdBeneficiario
          AND FlagActivo = 1;

        -- Comprueba que se actualizo una fila
        IF @@ROWCOUNT <> 1
        BEGIN
            ROLLBACK TRANSACTION;
            SET @outResultCode = 50006;
            RETURN;
        END;

        -- Obtiene el estado posterior
        SELECT @jsonDespues = (
            SELECT
                B.Id AS IdBeneficiario,
                B.IdCuenta,
                B.IdPersona,
                P.Nombre,
                B.IdParentezco,
                B.Porcentaje,
                B.FlagActivo,
                B.FechaDesactivacion
            FROM dbo.Beneficiario B
            INNER JOIN dbo.Persona P
                ON B.IdPersona = P.Id
            WHERE B.Id = @inIdBeneficiario
            FOR JSON PATH, INCLUDE_NULL_VALUES,
                WITHOUT_ARRAY_WRAPPER
        );

        -- Registra la baja en bitacora
        EXEC dbo.sp_RegistrarBitacora
            @inIdUsuario = @inIdUsuario,
            @inIdTipoOperacion = 5,
            @inJsonAntes = @jsonAntes,
            @inJsonDespues = @jsonDespues,
            @outResultCode = @codigoBitacora OUTPUT;

        -- Deshace si falla la auditoria
        IF (@codigoBitacora IS NULL
            OR @codigoBitacora <> 0)
        BEGIN
            ROLLBACK TRANSACTION;
            SET @outResultCode = 50000;
            RETURN;
        END;

        COMMIT TRANSACTION;
        SET @outResultCode = 0;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
        BEGIN
            ROLLBACK TRANSACTION;
        END;

        SET @outResultCode = 50000;
    END CATCH;
END;
GO