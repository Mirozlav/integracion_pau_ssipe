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
IF DB_NAME() <> N'DBSSIPE'   -- <<< nombre de la base SSIPE del ambiente (QA/PROD)
   OR OBJECT_ID(N'seguimiento.AsignarProyectoFase', N'U') IS NULL
BEGIN RAISERROR(N'Base incorrecta: ejecucion cancelada.', 16, 1); SET NOEXEC ON; END
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
SET NOEXEC OFF;
GO
