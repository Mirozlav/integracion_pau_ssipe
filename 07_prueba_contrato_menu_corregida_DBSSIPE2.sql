/* Prueba del contrato de menú plano SSIPE. Datos ficticios con ROLLBACK. */
SET XACT_ABORT ON;
IF DB_NAME()<>N'DBSSIPE2' THROW 51001,'Solo DBSSIPE2 DESA.',1;
BEGIN TRY
 BEGIN TRANSACTION;
 DECLARE @s int=2000000011;
 DECLARE @out TABLE(JsonResultado nvarchar(max));
 INSERT integracion.PauUsuario(SistemaId,UsuarioPauId,DependenciaPauId,IdUsuario,IdArea,UsuarioAuditoria,Activo,VigenteHastaUtc,RevisadoPor)
 VALUES(@s,2000000012,2000000013,2000000014,2000000015,'PRUEBA_NO_REAL',1,DATEADD(hour,1,SYSUTCDATETIME()),'TEST_ROLLBACK');
 INSERT integracion.PauPerfil VALUES(@s,2000000016,2000000017,'TEST','PERFIL PRUEBA',1);
 INSERT integracion.PauMenu VALUES(@s,2000000016,'modulo-prueba','TEST','Prueba','/seguimiento','',1,1);
 INSERT integracion.PauOperacion VALUES(@s,2000000016,'modulo-prueba','TEST_LEER','leer',1);
 DECLARE @json nvarchar(max)=N'{"version":2,"sistemaId":2000000011,"usuarioId":2000000012,"dependenciaId":2000000013,"perfilId":2000000016,"nombres":"PRUEBA","apellidoPaterno":"REVERTIDA","accesos":{"total":false,"leer":true,"crear":false,"editar":false,"eliminar":false},"menu":[{"id":"modulo-prueba"}]}';
 INSERT @out EXEC integracion.paResolverSesionPau @json;
 DECLARE @r nvarchar(max)=(SELECT JsonResultado FROM @out);
 IF JSON_VALUE(@r,'$.estado')<>'1' THROW 51200,'No se creó sesión.',1;
 IF JSON_VALUE(@r,'$.resultado.detalle[0].perfil[0].menu[0].Nivel')<>'0' THROW 51201,'Nivel raíz debe ser 0.',1;
 IF TRY_CONVERT(int,JSON_VALUE(@r,'$.resultado.detalle[0].perfil[0].menu[0].IdMenu')) IS NULL THROW 51202,'IdMenu es obligatorio.',1;
 IF JSON_VALUE(@r,'$.resultado.detalle[0].perfil[0].menu[0].id_menu_padre')<>'0' THROW 51203,'id_menu_padre debe existir.',1;
 IF JSON_VALUE(@r,'$.resultado.detalle[0].perfil[0].menu[0].Url')<>'/seguimiento' THROW 51204,'URL no conservada.',1;
 ROLLBACK TRANSACTION;
 SELECT 'Contrato menú SSIPE' Prueba,'OK' Estado;
 SELECT COUNT(*) ResiduosPrueba FROM integracion.PauUsuario WHERE SistemaId=@s;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
 THROW;
END CATCH;
