/* Rollback del corte 13: restaura temporalmente las vistas SSO del módulo Asignar Proyecto. */
IF DB_NAME()<>N'DBSSIPE2' THROW 51001,'Solo DBSSIPE2 DESA.',1;
GO
CREATE OR ALTER PROCEDURE seguimiento.paListarAsignarProyectoFaseUsuario @parametro nvarchar(max)
AS
BEGIN
 SET NOCOUNT ON;
 IF ISJSON(@parametro)=0 BEGIN SELECT '{"estado":0,"mensaje":"Json Incorrecto"}'; RETURN; END;
 DECLARE @result nvarchar(max),@tipoFase nvarchar(50),@codigoObra nvarchar(10)='P0023',@codigoExpediente nvarchar(10)='P0028',@codigoPreinversion nvarchar(10)='P0029';
 SELECT @tipoFase=LOWER(TRIM(JSON_VALUE(@parametro,'$.TipoFase')));
 SELECT @result=(SELECT JSON_QUERY(COALESCE((SELECT u.IdUsuario,u.IdPersona,u.IdPerfil,u.CodigoPerfil,u.NombrePerfil,
  u.Usuario,u.Documento,u.Nombres,u.ApellidoPaterno,u.ApellidoMaterno,
  LTRIM(RTRIM(ISNULL(u.ApellidoPaterno,'')+' '+ISNULL(u.ApellidoMaterno,'')+', '+ISNULL(u.Nombres,''))) NombreCompleto,
  u.Area,u.IdArea,ISNULL(a.CantidadAsignados,0) CantidadProyectosAsignados
  FROM DBSSO.login.vw_UsuarioInternoSistemaSsipe u
  LEFT JOIN(SELECT IdUsuario,COUNT(*) CantidadAsignados FROM seguimiento.AsignarProyectoFase WHERE Activo=1 AND Asignado=1 GROUP BY IdUsuario)a ON u.IdUsuario=a.IdUsuario
  LEFT JOIN DBSSO.login.vw_PerfilesSistemaSsipe p ON u.IdPerfil=p.IdPerfil
  WHERE p.CodigoPerfil IN(@codigoObra,@codigoExpediente,@codigoPreinversion)
   AND(@tipoFase='administrador' OR u.NombrePerfil LIKE '%'+@tipoFase+'%')
  ORDER BY u.ApellidoPaterno,u.ApellidoMaterno,u.Nombres FOR JSON PATH),'[]')) Usuarios FOR JSON PATH,WITHOUT_ARRAY_WRAPPER);
 SELECT ISNULL(@result,'{}');
END;
