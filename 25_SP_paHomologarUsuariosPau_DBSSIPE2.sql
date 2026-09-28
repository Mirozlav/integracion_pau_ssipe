/*
================================================================================
 SSIPE-PAU - Alta estandar de usuarios (FASE 2 de 2): homologar en la base SSIPE
 Version 2 (sep-2026): ademas de PauUsuario, registra al usuario en
 integracion.PauDirectorio para que aparezca en Asignar Proyecto sin esperar a
 su primer ingreso por PAU.
================================================================================
 QUE ES
   Procedimiento reutilizable que reemplaza el patron ad-hoc de
   17_homologacion_usuario_prueba_P0025_DBSSIPE2.sql / 20b_pau_usuario_masivo_DBSSIPE2.sql /
   23_pau_usuario_excel_DBSSIPE2.sql. Para dar de alta un lote nuevo NO hay que
   escribir un script nuevo: se llama a integracion.paHomologarUsuariosPau con
   el lote como JSON (la ultima salida del script 24 ya lo arma). El SP:
     1) Resuelve PerfilPauId a partir de CodigoSSO (P0023, P0025, etc.) y falla
        esa fila si el perfil no esta homologado/activo (correr 18/19 antes).
     2) Verifica en DBSSO (misma instancia) si el Documento YA es un usuario
        SSIPE conocido via login.vw_UsuarioInternoSistemaSsipe. Si existe,
        REUTILIZA su IdUsuario/IdArea historicos (no se crea identidad
        duplicada y sus proyectos asignados siguen siendo suyos).
     3) Si el Documento NO existe en el SSO, le asigna un IdUsuario NUNCA antes
        emitido (MAX historico de DBSSO.login.Usuario y de PauUsuario +
        correlativo). Jamas debe reutilizar uno <= ese maximo: heredaria los
        datos de otra persona en toda tabla SSIPE que filtre por IdUsuario.
     4) MERGE en integracion.PauUsuario (idempotente).
     5) NUEVO v2: MERGE en integracion.PauDirectorio con el perfil homologado y
        los datos personales PAU (EntidadPauId, UsuarioPau, Nombres, Apellidos).
        Si la fila no trae esos datos, se homologa igual y el directorio se
        completa en su primer ingreso (columna Directorio del reporte).
   No toca PauPerfil / PauMenu / PauOperacion (scripts 18/19, una vez por perfil).

 DONDE SE EJECUTA
   Base SSIPE del ambiente (DBSSIPE2 en DESA). DBSSO debe estar en la MISMA
   instancia (si no, el acceso DBSSO.login.* falla y haria falta un linked server).

 ATENCION - ARRANCA EN MODO SIMULACION
   @confirmar = 0 (default) hace ROLLBACK y muestra el reporte de lo que HARIA.
================================================================================
*/
IF DB_NAME() <> N'DBSSIPE2'   -- <<< en QA/PROD reemplazar por el nombre de la base SSIPE del ambiente
   OR OBJECT_ID(N'integracion.PauDirectorio', N'U') IS NULL
BEGIN RAISERROR(N'Base incorrecta o falta la infraestructura de integracion: ejecucion cancelada.', 16, 1); SET NOEXEC ON; END
GO
CREATE OR ALTER PROCEDURE integracion.paHomologarUsuariosPau
    @usuariosJson   nvarchar(max),      -- JSON array, ver ejemplo al final
    @sistemaId      int = 2020,         -- SistemaId de SSIPE en el PAU del ambiente
    @revisadoPor    nvarchar(100),      -- documento de quien homologa (auditoria)
    @idAreaPorDefecto int = NULL,       -- IdArea SSIPE para usuarios nuevos cuya fila no trae "IdArea"
    @vigenteDias    int = 90,
    @confirmar      bit = 0
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    IF ISJSON(@usuariosJson) <> 1 THROW 50002, '@usuariosJson invalido.', 1;

    DECLARE @vigenteHasta datetime2 = DATEADD(DAY, @vigenteDias, SYSUTCDATETIME());

    SELECT
        j.Documento, j.NombreCompleto, j.CodigoSSO, j.UsuarioPauId, j.DependenciaPauId, j.IdArea,
        j.EntidadPauId, j.UsuarioPau, j.Nombres, j.ApellidoPaterno, j.ApellidoMaterno, j.AreaNombre
    INTO #lote
    FROM OPENJSON(@usuariosJson)
    WITH (
        Documento nvarchar(100) '$.Documento',
        NombreCompleto nvarchar(200) '$.NombreCompleto',
        CodigoSSO varchar(10) '$.CodigoSSO',
        UsuarioPauId int '$.UsuarioPauId',
        DependenciaPauId int '$.DependenciaPauId',
        IdArea int '$.IdArea',
        EntidadPauId int '$.EntidadPauId',
        UsuarioPau nvarchar(100) '$.UsuarioPau',
        Nombres nvarchar(200) '$.Nombres',
        ApellidoPaterno nvarchar(150) '$.ApellidoPaterno',
        ApellidoMaterno nvarchar(150) '$.ApellidoMaterno',
        AreaNombre nvarchar(300) '$.AreaNombre'
    ) j;

    ALTER TABLE #lote ADD PerfilPauId int NULL, NombrePerfil nvarchar(200) NULL, IdUsuario int NULL,
        IdAreaResuelta int NULL, Origen varchar(20) NULL, Estado varchar(100) NULL, Directorio varchar(60) NULL;

    UPDATE #lote SET Estado = 'FALTA UsuarioPauId/DependenciaPauId (salida del script 24)'
    WHERE ISNULL(UsuarioPauId, 0) <= 0 OR ISNULL(DependenciaPauId, 0) <= 0;

    -- 1) Perfil homologado y activo
    UPDATE l SET PerfilPauId = p.PerfilPauId, NombrePerfil = p.NombrePerfil
    FROM #lote l JOIN integracion.PauPerfil p ON p.SistemaId = @sistemaId AND p.CodigoPerfil = l.CodigoSSO AND p.Activo = 1;
    UPDATE #lote SET Estado = 'PERFIL NO HOMOLOGADO/ACTIVO EN integracion.PauPerfil (correr 18/19 primero)'
    WHERE Estado IS NULL AND PerfilPauId IS NULL;

    -- 2) Reutilizar IdUsuario/IdArea si el documento ya es usuario SSIPE conocido en el SSO
    UPDATE l SET IdUsuario = u.IdUsuario, IdAreaResuelta = u.IdArea, Origen = 'SSO_EXISTENTE'
    FROM #lote l
    CROSS APPLY (SELECT TOP 1 v.IdUsuario, v.IdArea FROM DBSSO.login.vw_UsuarioInternoSistemaSsipe v
                 WHERE v.Documento = l.Documento ORDER BY v.IdUsuario) u
    WHERE l.Estado IS NULL;

    -- 2b) O si ya estaba homologado antes (misma identidad PAU): conservar su IdUsuario.
    --     Sin esto, re-homologar a un usuario nuevo le emitiria otro IdUsuario y perderia sus proyectos asignados.
    UPDATE l SET IdUsuario = pu.IdUsuario, IdAreaResuelta = pu.IdArea, Origen = 'PAU_EXISTENTE'
    FROM #lote l JOIN integracion.PauUsuario pu
      ON pu.SistemaId = @sistemaId AND pu.UsuarioPauId = l.UsuarioPauId AND pu.DependenciaPauId = l.DependenciaPauId
    WHERE l.Estado IS NULL AND l.IdUsuario IS NULL;

    -- 3) Usuarios genuinamente nuevos: IdUsuario nunca antes emitido
    DECLARE @pisoSeguro int = (
        SELECT MAX(v) FROM (
            SELECT MAX(IdUsuario) v FROM DBSSO.login.Usuario
            UNION ALL SELECT MAX(IdUsuario) FROM integracion.PauUsuario
        ) m
    );
    ;WITH nuevos AS (
        SELECT Documento, ROW_NUMBER() OVER (ORDER BY Documento) rn
        FROM #lote WHERE Estado IS NULL AND IdUsuario IS NULL
    )
    UPDATE l SET IdUsuario = @pisoSeguro + n.rn, IdAreaResuelta = ISNULL(l.IdArea, @idAreaPorDefecto), Origen = 'NUEVO'
    FROM #lote l JOIN nuevos n ON n.Documento = l.Documento;

    UPDATE #lote SET Estado = 'FALTA IdArea (nuevo, y @idAreaPorDefecto es NULL: pasar IdArea por fila o el parametro)'
    WHERE Estado IS NULL AND IdAreaResuelta IS NULL;

    -- Nombre de area para el directorio: el del PAU si vino en el lote; si no, el del catalogo de areas (SSO)
    UPDATE l SET AreaNombre = ar.Area
    FROM #lote l JOIN DBSSO.login.Area ar ON ar.IdArea = l.IdAreaResuelta
    WHERE l.Estado IS NULL AND NULLIF(LTRIM(RTRIM(l.AreaNombre)), N'') IS NULL;

    UPDATE #lote SET Directorio = CASE
        WHEN ISNULL(EntidadPauId, 0) > 0 AND NULLIF(LTRIM(RTRIM(UsuarioPau)), N'') IS NOT NULL
             AND NULLIF(LTRIM(RTRIM(Documento)), N'') IS NOT NULL THEN 'REGISTRADO'
        ELSE 'PENDIENTE (se completa en su primer ingreso PAU)' END
    WHERE Estado IS NULL;

    BEGIN TRANSACTION;

    MERGE integracion.PauUsuario AS d
    USING (SELECT * FROM #lote WHERE Estado IS NULL) AS s
        ON d.SistemaId = @sistemaId AND d.UsuarioPauId = s.UsuarioPauId AND d.DependenciaPauId = s.DependenciaPauId
    WHEN MATCHED THEN UPDATE SET IdUsuario = s.IdUsuario, IdArea = s.IdAreaResuelta, UsuarioAuditoria = s.Documento, Activo = 1,
        VigenteHastaUtc = @vigenteHasta, RevisadoPor = @revisadoPor, RevisadoUtc = SYSUTCDATETIME()
    WHEN NOT MATCHED THEN INSERT (SistemaId, UsuarioPauId, DependenciaPauId, IdUsuario, IdArea, UsuarioAuditoria, Activo, VigenteHastaUtc, RevisadoPor)
        VALUES (@sistemaId, s.UsuarioPauId, s.DependenciaPauId, s.IdUsuario, s.IdAreaResuelta, s.Documento, 1, @vigenteHasta, @revisadoPor);

    -- Un solo perfil vigente por usuario/dependencia (misma regla que paRegistrarDirectorioPau)
    UPDATE d SET Activo = 0, SincronizadoUtc = SYSUTCDATETIME()
    FROM integracion.PauDirectorio d
    JOIN #lote l ON l.Estado IS NULL AND l.Directorio = 'REGISTRADO'
     AND d.SistemaId = @sistemaId AND d.UsuarioPauId = l.UsuarioPauId AND d.DependenciaPauId = l.DependenciaPauId
    WHERE d.PerfilPauId <> l.PerfilPauId AND d.Activo = 1;

    MERGE integracion.PauDirectorio WITH (HOLDLOCK) AS d
    USING (SELECT * FROM #lote WHERE Estado IS NULL AND Directorio = 'REGISTRADO') AS s
        ON d.SistemaId = @sistemaId AND d.UsuarioPauId = s.UsuarioPauId
       AND d.DependenciaPauId = s.DependenciaPauId AND d.PerfilPauId = s.PerfilPauId
    WHEN MATCHED THEN UPDATE SET EntidadPauId = s.EntidadPauId, Documento = s.Documento, Usuario = s.UsuarioPau,
        Nombres = ISNULL(s.Nombres, N''), ApellidoPaterno = ISNULL(s.ApellidoPaterno, N''), ApellidoMaterno = ISNULL(s.ApellidoMaterno, N''),
        PerfilNombre = ISNULL(s.NombrePerfil, N''), AreaNombre = ISNULL(s.AreaNombre, N''), Activo = 1, SincronizadoUtc = SYSUTCDATETIME()
    WHEN NOT MATCHED THEN INSERT (SistemaId, UsuarioPauId, DependenciaPauId, PerfilPauId, EntidadPauId, Documento, Usuario,
        Nombres, ApellidoPaterno, ApellidoMaterno, PerfilNombre, AreaNombre, Activo)
        VALUES (@sistemaId, s.UsuarioPauId, s.DependenciaPauId, s.PerfilPauId, s.EntidadPauId, s.Documento, s.UsuarioPau,
        ISNULL(s.Nombres, N''), ISNULL(s.ApellidoPaterno, N''), ISNULL(s.ApellidoMaterno, N''), ISNULL(s.NombrePerfil, N''), ISNULL(s.AreaNombre, N''), 1);

    UPDATE #lote SET Estado = 'HOMOLOGADO' WHERE Estado IS NULL;

    SELECT Documento, NombreCompleto, CodigoSSO, PerfilPauId, UsuarioPauId, DependenciaPauId, IdUsuario,
           IdAreaResuelta AS IdArea, Origen, Estado, Directorio
    FROM #lote ORDER BY Estado, Documento;

    IF @confirmar = 1 BEGIN COMMIT; PRINT 'COMMIT realizado.'; END
    ELSE BEGIN ROLLBACK; PRINT 'Simulacion: ROLLBACK. Revisar Estado por fila y volver a llamar con @confirmar = 1.'; END
END
GO
SET NOEXEC OFF;
GO

/* ---- Ejemplo de uso: pegar el JSON que devuelve la ultima consulta del script 24 ----

EXEC integracion.paHomologarUsuariosPau
    @usuariosJson = N'[
        {"Documento":"00000001","NombreCompleto":"PEREZ GOMEZ, JUAN","CodigoSSO":"P0023","UsuarioPauId":9001,"DependenciaPauId":9101,
         "EntidadPauId":9201,"UsuarioPau":"00000001","Nombres":"JUAN","ApellidoPaterno":"PEREZ","ApellidoMaterno":"GOMEZ"}
    ]',
    @revisadoPor = N'<DNI de quien homologa>',
    @idAreaPorDefecto = 6,   -- ver integracion.paListarArea para elegir un IdArea real y activo
    @confirmar = 0;
*/
