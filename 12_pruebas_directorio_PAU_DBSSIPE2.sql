/* Pruebas transaccionales del directorio PAU. Siempre revierte los datos de prueba. */
SET XACT_ABORT ON;
IF DB_NAME()<>N'DBSSIPE2' THROW 51001,'Solo DBSSIPE2 DESA.',1;
BEGIN TRANSACTION;
BEGIN TRY
 DECLARE @sistema int=2147483000,@usuario int=2147483001,@dependencia int=2147483002,@perfil int=2147483003;
 INSERT integracion.PauUsuario(SistemaId,UsuarioPauId,DependenciaPauId,IdUsuario,IdArea,UsuarioAuditoria,Activo,VigenteHastaUtc,RevisadoPor)
 VALUES(@sistema,@usuario,@dependencia,2147483004,2147483005,N'PRUEBA_PAU',1,DATEADD(day,1,SYSUTCDATETIME()),N'PRUEBA_AUTOMATICA');
 INSERT integracion.PauPerfil(SistemaId,PerfilPauId,IdPerfil,CodigoPerfil,NombrePerfil,Activo)
 VALUES(@sistema,@perfil,2147483006,'P0023',N'Prueba PAU',1);

 EXEC integracion.paRegistrarDirectorioPau N'{"sistemaId":2147483000,"usuarioId":2147483001,"dependenciaId":2147483002,"perfilId":2147483003,"entidadId":2147483007,"documento":"00000000","usuario":"PRUEBA_PAU","nombres":"USUARIO","apellidoPaterno":"PRUEBA","apellidoMaterno":"PAU","perfilNombre":"Prueba PAU","areaNombre":"Área de prueba"}';

 IF NOT EXISTS(SELECT 1 FROM integracion.PauDirectorio WHERE SistemaId=@sistema AND UsuarioPauId=@usuario
  AND DependenciaPauId=@dependencia AND PerfilPauId=@perfil AND Activo=1 AND Documento=N'00000000')
  THROW 53001,'No se registró el directorio PAU.',1;
 SELECT N'REGISTRO_DIRECTORIO' Prueba,N'OK' Resultado;
 ROLLBACK;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
END CATCH;
IF EXISTS(SELECT 1 FROM integracion.PauDirectorio WHERE SistemaId=2147483000) THROW 53002,'Quedaron residuos de prueba.',1;
SELECT N'CERO_RESIDUOS' Prueba,N'OK' Resultado;
