/*
================================================================================
 SSIPE-PAU - Alta estandar de usuarios (FASE 2 de 2): homologar en DBSSIPE2
================================================================================
 QUE ES
   Procedimiento reutilizable que reemplaza el patron ad-hoc de
   17_homologacion_usuario_prueba_P0025_DBSSIPE2.sql / 20b_pau_usuario_masivo_DBSSIPE2.sql /
   23_pau_usuario_excel_DBSSIPE2.sql. A partir de aca, para dar de alta un lote
   nuevo de usuarios NO hay que escribir un script nuevo: se llama a
   integracion.paHomologarUsuariosPau con el lote como JSON (ver ejemplo de uso
   al final de este archivo). El procedimiento:
     1) Resuelve PerfilPauId a partir de CodigoSSO (P0023, P0025, etc.) y falla
        esa fila si el perfil no esta homologado/activo (correr 18/19 antes).
     2) Verifica en DBSSO (misma instancia, sin linked server: DBSSO y DBSSIPE2
        viven en PVDDEV-BD07\ARTEMISA36) si el Documento YA es un usuario SSIPE
        conocido via login.vw_UsuarioInternoSistemaSsipe. Si existe, REUTILIZA
        su IdUsuario/IdArea historicos (no se crea una identidad duplicada).
        Esto es la verificacion "usuarios de SSIPE en SGA/SSO" pedida: cubre a
        cualquiera que ya haya tenido perfil SSIPE por el SSO clasico.
     3) Si el Documento NO existe en ese SSO (usuario genuinamente nuevo, nunca
        tuvo cuenta SSIPE), le asigna un IdUsuario nuevo NUNCA antes emitido en
        DBSSO.login.Usuario (MAX historico + correlativo dentro del lote). Este
        numero jamas debe reutilizar uno <= ese maximo: si coincidiera con el
        IdUsuario de un empleado real (activo o de baja), el usuario nuevo
        heredaria silenciosamente sus datos en cualquier tabla de SSIPE que
        filtre por IdUsuario. IdArea: usa @idAreaPorDefecto salvo que la fila
        traiga su propio "IdArea" en el JSON.
     4) Hace MERGE en integracion.PauUsuario (upsert idempotente) y devuelve un
        reporte fila por fila.
   No toca integracion.PauPerfil / PauMenu / PauOperacion (eso son los scripts
   18/19, que se corren una sola vez por perfil nuevo, no por usuario).

 DONDE SE EJECUTA
   DBSSIPE2 en PVDDEV-BD07\ARTEMISA36 (ambiente DESA). Para QA/produccion:
   mismo procedimiento, pero crearlo en la base SSIPE de ese ambiente y
   verificar que DBSSO exista en la MISMA instancia (si en QA/PROD estuviera en
   un servidor distinto, el acceso de tres partes DBSSO.login.* fallaria y
   habria que resolverlo con un linked server antes de usar este SP ahi).

 USUARIO DE CONEXION
   Requiere permiso de SELECT sobre DBSSO (misma instancia) ademas de
   INSERT/UPDATE sobre integracion.* en DBSSIPE2.

 ATENCION - ARRANCA EN MODO SIMULACION
   @confirmar = 0 (default) corre todo en una transaccion y hace ROLLBACK,
   mostrando el reporte de lo que HARIA. Revisar la columna Estado de cada fila
   y recien entonces volver a llamar con @confirmar = 1.
================================================================================
*/
IF DB_NAME() <> N'DBSSIPE2' THROW 51001, 'Seleccionar DBSSIPE2 DESA (o el equivalente del ambiente, ver encabezado).', 1;
GO
CREATE OR ALTER PROCEDURE integracion.paHomologarUsuariosPau
    @usuariosJson   nvarchar(max),      -- JSON array: [{"Documento":"41080091","NombreCompleto":"LINARES ACOSTA, ABY","CodigoSSO":"P0023","UsuarioPauId":4610,"DependenciaPauId":7920,"IdArea":null}]
    @sistemaId      int = 2020,
    @revisadoPor    nvarchar(100),      -- documento de quien homologa (auditoria)
    @idAreaPorDefecto int = NULL,       -- IdArea de DBSSO a usar cuando el usuario es nuevo y la fila no trae "IdArea" propio
    @vigenteDias    int = 90,
    @confirmar      bit = 0
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    IF DB_NAME() <> N'DBSSIPE2' THROW 51001, 'Solo DBSSIPE2 (o el equivalente del ambiente).', 1;
    IF ISJSON(@usuariosJson) <> 1 THROW 50002, '@usuariosJson invalido.', 1;

    DECLARE @vigenteHasta datetime2 = DATEADD(DAY, @vigenteDias, SYSUTCDATETIME());

    SELECT
        j.Documento, j.NombreCompleto, j.CodigoSSO, j.UsuarioPauId, j.DependenciaPauId, j.IdArea
    INTO #lote
    FROM OPENJSON(@usuariosJson)
    WITH (
        Documento nvarchar(100) '$.Documento',
        NombreCompleto nvarchar(200) '$.NombreCompleto',
        CodigoSSO varchar(10) '$.CodigoSSO',
        UsuarioPauId int '$.UsuarioPauId',
        DependenciaPauId int '$.DependenciaPauId',
        IdArea int '$.IdArea'
    ) j;

    ALTER TABLE #lote ADD PerfilPauId int NULL, IdUsuario int NULL, IdAreaResuelta int NULL, Origen varchar(20) NULL, Estado varchar(80) NULL;

    -- 1) Resolver PerfilPauId homologado y activo
    UPDATE l SET PerfilPauId = p.PerfilPauId
    FROM #lote l JOIN integracion.PauPerfil p ON p.SistemaId = @sistemaId AND p.CodigoPerfil = l.CodigoSSO AND p.Activo = 1;
    UPDATE #lote SET Estado = 'PERFIL NO HOMOLOGADO/ACTIVO EN integracion.PauPerfil (correr 18/19 primero)' WHERE PerfilPauId IS NULL;

    -- 2) Reutilizar IdUsuario/IdArea si el documento ya es un usuario SSIPE conocido en el SSO (misma instancia, sin linked server)
    UPDATE l SET IdUsuario = u.IdUsuario, IdAreaResuelta = u.IdArea, Origen = 'SSO_EXISTENTE'
    FROM #lote l JOIN DBSSO.login.vw_UsuarioInternoSistemaSsipe u ON u.Documento = l.Documento
    WHERE l.Estado IS NULL;

    -- 3) Usuarios genuinamente nuevos (sin cuenta SSIPE historica en el SSO): IdUsuario nunca antes emitido
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
    WHERE Estado IS NULL AND Origen = 'NUEVO' AND IdAreaResuelta IS NULL;

    BEGIN TRANSACTION;

    MERGE integracion.PauUsuario AS d
    USING (SELECT * FROM #lote WHERE Estado IS NULL) AS s
        ON d.SistemaId = @sistemaId AND d.UsuarioPauId = s.UsuarioPauId AND d.DependenciaPauId = s.DependenciaPauId
    WHEN MATCHED THEN UPDATE SET IdUsuario = s.IdUsuario, IdArea = s.IdAreaResuelta, Activo = 1, VigenteHastaUtc = @vigenteHasta, RevisadoPor = @revisadoPor, RevisadoUtc = SYSUTCDATETIME()
    WHEN NOT MATCHED THEN INSERT (SistemaId, UsuarioPauId, DependenciaPauId, IdUsuario, IdArea, UsuarioAuditoria, Activo, VigenteHastaUtc, RevisadoPor)
        VALUES (@sistemaId, s.UsuarioPauId, s.DependenciaPauId, s.IdUsuario, s.IdAreaResuelta, s.Documento, 1, @vigenteHasta, @revisadoPor);

    UPDATE #lote SET Estado = 'HOMOLOGADO' WHERE Estado IS NULL;

    SELECT Documento, NombreCompleto, CodigoSSO, PerfilPauId, UsuarioPauId, DependenciaPauId, IdUsuario, IdAreaResuelta AS IdArea, Origen, Estado
    FROM #lote ORDER BY Estado, Documento;

    IF @confirmar = 1 BEGIN COMMIT; PRINT 'COMMIT realizado.'; END
    ELSE BEGIN ROLLBACK; PRINT 'Simulacion: ROLLBACK. Revisar Estado por fila y volver a llamar con @confirmar = 1.'; END
END
GO

/* ---- Ejemplo de uso (rellenar UsuarioPauId/DependenciaPauId con la salida de 24_ALTA_ESTANDAR_asignar_perfil_PAU.sql) ----

EXEC integracion.paHomologarUsuariosPau
    @usuariosJson = N'[
        {"Documento":"41080091","NombreCompleto":"LINARES ACOSTA, ABY","CodigoSSO":"P0023","UsuarioPauId":4610,"DependenciaPauId":7920},
        {"Documento":"72194989","NombreCompleto":"HUAYLLAS BARZOLA, LUSIANA RUZALIZ","CodigoSSO":"P0025","UsuarioPauId":4611,"DependenciaPauId":7921}
    ]',
    @revisadoPor = N'42910203',
    @idAreaPorDefecto = 6,   -- ver script 16 seccion 'Area' para elegir un IdArea real y activo en SSIPE
    @confirmar = 0;
*/
