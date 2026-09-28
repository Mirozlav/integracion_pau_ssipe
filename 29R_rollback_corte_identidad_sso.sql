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
IF DB_NAME() <> N'DBSSIPE2'   -- <<< en QA/PROD reemplazar por el nombre de la base SSIPE del ambiente
   OR OBJECT_ID(N'seguimiento.AsignarProyectoFase', N'U') IS NULL
BEGIN RAISERROR(N'Base incorrecta: ejecucion cancelada.', 16, 1); SET NOEXEC ON; END
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
SET NOEXEC OFF;
GO
