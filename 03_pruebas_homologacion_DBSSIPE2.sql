/* Pruebas con identidades ficticias, siempre ROLLBACK. No modifican asignaciones.
   Ejecutar después de 01 y 05. Toda aserción fallida lanza error y revierte. */
SET XACT_ABORT ON;
IF DB_NAME()<>N'DBSSIPE2' THROW 51001,'Solo DBSSIPE2 DESA.',1;
BEGIN TRY
 BEGIN TRANSACTION;
 DECLARE @s int=2000000001;
 IF EXISTS(SELECT 1 FROM integracion.PauUsuario WHERE SistemaId=@s)
 OR EXISTS(SELECT 1 FROM integracion.PauPerfil WHERE SistemaId=@s)
 THROW 51002,'El identificador de prueba ya está ocupado.',1;
 DECLARE @resultado TABLE(JsonResultado nvarchar(max));
 DECLARE @pruebas TABLE(Prueba nvarchar(150),Estado varchar(10));
 DECLARE @json nvarchar(max)=N'{"version":2,"sistemaId":2000000001,"usuarioId":2000000002,"dependenciaId":2000000003,"perfilId":2000000004,"nombres":"PRUEBA","apellidoPaterno":"REVERTIDA","accesos":{"total":false,"leer":true,"crear":false,"editar":false,"eliminar":false},"menu":[{"id":"modulo-prueba","disabled":false}]}';

 INSERT @resultado EXEC integracion.paResolverSesionPau @json;
 IF (SELECT JSON_VALUE(JsonResultado,'$.estado') FROM @resultado) <> '0' THROW 51100,'Debe negar usuario sin homologación.',1;
 INSERT @pruebas VALUES('Usuario no homologado: denegado','OK'); DELETE @resultado;
 INSERT integracion.PauUsuario(SistemaId,UsuarioPauId,DependenciaPauId,IdUsuario,IdArea,UsuarioAuditoria,Activo,VigenteHastaUtc,RevisadoPor)
 VALUES(@s,2000000002,2000000003,2000000005,2000000006,'PRUEBA_NO_REAL',1,DATEADD(hour,1,SYSUTCDATETIME()),'TEST_ROLLBACK');
 INSERT integracion.PauPerfil VALUES(@s,2000000004,2000000007,'TEST','PERFIL PRUEBA',1);
 INSERT integracion.PauMenu VALUES(@s,2000000004,'modulo-prueba','TEST','Prueba','/seguimiento','',1,1);
 INSERT integracion.PauOperacion VALUES(@s,2000000004,'modulo-prueba','TEST_LEER','leer',1),(@s,2000000004,'modulo-prueba','TEST_CREAR','crear',1);

 INSERT @resultado EXEC integracion.paResolverSesionPau @json;
 IF (SELECT JSON_VALUE(JsonResultado,'$.estado') FROM @resultado) <> '1' THROW 51101,'Debe permitir homologación válida.',1;
 IF (SELECT JSON_VALUE(JsonResultado,'$.resultado.IdUsuario') FROM @resultado) <> '2000000005' THROW 51102,'Debe conservar ID histórico, no ID PAU.',1;
 IF NOT EXISTS(SELECT 1 FROM @resultado WHERE JsonResultado LIKE '%TEST_LEER%' AND JsonResultado NOT LIKE '%TEST_CREAR%') THROW 51103,'Debe limitar claims a acciones concedidas.',1;
 INSERT @pruebas VALUES('Identidad histórica conservada','OK'),('Claim leer presente, crear ausente','OK'); DELETE @resultado;

 DECLARE @otra nvarchar(max)=JSON_MODIFY(@json,'$.sistemaId',2000000099);
 INSERT @resultado EXEC integracion.paResolverSesionPau @otra;
 IF (SELECT JSON_VALUE(JsonResultado,'$.estado') FROM @resultado) <> '0' THROW 51104,'Debe negar otro sistema.',1;
 INSERT @pruebas VALUES('Sistema distinto: denegado','OK'); DELETE @resultado;
 SET @otra=JSON_MODIFY(@json,'$.dependenciaId',2000000099);
 INSERT @resultado EXEC integracion.paResolverSesionPau @otra;
 IF (SELECT JSON_VALUE(JsonResultado,'$.estado') FROM @resultado) <> '0' THROW 51105,'Debe negar otra dependencia.',1;
 INSERT @pruebas VALUES('Dependencia distinta: denegada','OK'); DELETE @resultado;

 UPDATE integracion.PauUsuario SET VigenteHastaUtc=DATEADD(second,-10,SYSUTCDATETIME()) WHERE SistemaId=@s;
 INSERT @resultado EXEC integracion.paResolverSesionPau @json;
 IF (SELECT JSON_VALUE(JsonResultado,'$.estado') FROM @resultado) <> '0' THROW 51106,'Debe negar homologación vencida.',1;
 INSERT @pruebas VALUES('Homologación vencida: denegada','OK'); DELETE @resultado;
 UPDATE integracion.PauUsuario SET VigenteHastaUtc=DATEADD(hour,1,SYSUTCDATETIME()),Activo=0 WHERE SistemaId=@s;
 INSERT @resultado EXEC integracion.paResolverSesionPau @json;
 IF (SELECT JSON_VALUE(JsonResultado,'$.estado') FROM @resultado) <> '0' THROW 51107,'Debe negar usuario inactivo.',1;
 INSERT @pruebas VALUES('Usuario inactivo: denegado','OK'); DELETE @resultado;
 UPDATE integracion.PauUsuario SET Activo=1 WHERE SistemaId=@s;
 UPDATE integracion.PauPerfil SET Activo=0 WHERE SistemaId=@s;
 INSERT @resultado EXEC integracion.paResolverSesionPau @json;
 IF (SELECT JSON_VALUE(JsonResultado,'$.estado') FROM @resultado) <> '0' THROW 51108,'Debe negar perfil inactivo.',1;
 INSERT @pruebas VALUES('Perfil inactivo: denegado','OK'); DELETE @resultado;
 UPDATE integracion.PauPerfil SET Activo=1 WHERE SistemaId=@s;

 SET @otra=JSON_MODIFY(@json,'$.menu',JSON_QUERY('[{"id":"otro","disabled":false}]'));
 INSERT @resultado EXEC integracion.paResolverSesionPau @otra;
 IF (SELECT JSON_VALUE(JsonResultado,'$.estado') FROM @resultado) <> '0' THROW 51109,'Debe negar menú no concedido por PAU.',1;
 INSERT @pruebas VALUES('Menú no concedido por PAU: denegado','OK'); DELETE @resultado;
 SET @otra=JSON_MODIFY(@json,'$.menu',JSON_QUERY('[{"id":"padre","disabled":true,"children":[{"id":"modulo-prueba"}]}]'));
 INSERT @resultado EXEC integracion.paResolverSesionPau @otra;
 IF (SELECT JSON_VALUE(JsonResultado,'$.estado') FROM @resultado) <> '0' THROW 51110,'Debe negar hijo de padre deshabilitado.',1;
 INSERT @pruebas VALUES('Padre deshabilitado: hijos denegados','OK'); DELETE @resultado;
 SET @otra=JSON_MODIFY(@json,'$.menu',JSON_QUERY('[{"id":"padre","children":[{"id":"modulo-prueba"}]}]'));
 INSERT @resultado EXEC integracion.paResolverSesionPau @otra;
 IF (SELECT JSON_VALUE(JsonResultado,'$.estado') FROM @resultado) <> '1' THROW 51111,'Debe resolver menú anidado autorizado.',1;
 INSERT @pruebas VALUES('Menú anidado concedido: permitido','OK');
 ROLLBACK TRANSACTION;
 SELECT * FROM @pruebas;
 SELECT COUNT(*) ResiduosPrueba FROM integracion.PauUsuario WHERE SistemaId=@s;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
 THROW;
END CATCH;
