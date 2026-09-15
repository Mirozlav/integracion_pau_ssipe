/* Actividades 3/7/8 y dependencia adelantada de 11.
   Preparado para DBSSIPE2 DESA. No contiene altas de usuarios ni permisos.
   Cargar homologaciones revisadas por el responsable antes de habilitar PAU.
   IdUsuario conserva el identificador histórico de AsignarProyectoFase.
   No se sustituyen vistas SSO con un espejo incompleto. */
SET XACT_ABORT ON;
BEGIN TRY
BEGIN TRANSACTION;
IF DB_NAME()<>N'DBSSIPE2' THROW 50001,'Seleccionar DBSSIPE2 DESA.',1;
IF CONVERT(nvarchar(128),SERVERPROPERTY('MachineName')) <> N'PVDDEV-BD07' THROW 51001,'Solo servidor DESA PVDDEV-BD07.',1;
IF SCHEMA_ID(N'integracion') IS NULL EXEC(N'CREATE SCHEMA integracion');
IF OBJECT_ID(N'integracion.PauUsuario',N'U') IS NULL
CREATE TABLE integracion.PauUsuario(
 SistemaId int NOT NULL, UsuarioPauId int NOT NULL, DependenciaPauId int NOT NULL,
 IdUsuario int NOT NULL, IdArea int NOT NULL, UsuarioAuditoria nvarchar(100) NOT NULL,
 Activo bit NOT NULL DEFAULT 0, VigenteHastaUtc datetime2 NOT NULL,
 RevisadoPor nvarchar(100) NOT NULL, RevisadoUtc datetime2 NOT NULL DEFAULT SYSUTCDATETIME(),
 PRIMARY KEY(SistemaId,UsuarioPauId,DependenciaPauId), UNIQUE(SistemaId,IdUsuario,DependenciaPauId)
);
IF OBJECT_ID(N'integracion.PauPerfil',N'U') IS NULL
CREATE TABLE integracion.PauPerfil(
 SistemaId int NOT NULL, PerfilPauId int NOT NULL, IdPerfil int NOT NULL,
 CodigoPerfil varchar(20) NOT NULL, NombrePerfil nvarchar(200) NOT NULL,
 Activo bit NOT NULL DEFAULT 0, PRIMARY KEY(SistemaId,PerfilPauId)
);
IF OBJECT_ID(N'integracion.PauMenu',N'U') IS NULL
CREATE TABLE integracion.PauMenu(
 SistemaId int NOT NULL, PerfilPauId int NOT NULL, ModuloPauId nvarchar(100) NOT NULL,
 CodigoMenu varchar(30) NOT NULL, NombreMenu nvarchar(200) NOT NULL,
 Url nvarchar(300) NOT NULL, Icono nvarchar(100) NOT NULL DEFAULT '', Orden int NOT NULL,
 Activo bit NOT NULL DEFAULT 0, PRIMARY KEY(SistemaId,PerfilPauId,ModuloPauId),
 FOREIGN KEY(SistemaId,PerfilPauId) REFERENCES integracion.PauPerfil(SistemaId,PerfilPauId)
);
IF OBJECT_ID(N'integracion.PauOperacion',N'U') IS NULL
CREATE TABLE integracion.PauOperacion(
 SistemaId int NOT NULL, PerfilPauId int NOT NULL, ModuloPauId nvarchar(100) NOT NULL,
 HasClaim varchar(200) NOT NULL, Accion varchar(10) NOT NULL,
 Activo bit NOT NULL DEFAULT 0,
 PRIMARY KEY(SistemaId,PerfilPauId,ModuloPauId,HasClaim),
 CHECK(Accion IN ('leer','crear','editar','eliminar')),
 FOREIGN KEY(SistemaId,PerfilPauId,ModuloPauId) REFERENCES integracion.PauMenu(SistemaId,PerfilPauId,ModuloPauId)
);
COMMIT;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
END CATCH;
SELECT name FROM sys.tables WHERE schema_id=SCHEMA_ID('integracion');

