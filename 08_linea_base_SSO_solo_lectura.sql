/* Solo lectura en DBSSO DESA. Línea base para homologación hacia PAU. */
IF DB_NAME()<>N'DBSSO' THROW 51001,'Solo DBSSO DESA.',1;
SELECT 'Sistema' Categoria,CONVERT(varchar(30),IdSistema) Codigo,NombreSistema Nombre,CONVERT(bigint,1) Cantidad
FROM login.Sistema WHERE HasClaim='SSIPE'
UNION ALL
SELECT 'Perfil',CodigoPerfil,NombrePerfil,NULL
FROM login.vw_PerfilesSistemaSsipe
UNION ALL
SELECT 'UsuariosPerfil',CodigoPerfil,NombrePerfil,COUNT_BIG(DISTINCT IdUsuario)
FROM login.vw_UsuarioInternoSistemaSsipe GROUP BY CodigoPerfil,NombrePerfil
ORDER BY Categoria,Codigo;

SELECT SCHEMA_NAME(o.schema_id) Esquema,o.name Objeto,c.name Columna
FROM sys.columns c JOIN sys.objects o ON o.object_id=c.object_id
WHERE c.name LIKE '%HasClaim%' ORDER BY Esquema,Objeto,Columna;
