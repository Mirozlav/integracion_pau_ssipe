/*
================================================================================
 integracion_pau_ssipe_R_rollback_corte.sql
================================================================================
 ROLLBACK del corte (29R). Solo si hay que volver al ingreso por SSO:
   1) back: PauIntegration:Enabled=false y publicar el back anterior;
   2) este script: Asignar Proyecto y los filtros vuelven a leer el SSO.
 Las tablas integracion.* quedan (no afectan al SSO).

 COMO SE EJECUTA
   - Modo SQLCMD obligatorio (SSMS: menu Consulta > Modo SQLCMD; o sqlcmd -b -I).
     Sin SQLCMD no ejecuta nada.
   - Conectado a la base SSIPE del ambiente, con una cuenta con permisos DDL.
   - Primero con CONFIRMAR "0" (simula todo y hace ROLLBACK). Revisar la salida.
     Luego CONFIRMAR "1" en una conexion nueva.
   - Corta ante el primer error; si corta, la transaccion se revierte completa.
 GENERADO por herramientas/armar_integracion_pau_ssipe.py: no editar a mano,
 salvo el bloque :setvar de abajo.
================================================================================
*/
:on error exit
:setvar __MODO_SQLCMD "SI"         -- no tocar
:setvar BASE_SSIPE "DBSSIPE"       -- base SSIPE del ambiente
:setvar CONFIRMAR "0"              -- 0 = simular, 1 = aplicar
GO
IF N'$(__MODO_SQLCMD)' <> N'SI'
BEGIN RAISERROR(N'Ejecutar en modo SQLCMD (SSMS: Consulta > Modo SQLCMD). No se ejecuto nada.', 16, 1); SET NOEXEC ON; END
GO
IF DB_NAME() <> N'$(BASE_SSIPE)' OR N'$(CONFIRMAR)' NOT IN (N'0', N'1')
BEGIN RAISERROR(N'Base distinta de BASE_SSIPE o CONFIRMAR distinto de 0/1: ejecucion cancelada.', 16, 1); SET NOEXEC ON; END
GO
SET XACT_ABORT ON;
BEGIN TRANSACTION;
PRINT CONCAT(N'Inicio en ', @@SERVERNAME, N'.', DB_NAME(), N' | CONFIRMAR=$(CONFIRMAR) | ', CONVERT(varchar(19), SYSDATETIME(), 120));
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
IF DB_NAME() <> N'$(BASE_SSIPE)'
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
GO
GO
-- ############################################################################
-- CIERRE: confirma o revierte todo lo anterior
-- ############################################################################
IF @@TRANCOUNT <> 1
BEGIN RAISERROR(N'Transaccion exterior inconsistente: se revierte.', 16, 1); IF @@TRANCOUNT > 0 ROLLBACK; SET NOEXEC ON; END
GO
IF $(CONFIRMAR) = 1 BEGIN COMMIT; PRINT N'COMMIT REALIZADO.'; END
ELSE BEGIN ROLLBACK; PRINT N'SIMULACION: ROLLBACK de todo. Revisar la salida y repetir con CONFIRMAR "1" en una conexion nueva.'; END
GO
SET NOEXEC OFF;
GO
