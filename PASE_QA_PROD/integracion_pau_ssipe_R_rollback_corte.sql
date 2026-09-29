/*
================================================================================
 integracion_pau_ssipe_R_rollback_corte.sql
================================================================================
 SOLO SI EL PASE FALLA y hay que volver al ingreso por SSO (29R):
   1) back: PauIntegration:Enabled=false y publicar el back y front anteriores;
   2) este script: Asignar Proyecto y los filtros vuelven a leer el SSO.
 Las tablas integracion.* quedan (no afectan al SSO).

 COMO SE EJECUTA (ventana de consultas normal del gestor, conectado a la base SSIPE)
   1. Completar SOLO el bloque "EDITAR SOLO AQUI" (debajo).
   2. Ejecutar todo con CONFIRMAR = 0: simula y revierte. Revisar que termine en
      "SIMULACION OK" y sin errores.
   3. Cambiar CONFIRMAR a 1 y ejecutar de nuevo: termina en "COMMIT REALIZADO".
   Si aparece un error, el script se detiene y revierte todo: no queda nada a medias.
 GENERADO por herramientas/armar_integracion_pau_ssipe.py: no editar fuera del bloque.
================================================================================
*/
SET NOEXEC OFF;
IF @@TRANCOUNT > 0 ROLLBACK;
SET NOCOUNT ON;
IF OBJECT_ID(N'tempdb..#param') IS NOT NULL DROP TABLE #param;
CREATE TABLE #param (Nombre sysname PRIMARY KEY, Valor nvarchar(200) NULL);
-- ============================ EDITAR SOLO AQUI ============================
INSERT #param VALUES (N'BASE_SSIPE', N'DBSSIPE');               -- base SSIPE a la que esta conectado (DESA: DBSSIPE2)
INSERT #param VALUES (N'CONFIRMAR', N'0');                      -- 0 = simular, 1 = aplicar
-- ==========================================================================
GO
IF DB_NAME() <> (SELECT Valor FROM #param WHERE Nombre = N'BASE_SSIPE') OR ISNULL((SELECT Valor FROM #param WHERE Nombre = N'CONFIRMAR'), N'') NOT IN (N'0', N'1')
BEGIN RAISERROR(N'Base conectada distinta de BASE_SSIPE, o CONFIRMAR distinto de 0/1. No se ejecuto nada.', 16, 1); SET NOEXEC ON; END
GO
SET XACT_ABORT ON;
BEGIN TRANSACTION;
DECLARE @confirmarTexto nvarchar(10) = (SELECT Valor FROM #param WHERE Nombre = N'CONFIRMAR');
PRINT CONCAT(N'Inicio en ', @@SERVERNAME, N'.', DB_NAME(), N' | CONFIRMAR=', @confirmarTexto, N' | ', CONVERT(varchar(19), SYSDATETIME(), 120));
GO
-- ############################################################################
-- FUENTE: 29R_rollback_corte_identidad_sso.sql
-- ############################################################################
/*
================================================================================
 29R - Rollback del script 29: SSIPE vuelve a leer identidad/perfiles del SSO
================================================================================
 Restaura la logica previa (identica en DBSSIPE2 y en DBSSIPE3, copia fiel
 de produccion, al 25/09/2026; solo cambian comentarios sin tildes) de
 seguimiento.paListarAsignarProyectoFaseUsuario y deshace el parche de una
 linea en paListarSeguimientoProyecto / Seguimiento / Convenio.
 Usarlo solo junto con el rollback del back (PauIntegration:Enabled=false), ya
 que con la sesion SSO el back no inyecta IdUsuarioSesion.
================================================================================
*/
IF DB_NAME() <> (SELECT Valor FROM #param WHERE Nombre = N'BASE_SSIPE')
   OR OBJECT_ID(N'seguimiento.AsignarProyectoFase', N'U') IS NULL
BEGIN RAISERROR(N'Base incorrecta: ejecucion cancelada.', 16, 1); SET NOEXEC ON; END
GO
IF @@TRANCOUNT <> 1
BEGIN RAISERROR(N'DETENIDO: hubo un error en un bloque anterior. Revise el PRIMER mensaje de error; al final se revierte todo.', 16, 1); SET NOEXEC ON; END
GO

CREATE OR ALTER PROCEDURE [seguimiento].[paListarAsignarProyectoFaseUsuario]
    @parametro NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    IF ISJSON(@parametro) = 0
    BEGIN SELECT '{"estado":0,"mensaje":"Json Incorrecto"}'; RETURN; END

    DECLARE @result       NVARCHAR(MAX);
    DECLARE @tipoFase     NVARCHAR(50);

    -- Codigos de perfil por fase
    DECLARE @codigoObra          NVARCHAR(10) = 'P0023';
    DECLARE @codigoExpediente    NVARCHAR(10) = 'P0028';
    DECLARE @codigoPreinversion  NVARCHAR(10) = 'P0029';

    -- Leer parametro TipoFase del JSON ('obra' | 'expediente' | 'preinversion' | 'administrador')
    SELECT @tipoFase = LOWER(TRIM(JSON_VALUE(@parametro, '$.TipoFase')));

    SELECT @result = (
        SELECT JSON_QUERY(
            COALESCE(
                (
                    SELECT
                        u.IdUsuario,
                        u.IdPersona,
                        u.IdPerfil,
                        u.CodigoPerfil,
                        u.NombrePerfil,
                        u.Usuario,
                        u.Documento,
                        u.Nombres,
                        u.ApellidoPaterno,
                        u.ApellidoMaterno,
                        LTRIM(RTRIM(
                            ISNULL(u.ApellidoPaterno, '') + ' ' +
                            ISNULL(u.ApellidoMaterno, '') + ', ' +
                            ISNULL(u.Nombres, '')
                        )) AS NombreCompleto,
                        u.Area,
                        u.IdArea,
                        ISNULL(asig.CantidadAsignados, 0) AS CantidadProyectosAsignados
                    FROM [DBSSO].[login].[vw_UsuarioInternoSistemaSsipe] u
                    LEFT JOIN (
                        SELECT IdUsuario, COUNT(*) AS CantidadAsignados
                        FROM [seguimiento].[AsignarProyectoFase]
                        WHERE Activo = 1 AND Asignado = 1
                        GROUP BY IdUsuario
                    ) asig ON u.IdUsuario = asig.IdUsuario
                    LEFT JOIN [DBSSO].[login].[vw_PerfilesSistemaSsipe] vp ON u.IdPerfil = vp.IdPerfil
                    WHERE
                        vp.CodigoPerfil IN (@codigoObra, @codigoExpediente, @codigoPreinversion)
                        AND (@tipoFase = 'administrador'
                             OR u.NombrePerfil LIKE '%' + @tipoFase + '%')
                    ORDER BY u.ApellidoPaterno, u.ApellidoMaterno, u.Nombres
                    FOR JSON PATH
                )
            , '[]')
        ) AS Usuarios
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    );

    SELECT ISNULL(@result, '{}');
END
GO
IF @@TRANCOUNT <> 1
BEGIN RAISERROR(N'DETENIDO: hubo un error en un bloque anterior. Revise el PRIMER mensaje de error; al final se revierte todo.', 16, 1); SET NOEXEC ON; END
GO

SET XACT_ABORT ON;
DECLARE @viejo nvarchar(200) = N'integracion.vw_UsuarioSsipe',
        @nuevo nvarchar(200) = N'DBSSO.login.vw_UsuarioInternoSistemaSsipe';
DECLARE @sp TABLE (Nombre sysname);
INSERT @sp VALUES (N'paListarSeguimientoProyecto'), (N'paListarSeguimientoSeguimiento'), (N'paListarSeguimientoConvenio');
DECLARE @reporte TABLE (Procedimiento sysname, Resultado nvarchar(200));
DECLARE @nombre sysname, @def nvarchar(max), @veces int, @pos int;
DECLARE c CURSOR LOCAL FAST_FORWARD FOR SELECT Nombre FROM @sp;
OPEN c; FETCH NEXT FROM c INTO @nombre;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @def = OBJECT_DEFINITION(OBJECT_ID(N'seguimiento.' + @nombre));
    SET @veces = (DATALENGTH(@def) - DATALENGTH(REPLACE(@def, @viejo, N''))) / DATALENGTH(@viejo);
    IF @veces = 0
        INSERT @reporte VALUES (@nombre, N'SIN PARCHE (no se toca)');
    ELSE
    BEGIN
        SET @def = REPLACE(@def, @viejo, @nuevo);
        SET @pos = CHARINDEX(N'CREATE', @def);
        IF LTRIM(REPLACE(REPLACE(SUBSTRING(@def, @pos + 6, 20), CHAR(13), N' '), CHAR(10), N' ')) LIKE N'PROC%'
            SET @def = STUFF(@def, @pos, 6, N'ALTER');
        EXEC sys.sp_executesql @def;
        INSERT @reporte VALUES (@nombre, N'REVERTIDO');
    END
    FETCH NEXT FROM c INTO @nombre;
END
CLOSE c; DEALLOCATE c;
SELECT * FROM @reporte;
GO
IF @@TRANCOUNT <> 1
BEGIN RAISERROR(N'DETENIDO: hubo un error en un bloque anterior. Revise el PRIMER mensaje de error; al final se revierte todo.', 16, 1); SET NOEXEC ON; END
GO
GO
IF @@TRANCOUNT <> 1
BEGIN RAISERROR(N'DETENIDO: hubo un error en un bloque anterior. Revise el PRIMER mensaje de error; al final se revierte todo.', 16, 1); SET NOEXEC ON; END
GO
GO
IF @@TRANCOUNT <> 1
BEGIN RAISERROR(N'DETENIDO: hubo un error en un bloque anterior. Revise el PRIMER mensaje de error; al final se revierte todo.', 16, 1); SET NOEXEC ON; END
GO
-- ############################################################################
-- CIERRE: confirma o revierte todo lo anterior
-- ############################################################################
IF @@TRANCOUNT <> 1
BEGIN RAISERROR(N'DETENIDO: hubo un error en un bloque anterior. Revise el PRIMER mensaje de error; al final se revierte todo.', 16, 1); SET NOEXEC ON; END
GO
IF (SELECT Valor FROM #param WHERE Nombre = N'CONFIRMAR') = N'1' BEGIN COMMIT; PRINT N'COMMIT REALIZADO: cambios aplicados.'; END
ELSE BEGIN ROLLBACK; PRINT N'SIMULACION OK: no se aplico nada. Cambiar CONFIRMAR a 1 y ejecutar de nuevo.'; END
GO
SET NOEXEC OFF;
GO
IF @@TRANCOUNT > 0
BEGIN ROLLBACK; RAISERROR(N'EJECUCION DETENIDA: se revirtio todo. Revise el primer mensaje de error.', 16, 1); END
GO
