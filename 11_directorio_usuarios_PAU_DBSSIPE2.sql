/* Actividad 13, paso seguro previo al corte SSO.
   Registra en SSIPE únicamente identidades PAU que ya poseen homologación aprobada. */
SET XACT_ABORT ON;
IF DB_NAME()<>N'DBSSIPE2' THROW 51001,'Solo DBSSIPE2 DESA.',1;
IF CONVERT(nvarchar(128),SERVERPROPERTY('MachineName'))<>N'PVDDEV-BD07' THROW 51002,'Solo servidor DESA PVDDEV-BD07.',1;
GO

IF OBJECT_ID(N'integracion.PauDirectorio',N'U') IS NULL
BEGIN
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
  CONSTRAINT PK_PauDirectorio PRIMARY KEY(SistemaId,UsuarioPauId,DependenciaPauId,PerfilPauId),
  CONSTRAINT FK_PauDirectorio_Usuario FOREIGN KEY(SistemaId,UsuarioPauId,DependenciaPauId)
   REFERENCES integracion.PauUsuario(SistemaId,UsuarioPauId,DependenciaPauId),
  CONSTRAINT FK_PauDirectorio_Perfil FOREIGN KEY(SistemaId,PerfilPauId)
   REFERENCES integracion.PauPerfil(SistemaId,PerfilPauId)
 );
END;
GO

CREATE OR ALTER PROCEDURE integracion.paRegistrarDirectorioPau @parametro nvarchar(max)
AS
BEGIN
 SET NOCOUNT ON;
 SET XACT_ABORT ON;
 IF DB_NAME()<>N'DBSSIPE2' THROW 51001,'Solo DBSSIPE2 DESA.',1;
 IF ISJSON(@parametro)<>1 THROW 52001,'JSON PAU inválido.',1;

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
  THROW 52003,'Usuario PAU sin homologación vigente.',1;
 IF NOT EXISTS(SELECT 1 FROM integracion.PauPerfil WHERE SistemaId=@sistema AND PerfilPauId=@perfil AND Activo=1)
  THROW 52004,'Perfil PAU sin homologación vigente.',1;

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

SELECT name FROM sys.objects WHERE object_id IN(OBJECT_ID(N'integracion.PauDirectorio'),OBJECT_ID(N'integracion.paRegistrarDirectorioPau'));
