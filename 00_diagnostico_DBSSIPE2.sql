/* Solo lectura. Base autorizada: DBSSIPE2, Artemisa36 DESA. */
IF DB_NAME() <> N'DBSSIPE2' THROW 51000, 'Ejecutar solamente en DBSSIPE2.', 1;
SELECT 'Ambiente' Tipo,DB_NAME() Objeto,
 (SELECT CAST(SERVERPROPERTY('ServerName') AS nvarchar(128)) Servidor,DB_NAME() Base,
 HAS_PERMS_BY_NAME(DB_NAME(),'DATABASE','CREATE TABLE') CrearTabla,
 HAS_PERMS_BY_NAME(DB_NAME(),'DATABASE','CREATE PROCEDURE') CrearProcedimiento
 FOR JSON PATH,WITHOUT_ARRAY_WRAPPER) Datos
UNION ALL
SELECT 'Dependencia',QUOTENAME(SCHEMA_NAME(o.schema_id))+'.'+QUOTENAME(o.name),m.definition
FROM sys.objects o JOIN sys.sql_modules m ON m.object_id=o.object_id
WHERE m.definition LIKE '%DBSSO%' OR o.name LIKE '%AsignarProyecto%'
UNION ALL
SELECT 'Columnas',QUOTENAME(SCHEMA_NAME(o.schema_id))+'.'+QUOTENAME(o.name),
 (SELECT c.name Columna,TYPE_NAME(c.user_type_id) Tipo,c.max_length Longitud,c.is_nullable PermiteNull
 FROM sys.columns c WHERE c.object_id=o.object_id ORDER BY c.column_id FOR JSON PATH)
FROM sys.objects o WHERE o.name IN ('AsignarProyectoFase','PauUsuario','PauPerfil','PauMenu','PauOperacion')
UNION ALL
SELECT 'Conteo','AsignarProyectoFase',
 (SELECT COUNT_BIG(*) Total,SUM(CASE WHEN Activo=1 AND Asignado=1 THEN 1 ELSE 0 END) Activas
 FROM seguimiento.AsignarProyectoFase FOR JSON PATH,WITHOUT_ARRAY_WRAPPER);
