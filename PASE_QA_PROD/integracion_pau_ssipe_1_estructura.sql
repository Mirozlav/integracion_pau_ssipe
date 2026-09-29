/*
================================================================================
 integracion_pau_ssipe_1_estructura.sql
================================================================================
 PASE PAU -> SSIPE, PARTE 1 de 2 (estructura). Base SSIPE del ambiente.
   P01 esquema integracion + tablas | 27 SPs de sesion y directorio PAU
   28 vista integracion.vw_UsuarioSsipe + integracion.paListarArea
   25 SP integracion.paHomologarUsuariosPau (v2)
 No necesita ids del PAU ni cambia el comportamiento del back actual.
 Es PRERREQUISITO de DESPLIEGUE_1_DBSSIPE.sql (sus listados leen la vista).

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
-- FUENTE: PASE_QA_PROD/P01_infraestructura_integracion.sql
-- ############################################################################
/*
================================================================================
 P01 - Infraestructura de integracion PAU en la base SSIPE (QA/PROD)
================================================================================
 Consolida sin candados de DESA: 01_tablas_homologacion_DBSSIPE2.sql (PauUsuario,
 PauPerfil, PauMenu, PauOperacion) + la tabla PauDirectorio de
 11_directorio_usuarios_PAU_DBSSIPE2.sql. Mismas definiciones que DBSSIPE2.
 Idempotente: solo crea lo que falte. No carga datos.
================================================================================
*/
IF DB_NAME() <> (SELECT Valor FROM #param WHERE Nombre = N'BASE_SSIPE')
   OR OBJECT_ID(N'seguimiento.AsignarProyectoFase', N'U') IS NULL
BEGIN RAISERROR(N'Base incorrecta: ejecucion cancelada.', 16, 1); SET NOEXEC ON; END
GO
IF @@TRANCOUNT <> 1
BEGIN RAISERROR(N'DETENIDO: hubo un error en un bloque anterior. Revise el PRIMER mensaje de error; al final se revierte todo.', 16, 1); SET NOEXEC ON; END
GO
SET XACT_ABORT ON;
BEGIN TRANSACTION;

IF SCHEMA_ID(N'integracion') IS NULL EXEC(N'CREATE SCHEMA integracion');

IF OBJECT_ID(N'integracion.PauUsuario', N'U') IS NULL
CREATE TABLE integracion.PauUsuario(
 SistemaId int NOT NULL, UsuarioPauId int NOT NULL, DependenciaPauId int NOT NULL,
 IdUsuario int NOT NULL, IdArea int NOT NULL, UsuarioAuditoria nvarchar(100) NOT NULL,
 Activo bit NOT NULL DEFAULT 0, VigenteHastaUtc datetime2 NOT NULL,
 RevisadoPor nvarchar(100) NOT NULL, RevisadoUtc datetime2 NOT NULL DEFAULT SYSUTCDATETIME(),
 PRIMARY KEY(SistemaId, UsuarioPauId, DependenciaPauId), UNIQUE(SistemaId, IdUsuario, DependenciaPauId)
);

IF OBJECT_ID(N'integracion.PauPerfil', N'U') IS NULL
CREATE TABLE integracion.PauPerfil(
 SistemaId int NOT NULL, PerfilPauId int NOT NULL, IdPerfil int NOT NULL,
 CodigoPerfil varchar(20) NOT NULL, NombrePerfil nvarchar(200) NOT NULL,
 Activo bit NOT NULL DEFAULT 0, PRIMARY KEY(SistemaId, PerfilPauId)
);

IF OBJECT_ID(N'integracion.PauMenu', N'U') IS NULL
CREATE TABLE integracion.PauMenu(
 SistemaId int NOT NULL, PerfilPauId int NOT NULL, ModuloPauId nvarchar(100) NOT NULL,
 CodigoMenu varchar(30) NOT NULL, NombreMenu nvarchar(200) NOT NULL,
 Url nvarchar(300) NOT NULL, Icono nvarchar(100) NOT NULL DEFAULT '', Orden int NOT NULL,
 Activo bit NOT NULL DEFAULT 0, PRIMARY KEY(SistemaId, PerfilPauId, ModuloPauId),
 FOREIGN KEY(SistemaId, PerfilPauId) REFERENCES integracion.PauPerfil(SistemaId, PerfilPauId)
);

IF OBJECT_ID(N'integracion.PauOperacion', N'U') IS NULL
CREATE TABLE integracion.PauOperacion(
 SistemaId int NOT NULL, PerfilPauId int NOT NULL, ModuloPauId nvarchar(100) NOT NULL,
 HasClaim varchar(200) NOT NULL, Accion varchar(10) NOT NULL,
 Activo bit NOT NULL DEFAULT 0,
 PRIMARY KEY(SistemaId, PerfilPauId, ModuloPauId, HasClaim),
 CHECK(Accion IN ('leer', 'crear', 'editar', 'eliminar')),
 FOREIGN KEY(SistemaId, PerfilPauId, ModuloPauId) REFERENCES integracion.PauMenu(SistemaId, PerfilPauId, ModuloPauId)
);

IF OBJECT_ID(N'integracion.PauDirectorio', N'U') IS NULL
CREATE TABLE integracion.PauDirectorio(
 SistemaId int NOT NULL,
 UsuarioPauId int NOT NULL,
 DependenciaPauId int NOT NULL,
 PerfilPauId int NOT NULL,
 EntidadPauId int NOT NULL,
 Documento nvarchar(30) NOT NULL,
 Usuario nvarchar(100) NOT NULL,
 Nombres nvarchar(200) NOT NULL,
 ApellidoPaterno nvarchar(150) NOT NULL,
 ApellidoMaterno nvarchar(150) NOT NULL,
 PerfilNombre nvarchar(200) NOT NULL,
 AreaNombre nvarchar(300) NOT NULL,
 Activo bit NOT NULL CONSTRAINT DF_PauDirectorio_Activo DEFAULT 1,
 SincronizadoUtc datetime2 NOT NULL CONSTRAINT DF_PauDirectorio_Sincronizado DEFAULT SYSUTCDATETIME(),
 CONSTRAINT PK_PauDirectorio PRIMARY KEY(SistemaId, UsuarioPauId, DependenciaPauId, PerfilPauId),
 CONSTRAINT FK_PauDirectorio_Usuario FOREIGN KEY(SistemaId, UsuarioPauId, DependenciaPauId)
  REFERENCES integracion.PauUsuario(SistemaId, UsuarioPauId, DependenciaPauId),
 CONSTRAINT FK_PauDirectorio_Perfil FOREIGN KEY(SistemaId, PerfilPauId)
  REFERENCES integracion.PauPerfil(SistemaId, PerfilPauId)
);

COMMIT;
SELECT Tabla = name FROM sys.tables WHERE schema_id = SCHEMA_ID(N'integracion') ORDER BY name;
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
-- FUENTE: 27_sp_sesion_directorio_PAU.sql
-- ############################################################################
/*
================================================================================
 27 - SPs de sesion y directorio PAU, validos para cualquier ambiente
================================================================================
 QUE ES
   Version portable de integracion.paResolverSesionPau (05) y
   integracion.paRegistrarDirectorioPau (11). Ambos traian dentro del cuerpo
   "IF DB_NAME()<>N'DBSSIPE2' THROW", lo que los hace fallar en QA/PROD. Aca se
   quita ese candado del cuerpo (el control de ambiente queda solo en la
   cabecera del script) y se corrige el mensaje con codificacion rota que
   tenia el 11 en DBSSIPE2.
   La logica es identica a la vigente en DBSSIPE2.

 DONDE SE EJECUTA
   Base SSIPE del ambiente: DBSSIPE2 (DESA) o la base SSIPE de QA/PROD.
   Requiere las tablas de integracion (01 + 11, o PASE_QA_PROD/P01).
================================================================================
*/
IF DB_NAME() <> (SELECT Valor FROM #param WHERE Nombre = N'BASE_SSIPE')
   OR OBJECT_ID(N'integracion.PauDirectorio', N'U') IS NULL
BEGIN RAISERROR(N'Base incorrecta o falta la infraestructura de integracion: ejecucion cancelada.', 16, 1); SET NOEXEC ON; END
GO
IF @@TRANCOUNT <> 1
BEGIN RAISERROR(N'DETENIDO: hubo un error en un bloque anterior. Revise el PRIMER mensaje de error; al final se revierte todo.', 16, 1); SET NOEXEC ON; END
GO

CREATE OR ALTER PROCEDURE integracion.paResolverSesionPau @parametro nvarchar(max)
AS
BEGIN
 SET NOCOUNT ON;
 IF ISJSON(@parametro)<>1 THROW 50002,'JSON invalido.',1;
 DECLARE @sistema int=TRY_CONVERT(int,JSON_VALUE(@parametro,'$.sistemaId')),
 @pau int=TRY_CONVERT(int,JSON_VALUE(@parametro,'$.usuarioId')),
 @dep int=TRY_CONVERT(int,JSON_VALUE(@parametro,'$.dependenciaId')),
 @perfil int=TRY_CONVERT(int,JSON_VALUE(@parametro,'$.perfilId'));
 IF NOT EXISTS(SELECT 1 FROM integracion.PauUsuario WHERE SistemaId=@sistema AND UsuarioPauId=@pau
   AND DependenciaPauId=@dep AND Activo=1 AND VigenteHastaUtc>SYSUTCDATETIME())
 OR NOT EXISTS(SELECT 1 FROM integracion.PauPerfil WHERE SistemaId=@sistema AND PerfilPauId=@perfil AND Activo=1)
 BEGIN SELECT N'{"estado":0,"resultado":{"codigo":"HOMOLOGACION_PENDIENTE"}}'; RETURN; END;

 -- Recorrer unicamente nodos autorizados por PAU, excluyendo hijos de nodos deshabilitados.
 CREATE TABLE #nodos(Id nvarchar(100), Hijos nvarchar(max), Nivel int);
 INSERT #nodos SELECT id,children,0 FROM OPENJSON(@parametro,'$.menu')
 WITH(id nvarchar(100),children nvarchar(max) AS JSON,disabled bit) WHERE ISNULL(disabled,0)=0;
 DECLARE @nivel int=0;
 WHILE @nivel<16 AND EXISTS(SELECT 1 FROM #nodos WHERE Nivel=@nivel AND Hijos IS NOT NULL)
 BEGIN
  INSERT #nodos SELECT j.id,j.children,@nivel+1 FROM #nodos n CROSS APPLY OPENJSON(n.Hijos)
  WITH(id nvarchar(100),children nvarchar(max) AS JSON,disabled bit) j
  WHERE n.Nivel=@nivel AND ISNULL(j.disabled,0)=0;
  SET @nivel+=1;
 END;
 IF NOT EXISTS(SELECT 1 FROM integracion.PauMenu m WHERE m.SistemaId=@sistema AND m.PerfilPauId=@perfil
 AND m.Activo=1 AND EXISTS(SELECT 1 FROM #nodos n WHERE n.Id=m.ModuloPauId))
 BEGIN SELECT N'{"estado":0,"resultado":{"codigo":"MENU_NO_HOMOLOGADO"}}'; RETURN; END;

 DECLARE @respuesta nvarchar(max);
 SET @respuesta=(SELECT 1 estado,JSON_QUERY((SELECT u.IdUsuario,u.UsuarioAuditoria Usuario,
 JSON_VALUE(@parametro,'$.nombres') Nombres, JSON_VALUE(@parametro,'$.apellidoPaterno') ApellidoPaterno,
 JSON_VALUE(@parametro,'$.apellidoMaterno') ApellidoMaterno,CAST(0 AS bit) CambioClave,
 JSON_QUERY('[]') Correo,JSON_QUERY('[]') Telefono,
 JSON_QUERY((SELECT 0 IdAcceso,
 JSON_QUERY((SELECT u.IdArea FOR JSON PATH)) area,
 JSON_QUERY((SELECT p.IdPerfil,p.CodigoPerfil,p.NombrePerfil,@sistema IdSistema,0 IdDetallePerfilSistema,
 JSON_QUERY((SELECT ROW_NUMBER() OVER(ORDER BY m.Orden,m.CodigoMenu) IdMenu,0 id_menu_padre,m.CodigoMenu,m.NombreMenu,m.Url,m.Icono,m.Orden,0 Nivel,CAST(0 AS bit) es_componente,0 IdDetallePerfilSistemaMenu,0 IdDetalleSistemaMenu,
 JSON_QUERY((SELECT o.HasClaim,o.HasClaim NombreOperacion,0 IdOperacion,0 IdDetallePerfilOperacion
 FROM integracion.PauOperacion o WHERE o.SistemaId=m.SistemaId AND o.PerfilPauId=m.PerfilPauId
 AND o.ModuloPauId=m.ModuloPauId AND o.Activo=1
 AND (JSON_VALUE(@parametro,'$.accesos.total')='true' OR
 CASE o.Accion WHEN 'leer' THEN JSON_VALUE(@parametro,'$.accesos.leer')
 WHEN 'crear' THEN JSON_VALUE(@parametro,'$.accesos.crear') WHEN 'editar' THEN JSON_VALUE(@parametro,'$.accesos.editar')
 WHEN 'eliminar' THEN JSON_VALUE(@parametro,'$.accesos.eliminar') END='true') FOR JSON PATH)) operacion
 FROM integracion.PauMenu m WHERE m.SistemaId=@sistema AND m.PerfilPauId=@perfil AND m.Activo=1
 AND EXISTS(SELECT 1 FROM #nodos n WHERE n.Id=m.ModuloPauId) ORDER BY m.Orden FOR JSON PATH)) menu
 FROM integracion.PauPerfil p WHERE p.SistemaId=@sistema AND p.PerfilPauId=@perfil AND p.Activo=1 FOR JSON PATH)) perfil
 FOR JSON PATH)) detalle
 FROM integracion.PauUsuario u WHERE u.SistemaId=@sistema AND u.UsuarioPauId=@pau AND u.DependenciaPauId=@dep
 AND u.Activo=1 AND u.VigenteHastaUtc>SYSUTCDATETIME()
 FOR JSON PATH,WITHOUT_ARRAY_WRAPPER)) resultado FOR JSON PATH,WITHOUT_ARRAY_WRAPPER);
 SELECT @respuesta;
END;
GO
IF @@TRANCOUNT <> 1
BEGIN RAISERROR(N'DETENIDO: hubo un error en un bloque anterior. Revise el PRIMER mensaje de error; al final se revierte todo.', 16, 1); SET NOEXEC ON; END
GO

CREATE OR ALTER PROCEDURE integracion.paRegistrarDirectorioPau @parametro nvarchar(max)
AS
BEGIN
 SET NOCOUNT ON;
 SET XACT_ABORT ON;
 IF ISJSON(@parametro)<>1 THROW 52001,'JSON PAU invalido.',1;

 DECLARE @sistema int=TRY_CONVERT(int,JSON_VALUE(@parametro,'$.sistemaId')),
  @usuarioPau int=TRY_CONVERT(int,JSON_VALUE(@parametro,'$.usuarioId')),
  @dependencia int=TRY_CONVERT(int,JSON_VALUE(@parametro,'$.dependenciaId')),
  @perfil int=TRY_CONVERT(int,JSON_VALUE(@parametro,'$.perfilId')),
  @entidad int=TRY_CONVERT(int,JSON_VALUE(@parametro,'$.entidadId')),
  @documento nvarchar(30)=LTRIM(RTRIM(JSON_VALUE(@parametro,'$.documento'))),
  @usuario nvarchar(100)=LTRIM(RTRIM(JSON_VALUE(@parametro,'$.usuario'))),
  @nombres nvarchar(200)=LTRIM(RTRIM(JSON_VALUE(@parametro,'$.nombres'))),
  @paterno nvarchar(150)=LTRIM(RTRIM(JSON_VALUE(@parametro,'$.apellidoPaterno'))),
  @materno nvarchar(150)=LTRIM(RTRIM(JSON_VALUE(@parametro,'$.apellidoMaterno'))),
  @perfilNombre nvarchar(200)=LTRIM(RTRIM(JSON_VALUE(@parametro,'$.perfilNombre'))),
  @areaNombre nvarchar(300)=LTRIM(RTRIM(JSON_VALUE(@parametro,'$.areaNombre')));

 IF @sistema IS NULL OR @usuarioPau IS NULL OR @dependencia IS NULL OR @perfil IS NULL OR @entidad IS NULL
  OR @sistema<=0 OR @usuarioPau<=0 OR @dependencia<=0 OR @perfil<=0 OR @entidad<=0
  OR NULLIF(@documento,N'') IS NULL OR NULLIF(@usuario,N'') IS NULL
  THROW 52002,'Identidad PAU incompleta.',1;

 IF NOT EXISTS(SELECT 1 FROM integracion.PauUsuario WHERE SistemaId=@sistema AND UsuarioPauId=@usuarioPau
   AND DependenciaPauId=@dependencia AND Activo=1 AND VigenteHastaUtc>SYSUTCDATETIME())
  THROW 52003,'Usuario PAU sin homologacion vigente.',1;
 IF NOT EXISTS(SELECT 1 FROM integracion.PauPerfil WHERE SistemaId=@sistema AND PerfilPauId=@perfil AND Activo=1)
  THROW 52004,'Perfil PAU sin homologacion vigente.',1;

 BEGIN TRANSACTION;
 UPDATE integracion.PauDirectorio SET Activo=0,SincronizadoUtc=SYSUTCDATETIME()
 WHERE SistemaId=@sistema AND UsuarioPauId=@usuarioPau AND DependenciaPauId=@dependencia AND PerfilPauId<>@perfil AND Activo=1;

 MERGE integracion.PauDirectorio WITH(HOLDLOCK) AS destino
 USING(SELECT @sistema SistemaId,@usuarioPau UsuarioPauId,@dependencia DependenciaPauId,@perfil PerfilPauId) AS origen
 ON destino.SistemaId=origen.SistemaId AND destino.UsuarioPauId=origen.UsuarioPauId
  AND destino.DependenciaPauId=origen.DependenciaPauId AND destino.PerfilPauId=origen.PerfilPauId
 WHEN MATCHED THEN UPDATE SET EntidadPauId=@entidad,Documento=@documento,Usuario=@usuario,
  Nombres=ISNULL(@nombres,N''),ApellidoPaterno=ISNULL(@paterno,N''),ApellidoMaterno=ISNULL(@materno,N''),
  PerfilNombre=ISNULL(@perfilNombre,N''),AreaNombre=ISNULL(@areaNombre,N''),Activo=1,SincronizadoUtc=SYSUTCDATETIME()
 WHEN NOT MATCHED THEN INSERT(SistemaId,UsuarioPauId,DependenciaPauId,PerfilPauId,EntidadPauId,Documento,Usuario,
  Nombres,ApellidoPaterno,ApellidoMaterno,PerfilNombre,AreaNombre,Activo)
 VALUES(@sistema,@usuarioPau,@dependencia,@perfil,@entidad,@documento,@usuario,ISNULL(@nombres,N''),ISNULL(@paterno,N''),
  ISNULL(@materno,N''),ISNULL(@perfilNombre,N''),ISNULL(@areaNombre,N''),1);
 COMMIT;
END;
GO
IF @@TRANCOUNT <> 1
BEGIN RAISERROR(N'DETENIDO: hubo un error en un bloque anterior. Revise el PRIMER mensaje de error; al final se revierte todo.', 16, 1); SET NOEXEC ON; END
GO

SELECT objeto = s.name + '.' + o.name, conCandadoAmbiente = CASE WHEN OBJECT_DEFINITION(o.object_id) LIKE N'%DB_NAME()%' THEN 1 ELSE 0 END
FROM sys.objects o JOIN sys.schemas s ON s.schema_id = o.schema_id
WHERE s.name = N'integracion' AND o.name IN (N'paResolverSesionPau', N'paRegistrarDirectorioPau');
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
-- FUENTE: 28_identidad_usuario_y_areas.sql
-- ############################################################################
/*
================================================================================
 28 - Identidad de usuario SSIPE desde PAU + catalogo de areas sin desplegar en SSO
================================================================================
 QUE ES
   1) integracion.vw_UsuarioSsipe
      Unica fuente de "quien es quien y con que perfil" para SSIPE. Reemplaza a
      DBSSO.login.vw_UsuarioInternoSistemaSsipe / vw_PerfilesSistemaSsipe en los
      SPs de Asignar Proyecto y Seguimiento (script 29). Toma:
        - IdUsuario / IdArea historicos de SSIPE -> integracion.PauUsuario
        - datos personales y perfil vigente      -> integracion.PauDirectorio
          (lo llena el login PAU y, desde el script 25 v2, tambien la
          homologacion, asi el usuario aparece antes de su primer ingreso)
        - codigo/nombre de perfil SSIPE          -> integracion.PauPerfil
        - nombre del area (solo catalogo)        -> DBSSO.login.Area por IdArea
      Una sola fila por IdUsuario: si hubiera varias dependencias/perfiles
      activos gana el sincronizado mas reciente (el del ultimo ingreso).

   2) integracion.paListarArea
      Reemplaza al BLOQUE 1 de DESPLIEGUE/DESPLIEGUE_2_DBSSO.sql
      (login.paListarLoginArea + login.vw_Area en DBSSO). Misma logica y mismo
      JSON de salida, pero creado en la base SSIPE leyendo las tablas base del
      SSO (que sigue vivo como catalogo). Asi el pase a QA/PROD no necesita
      crear nada en DBSSO. El back (GeneralController.ListarArea) pasa a
      llamarlo por cnx_ssipe.

 DONDE SE EJECUTA
   Base SSIPE del ambiente (DBSSIPE2 en DESA). DBSSO debe estar en la misma
   instancia (asi funciona hoy en DESA y en la copia de produccion DBSSIPE3) y
   el usuario de la aplicacion debe tener SELECT sobre las tablas login.* que
   se leen (lo valida PASE_QA_PROD/P00).
================================================================================
*/
IF DB_NAME() <> (SELECT Valor FROM #param WHERE Nombre = N'BASE_SSIPE')
   OR OBJECT_ID(N'integracion.PauDirectorio', N'U') IS NULL
   OR OBJECT_ID(N'seguimiento.AsignarProyectoFase', N'U') IS NULL
BEGIN RAISERROR(N'Base incorrecta o falta la infraestructura de integracion: ejecucion cancelada.', 16, 1); SET NOEXEC ON; END
GO
IF @@TRANCOUNT <> 1
BEGIN RAISERROR(N'DETENIDO: hubo un error en un bloque anterior. Revise el PRIMER mensaje de error; al final se revierte todo.', 16, 1); SET NOEXEC ON; END
GO

CREATE OR ALTER VIEW integracion.vw_UsuarioSsipe
AS
SELECT x.IdUsuario, x.IdPersona, x.IdPerfil, x.CodigoPerfil, x.NombrePerfil, x.Usuario, x.Documento,
       x.Nombres, x.ApellidoPaterno, x.ApellidoMaterno, x.IdArea, x.Area,
       x.SistemaId, x.UsuarioPauId, x.DependenciaPauId, x.PerfilPauId, x.SincronizadoUtc
FROM (
    SELECT u.IdUsuario, d.EntidadPauId AS IdPersona, p.IdPerfil, p.CodigoPerfil, p.NombrePerfil,
           d.Usuario, d.Documento, d.Nombres, d.ApellidoPaterno, d.ApellidoMaterno,
           u.IdArea,
           -- Nombre del area SSIPE (IdArea) desde el catalogo; si no existe, el nombre de dependencia que mando el PAU
           COALESCE(ar.Area, NULLIF(d.AreaNombre, N'')) AS Area,
           u.SistemaId, u.UsuarioPauId, u.DependenciaPauId, d.PerfilPauId, d.SincronizadoUtc,
           ROW_NUMBER() OVER (PARTITION BY u.IdUsuario ORDER BY d.SincronizadoUtc DESC, d.PerfilPauId DESC) AS rn
    FROM integracion.PauUsuario u
    INNER JOIN integracion.PauDirectorio d
        ON d.SistemaId = u.SistemaId AND d.UsuarioPauId = u.UsuarioPauId
       AND d.DependenciaPauId = u.DependenciaPauId AND d.Activo = 1
    INNER JOIN integracion.PauPerfil p
        ON p.SistemaId = d.SistemaId AND p.PerfilPauId = d.PerfilPauId AND p.Activo = 1
    LEFT JOIN DBSSO.login.Area ar ON ar.IdArea = u.IdArea
    WHERE u.Activo = 1 AND u.VigenteHastaUtc > SYSUTCDATETIME()
) x
WHERE x.rn = 1;
GO
IF @@TRANCOUNT <> 1
BEGIN RAISERROR(N'DETENIDO: hubo un error en un bloque anterior. Revise el PRIMER mensaje de error; al final se revierte todo.', 16, 1); SET NOEXEC ON; END
GO

CREATE OR ALTER PROCEDURE integracion.paListarArea
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @result nvarchar(max);

    SELECT @result = (
        SELECT s.IdDetalleArea, s.IdArea, s.Area, s.Sigla
        FROM (
            SELECT da.IdDetalleArea,
                   ar.IdArea,
                   da.Sigla,
                   ar.Area + CASE WHEN ss.EquipoTrabajo IS NOT NULL THEN ' / ' + ss.EquipoTrabajo ELSE '' END AS Area
            FROM DBSSO.login.DetalleArea da
            INNER JOIN DBSSO.login.Area ar ON da.IdArea = ar.IdArea
            INNER JOIN DBSSO.login.TipoArea ta ON ar.IdTipoArea = ta.IdTipoArea
            LEFT JOIN (
                SELECT det.IdDetalleArea, STRING_AGG(et.EquipoTrabajo, ' / ') AS EquipoTrabajo
                FROM DBSSO.login.DetalleAreaEquipoTrabajo det
                INNER JOIN DBSSO.login.EquipoTrabajo et ON det.IdEquipoTrabajo = et.IdEquipoTrabajo
                WHERE det.Activo = 1
                GROUP BY det.IdDetalleArea
            ) ss ON da.IdDetalleArea = ss.IdDetalleArea
            WHERE da.Activo = 1
              AND ta.CodigoTipoArea IN ('TA0001', 'TA0002', 'TA0003')   -- DIRECCION, OFICINA, GERENCIA
        ) s
        ORDER BY s.Area
        FOR JSON PATH
    );

    SELECT ISNULL(@result, '[]');
END;
GO
IF @@TRANCOUNT <> 1
BEGIN RAISERROR(N'DETENIDO: hubo un error en un bloque anterior. Revise el PRIMER mensaje de error; al final se revierte todo.', 16, 1); SET NOEXEC ON; END
GO

SELECT objeto = N'integracion.vw_UsuarioSsipe', filas = (SELECT COUNT(*) FROM integracion.vw_UsuarioSsipe);
EXEC integracion.paListarArea;
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
-- FUENTE: 25_SP_paHomologarUsuariosPau_DBSSIPE2.sql
-- ############################################################################
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
IF DB_NAME() <> (SELECT Valor FROM #param WHERE Nombre = N'BASE_SSIPE')
   OR OBJECT_ID(N'integracion.PauDirectorio', N'U') IS NULL
BEGIN RAISERROR(N'Base incorrecta o falta la infraestructura de integracion: ejecucion cancelada.', 16, 1); SET NOEXEC ON; END
GO
IF @@TRANCOUNT <> 1
BEGIN RAISERROR(N'DETENIDO: hubo un error en un bloque anterior. Revise el PRIMER mensaje de error; al final se revierte todo.', 16, 1); SET NOEXEC ON; END
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

    IF @confirmar = 1 BEGIN COMMIT; PRINT 'Bloque OK (se confirma o revierte al final segun CONFIRMAR).'; END
    ELSE BEGIN ROLLBACK; PRINT 'Simulacion: ROLLBACK. Revisar Estado por fila y volver a llamar con @confirmar = 1.'; END
END
GO
IF @@TRANCOUNT <> 1
BEGIN RAISERROR(N'DETENIDO: hubo un error en un bloque anterior. Revise el PRIMER mensaje de error; al final se revierte todo.', 16, 1); SET NOEXEC ON; END
GO
GO
IF @@TRANCOUNT <> 1
BEGIN RAISERROR(N'DETENIDO: hubo un error en un bloque anterior. Revise el PRIMER mensaje de error; al final se revierte todo.', 16, 1); SET NOEXEC ON; END
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
GO
IF @@TRANCOUNT <> 1
BEGIN RAISERROR(N'DETENIDO: hubo un error en un bloque anterior. Revise el PRIMER mensaje de error; al final se revierte todo.', 16, 1); SET NOEXEC ON; END
GO
-- ############################################################################
-- VERIFICACION PARTE 1
-- ############################################################################
SELECT Verificacion = N'Parte 1', Objeto = s.name + N'.' + o.name, o.type_desc
FROM sys.objects o JOIN sys.schemas s ON s.schema_id = o.schema_id
WHERE s.name = N'integracion' AND o.type IN ('U', 'V', 'P') ORDER BY o.type, o.name;
IF (SELECT COUNT(*) FROM sys.objects o WHERE o.schema_id = SCHEMA_ID(N'integracion')
      AND o.name IN (N'PauUsuario', N'PauPerfil', N'PauMenu', N'PauOperacion', N'PauDirectorio', N'vw_UsuarioSsipe',
                     N'paListarArea', N'paResolverSesionPau', N'paRegistrarDirectorioPau', N'paHomologarUsuariosPau')) <> 10
BEGIN RAISERROR(N'Parte 1 incompleta: faltan objetos de integracion.', 16, 1); SET NOEXEC ON; END
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
