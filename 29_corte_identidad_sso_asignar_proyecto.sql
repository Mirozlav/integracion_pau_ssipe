/*
================================================================================
 29 - Corte de identidad SSO -> PAU: Asignar Proyecto y filtros de Seguimiento
================================================================================
 QUE ES
   Reemplaza a 13_cutover_asignar_proyecto_PAU_DBSSIPE2.sql (que solo cubria 1
   de los 4 SPs afectados). Deja a SSIPE sin leer identidad ni perfiles del SSO:

   1) seguimiento.paListarAsignarProyectoFaseUsuario (reescrito)
      - Candidatos a asignar: integracion.vw_UsuarioSsipe (PAU), perfiles
        P0023 / P0028 / P0029 como antes.
      - El "tipo de fase" (administrador / obra / expediente / preinversion) ya
        NO lo manda el front: se calcula aqui con el perfil del usuario de la
        sesion (IdUsuarioSesion, que inyecta el back desde el token PAU) usando
        la misma regla que aplicaba el front sobre NombrePerfil.
      - Misma forma de salida: {"Usuarios":[...]}.

   2) seguimiento.paListarSeguimientoProyecto / paListarSeguimientoSeguimiento /
      paListarSeguimientoConvenio (parche de UNA linea)
      Obtenian el CodigoPerfil del usuario desde DBSSO.login.vw_UsuarioInternoSistemaSsipe
      para decidir si solo ve sus proyectos asignados. Pasan a leerlo de
      integracion.vw_UsuarioSsipe (perfil que otorgo el PAU). Con esto:
        - un usuario nuevo en PAU (sin cuenta en el SSO) ya no queda con perfil
          NULL (que hoy lo dejaba sin ver nada salvo lo asignado),
        - se filtra con el perfil PAU y no con el viejo del SSO,
        - se elimina la ambiguedad de la vista SSO (usuarios con varias filas).
      El parche se aplica sobre la definicion VIGENTE del ambiente (no se
      reescribe el SP completo), por eso sirve igual en DESA, QA y PROD aunque
      otro script del pase haya tocado esos SPs. Exige encontrar la referencia
      exactamente una vez; si no, aborta sin tocar nada. Si ya estaba aplicado,
      lo informa y sigue (idempotente).

   Los otros 4 SPs del modulo (paInsertar / paAnular / paListar /
   paListar...Proyecto) no cambian: solo usan IdUsuario, que sigue siendo el
   historico de SSIPE (lo garantiza la homologacion, script 25).

 PRERREQUISITOS
   27 y 28 aplicados; back SSIPE con la version que inyecta IdUsuario/IdUsuarioSesion
   desde la sesion (rama dev_pau). Rollback: 29R.
================================================================================
*/
IF DB_NAME() <> N'DBSSIPE2'   -- <<< en QA/PROD reemplazar por el nombre de la base SSIPE del ambiente
   OR OBJECT_ID(N'integracion.vw_UsuarioSsipe', N'V') IS NULL
   OR OBJECT_ID(N'seguimiento.AsignarProyectoFase', N'U') IS NULL
BEGIN RAISERROR(N'Base incorrecta o falta integracion.vw_UsuarioSsipe (script 28): ejecucion cancelada.', 16, 1); SET NOEXEC ON; END
GO

CREATE OR ALTER PROCEDURE seguimiento.paListarAsignarProyectoFaseUsuario
    @parametro NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    IF ISJSON(@parametro) = 0
    BEGIN SELECT '{"estado":0,"mensaje":"Json Incorrecto"}'; RETURN; END

    DECLARE @result NVARCHAR(MAX),
            @tipoFase NVARCHAR(50),
            @idUsuarioSesion INT = TRY_CONVERT(INT, JSON_VALUE(@parametro, '$.IdUsuarioSesion')),
            @nombrePerfilSesion NVARCHAR(200);

    DECLARE @codigoObra         VARCHAR(20) = 'P0023',
            @codigoExpediente   VARCHAR(20) = 'P0028',
            @codigoPreinversion VARCHAR(20) = 'P0029';

    SELECT @nombrePerfilSesion = UPPER(NombrePerfil)
    FROM integracion.vw_UsuarioSsipe
    WHERE IdUsuario = @idUsuarioSesion;

    -- Misma regla que usaba el front sobre el NombrePerfil de la sesion, ahora resuelta en el servidor.
    SET @tipoFase = CASE
        WHEN @nombrePerfilSesion LIKE '%ADMINISTRADOR%' THEN 'administrador'
        WHEN @nombrePerfilSesion LIKE '%OBRA%'          THEN 'obra'
        WHEN @nombrePerfilSesion LIKE '%EXPEDIENTE%'    THEN 'expediente'
        WHEN @nombrePerfilSesion LIKE '%PREINVERSION%'  THEN 'preinversion'
    END;

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
                    FROM integracion.vw_UsuarioSsipe u
                    LEFT JOIN (
                        SELECT IdUsuario, COUNT(*) AS CantidadAsignados
                        FROM seguimiento.AsignarProyectoFase
                        WHERE Activo = 1 AND Asignado = 1
                        GROUP BY IdUsuario
                    ) asig ON u.IdUsuario = asig.IdUsuario
                    WHERE u.CodigoPerfil IN (@codigoObra, @codigoExpediente, @codigoPreinversion)
                      AND @tipoFase IS NOT NULL
                      AND (@tipoFase = 'administrador' OR u.NombrePerfil LIKE '%' + @tipoFase + '%')
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

/* ---- Parche de una linea en los 3 SPs de Seguimiento ---- */
SET XACT_ABORT ON;
DECLARE @viejo nvarchar(200) = N'DBSSO.login.vw_UsuarioInternoSistemaSsipe',
        @nuevo nvarchar(200) = N'integracion.vw_UsuarioSsipe';
DECLARE @sp TABLE (Nombre sysname);
INSERT @sp VALUES (N'paListarSeguimientoProyecto'), (N'paListarSeguimientoSeguimiento'), (N'paListarSeguimientoConvenio');
DECLARE @reporte TABLE (Procedimiento sysname, Resultado nvarchar(200));

DECLARE @nombre sysname, @def nvarchar(max), @veces int, @pos int, @resto nvarchar(40);
DECLARE c CURSOR LOCAL FAST_FORWARD FOR SELECT Nombre FROM @sp;
OPEN c; FETCH NEXT FROM c INTO @nombre;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @def = OBJECT_DEFINITION(OBJECT_ID(N'seguimiento.' + @nombre));
    IF @def IS NULL
    BEGIN
        DECLARE @msgNoExiste nvarchar(300) = CONCAT(N'No existe seguimiento.', @nombre, N'.');
        THROW 55001, @msgNoExiste, 1;
    END

    SET @veces = (DATALENGTH(@def) - DATALENGTH(REPLACE(@def, @viejo, N''))) / DATALENGTH(@viejo);
    IF @veces = 0 AND CHARINDEX(@nuevo, @def) > 0
        INSERT @reporte VALUES (@nombre, N'YA ESTABA APLICADO (no se toca)');
    ELSE IF @veces <> 1
    BEGIN
        DECLARE @msgVeces nvarchar(300) = CONCAT(N'seguimiento.', @nombre, N': se esperaba 1 referencia a la vista SSO y hay ', @veces, N'. Revisar a mano; no se aplico nada.');
        THROW 55002, @msgVeces, 1;
    END
    ELSE
    BEGIN
        SET @def = REPLACE(@def, @viejo, @nuevo);
        -- CREATE PROCEDURE -> ALTER PROCEDURE conservando permisos y el resto del texto tal cual
        SET @pos = CHARINDEX(N'CREATE', @def);
        SET @resto = LTRIM(REPLACE(REPLACE(REPLACE(SUBSTRING(@def, @pos + 6, 40), CHAR(13), N' '), CHAR(10), N' '), CHAR(9), N' '));
        IF @pos = 0 OR (@resto NOT LIKE N'PROC%' AND @resto NOT LIKE N'OR ALTER PROC%')
        BEGIN
            DECLARE @msgCab nvarchar(300) = CONCAT(N'seguimiento.', @nombre, N': cabecera CREATE PROCEDURE no reconocida. No se aplico nada.');
            THROW 55003, @msgCab, 1;
        END
        IF @resto LIKE N'PROC%' SET @def = STUFF(@def, @pos, 6, N'ALTER');
        EXEC sys.sp_executesql @def;
        INSERT @reporte VALUES (@nombre, N'APLICADO');
    END
    FETCH NEXT FROM c INTO @nombre;
END
CLOSE c; DEALLOCATE c;

SELECT * FROM @reporte;
GO

/* ---- Verificacion: ningun objeto de SSIPE lee identidad del SSO (salvo la homologacion, que lo usa para reutilizar IdUsuario) ---- */
SELECT Objeto = s.name + '.' + o.name, o.type_desc
FROM sys.objects o JOIN sys.schemas s ON s.schema_id = o.schema_id
WHERE o.type IN ('P', 'V', 'FN', 'IF', 'TF')
  AND (OBJECT_DEFINITION(o.object_id) LIKE N'%vw_UsuarioInternoSistemaSsipe%' OR OBJECT_DEFINITION(o.object_id) LIKE N'%vw_PerfilesSistemaSsipe%')
  AND NOT (s.name = N'integracion' AND o.name = N'paHomologarUsuariosPau');
IF EXISTS (
    SELECT 1 FROM sys.objects o JOIN sys.schemas s ON s.schema_id = o.schema_id
    WHERE o.type IN ('P', 'V', 'FN', 'IF', 'TF')
      AND (OBJECT_DEFINITION(o.object_id) LIKE N'%vw_UsuarioInternoSistemaSsipe%' OR OBJECT_DEFINITION(o.object_id) LIKE N'%vw_PerfilesSistemaSsipe%')
      AND NOT (s.name = N'integracion' AND o.name = N'paHomologarUsuariosPau'))
    THROW 55004, 'Quedan objetos leyendo identidad del SSO (ver resultado anterior).', 1;
PRINT 'Corte de identidad SSO aplicado: SSIPE resuelve usuarios y perfiles solo desde PAU.';
GO
SET NOEXEC OFF;
GO
