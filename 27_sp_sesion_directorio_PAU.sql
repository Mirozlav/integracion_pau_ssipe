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
IF DB_NAME() <> N'DBSSIPE2'   -- <<< en QA/PROD reemplazar por el nombre de la base SSIPE del ambiente
   OR OBJECT_ID(N'integracion.PauDirectorio', N'U') IS NULL
BEGIN RAISERROR(N'Base incorrecta o falta la infraestructura de integracion: ejecucion cancelada.', 16, 1); SET NOEXEC ON; END
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

SELECT objeto = s.name + '.' + o.name, conCandadoAmbiente = CASE WHEN OBJECT_DEFINITION(o.object_id) LIKE N'%DB_NAME()%' THEN 1 ELSE 0 END
FROM sys.objects o JOIN sys.schemas s ON s.schema_id = o.schema_id
WHERE s.name = N'integracion' AND o.name IN (N'paResolverSesionPau', N'paRegistrarDirectorioPau');
GO
SET NOEXEC OFF;
GO
