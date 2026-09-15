/* Versión única vigente: traduce el contrato oficial PAU al menú plano que consume SSIPE.
   El JSON de entrada ya fue obtenido y normalizado por el backend SSIPE mediante
   Auth/Integration + Auth/GetUsuarioLoginPorIdSis. Sin permisos por defecto. */
IF DB_NAME()<>N'DBSSIPE2' THROW 51001,'Solo DBSSIPE2 DESA.',1;
GO
CREATE OR ALTER PROCEDURE integracion.paResolverSesionPau @parametro nvarchar(max)
AS
BEGIN
 SET NOCOUNT ON;
 IF DB_NAME()<>N'DBSSIPE2' THROW 51001,'Solo DBSSIPE2 DESA.',1;
 IF ISJSON(@parametro)<>1 THROW 50002,'JSON inválido.',1;
 DECLARE @sistema int=TRY_CONVERT(int,JSON_VALUE(@parametro,'$.sistemaId')),
 @pau int=TRY_CONVERT(int,JSON_VALUE(@parametro,'$.usuarioId')),
 @dep int=TRY_CONVERT(int,JSON_VALUE(@parametro,'$.dependenciaId')),
 @perfil int=TRY_CONVERT(int,JSON_VALUE(@parametro,'$.perfilId'));
 IF NOT EXISTS(SELECT 1 FROM integracion.PauUsuario WHERE SistemaId=@sistema AND UsuarioPauId=@pau
   AND DependenciaPauId=@dep AND Activo=1 AND VigenteHastaUtc>SYSUTCDATETIME())
 OR NOT EXISTS(SELECT 1 FROM integracion.PauPerfil WHERE SistemaId=@sistema AND PerfilPauId=@perfil AND Activo=1)
 BEGIN SELECT N'{"estado":0,"resultado":{"codigo":"HOMOLOGACION_PENDIENTE"}}'; RETURN; END;

 -- Recorrer únicamente nodos autorizados por PAU, excluyendo hijos de nodos deshabilitados.
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




