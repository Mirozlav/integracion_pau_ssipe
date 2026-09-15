/* CORTE CONTROLADO: elimina la dependencia de DBSSO del listado Asignar Proyecto.
   No ejecutar mientras el directorio PAU esté vacío o incompleto. Ver script 13_rollback. */
SET XACT_ABORT ON;
IF DB_NAME()<>N'DBSSIPE2' THROW 51001,'Solo DBSSIPE2 DESA.',1;
IF CONVERT(nvarchar(128),SERVERPROPERTY('MachineName'))<>N'PVDDEV-BD07' THROW 51002,'Solo servidor DESA PVDDEV-BD07.',1;
IF NOT EXISTS(SELECT 1 FROM integracion.PauDirectorio WHERE Activo=1) THROW 54001,'Directorio PAU vacío: corte cancelado.',1;
IF EXISTS(SELECT 1 FROM integracion.PauUsuario u WHERE u.Activo=1 AND u.VigenteHastaUtc>SYSUTCDATETIME()
 AND NOT EXISTS(SELECT 1 FROM integracion.PauDirectorio d WHERE d.SistemaId=u.SistemaId AND d.UsuarioPauId=u.UsuarioPauId
 AND d.DependenciaPauId=u.DependenciaPauId AND d.Activo=1)) THROW 54002,'Hay usuarios homologados sin directorio PAU.',1;
GO
CREATE OR ALTER PROCEDURE seguimiento.paListarAsignarProyectoFaseUsuario @parametro nvarchar(max)
AS
BEGIN
 SET NOCOUNT ON;
 IF ISJSON(@parametro)=0 BEGIN SELECT '{"estado":0,"mensaje":"Json Incorrecto"}'; RETURN; END;
 DECLARE @result nvarchar(max),@tipoFase nvarchar(50)=LOWER(TRIM(JSON_VALUE(@parametro,'$.TipoFase')));
 SELECT @result=(SELECT JSON_QUERY(COALESCE((
  SELECT u.IdUsuario,d.EntidadPauId IdPersona,p.IdPerfil,p.CodigoPerfil,p.NombrePerfil,d.Usuario,d.Documento,
   d.Nombres,d.ApellidoPaterno,d.ApellidoMaterno,
   LTRIM(RTRIM(ISNULL(d.ApellidoPaterno,'')+' '+ISNULL(d.ApellidoMaterno,'')+', '+ISNULL(d.Nombres,''))) NombreCompleto,
   d.AreaNombre Area,u.IdArea,ISNULL(a.CantidadAsignados,0) CantidadProyectosAsignados
  FROM integracion.PauDirectorio d
  INNER JOIN integracion.PauUsuario u ON u.SistemaId=d.SistemaId AND u.UsuarioPauId=d.UsuarioPauId
   AND u.DependenciaPauId=d.DependenciaPauId AND u.Activo=1 AND u.VigenteHastaUtc>SYSUTCDATETIME()
  INNER JOIN integracion.PauPerfil p ON p.SistemaId=d.SistemaId AND p.PerfilPauId=d.PerfilPauId AND p.Activo=1
  LEFT JOIN(SELECT IdUsuario,COUNT(*) CantidadAsignados FROM seguimiento.AsignarProyectoFase
   WHERE Activo=1 AND Asignado=1 GROUP BY IdUsuario)a ON a.IdUsuario=u.IdUsuario
  WHERE d.Activo=1 AND p.CodigoPerfil IN('P0023','P0028','P0029')
   AND(@tipoFase='administrador' OR p.NombrePerfil LIKE '%'+@tipoFase+'%')
  ORDER BY d.ApellidoPaterno,d.ApellidoMaterno,d.Nombres FOR JSON PATH),'[]')) Usuarios
  FOR JSON PATH,WITHOUT_ARRAY_WRAPPER);
 SELECT ISNULL(@result,'{}');
END;
GO
IF OBJECT_DEFINITION(OBJECT_ID(N'seguimiento.paListarAsignarProyectoFaseUsuario')) LIKE N'%DBSSO%'
 THROW 54003,'El procedimiento aún contiene una referencia DBSSO.',1;
