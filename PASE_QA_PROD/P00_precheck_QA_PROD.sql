/*
================================================================================
 P00 - Prechequeo del pase PAU -> SSIPE en QA/PROD. SOLO LECTURA.
================================================================================
 Ejecutar conectado a la base SSIPE del ambiente CON EL MISMO USUARIO que usa el
 back (cnx_ssipe). Todas las filas deben salir en OK antes de seguir con P01.
 Validado contra DBSSIPE3 (copia fiel de produccion) el 25/09/2026.
================================================================================
*/
SET NOCOUNT ON;
DECLARE @chk TABLE (Orden int, Control nvarchar(200), Resultado nvarchar(20), Detalle nvarchar(400));

INSERT @chk SELECT 1, N'Base SSIPE (existe seguimiento.AsignarProyectoFase)',
    CASE WHEN OBJECT_ID(N'seguimiento.AsignarProyectoFase', N'U') IS NOT NULL THEN N'OK' ELSE N'FALLA' END, DB_NAME();

INSERT @chk SELECT 2, N'DBSSO en la misma instancia',
    CASE WHEN DB_ID(N'DBSSO') IS NOT NULL THEN N'OK' ELSE N'FALLA' END, N'Se lee con nombres de tres partes DBSSO.login.*';

INSERT @chk SELECT 3, CONCAT(N'SELECT sobre DBSSO.login.', t.n),
    CASE WHEN HAS_PERMS_BY_NAME(N'DBSSO.login.' + t.n, N'OBJECT', N'SELECT') = 1 THEN N'OK' ELSE N'FALLA' END,
    N'Usuario: ' + SUSER_SNAME()
FROM (VALUES (N'DetalleArea'), (N'Area'), (N'TipoArea'), (N'DetalleAreaEquipoTrabajo'), (N'EquipoTrabajo'),
             (N'Usuario'), (N'vw_UsuarioInternoSistemaSsipe')) t(n);

INSERT @chk SELECT 4, CONCAT(N'Parche aplicable en seguimiento.', t.n),
    CASE WHEN (DATALENGTH(d.def) - DATALENGTH(REPLACE(d.def, N'DBSSO.login.vw_UsuarioInternoSistemaSsipe', N''))) / DATALENGTH(N'DBSSO.login.vw_UsuarioInternoSistemaSsipe') = 1
              OR CHARINDEX(N'integracion.vw_UsuarioSsipe', d.def) > 0 THEN N'OK' ELSE N'FALLA' END,
    N'Debe tener exactamente 1 referencia a la vista SSO (o ya estar parchado)'
FROM (VALUES (N'paListarSeguimientoProyecto'), (N'paListarSeguimientoSeguimiento'), (N'paListarSeguimientoConvenio')) t(n)
CROSS APPLY (SELECT def = OBJECT_DEFINITION(OBJECT_ID(N'seguimiento.' + t.n))) d;

INSERT @chk SELECT 4, CONCAT(N'Cabecera CREATE PROCEDURE reconocible en seguimiento.', t.n),
    CASE WHEN LTRIM(REPLACE(REPLACE(REPLACE(SUBSTRING(d.def, CHARINDEX(N'CREATE', d.def) + 6, 40), CHAR(13), N' '), CHAR(10), N' '), CHAR(9), N' ')) LIKE N'PROC%'
              OR LTRIM(REPLACE(REPLACE(REPLACE(SUBSTRING(d.def, CHARINDEX(N'CREATE', d.def) + 6, 40), CHAR(13), N' '), CHAR(10), N' '), CHAR(9), N' ')) LIKE N'OR ALTER PROC%'
         THEN N'OK' ELSE N'FALLA' END,
    N'El script 29 convierte CREATE en ALTER para conservar permisos'
FROM (VALUES (N'paListarSeguimientoProyecto'), (N'paListarSeguimientoSeguimiento'), (N'paListarSeguimientoConvenio')) t(n)
CROSS APPLY (SELECT def = OBJECT_DEFINITION(OBJECT_ID(N'seguimiento.' + t.n))) d;

INSERT @chk SELECT 5, N'Procedimientos de Asignar Proyecto presentes',
    CASE WHEN (SELECT COUNT(*) FROM sys.objects WHERE schema_id = SCHEMA_ID(N'seguimiento') AND name IN
        (N'paAnularAsignarProyectoFase', N'paInsertarAsignarProyectoFase', N'paListarAsignarProyectoFase',
         N'paListarAsignarProyectoFaseProyecto', N'paListarAsignarProyectoFaseUsuario')) = 5 THEN N'OK' ELSE N'FALLA' END, N'';

INSERT @chk SELECT 6, N'Permiso para crear objetos (db_owner o db_ddladmin)',
    CASE WHEN IS_MEMBER(N'db_owner') = 1 OR IS_MEMBER(N'db_ddladmin') = 1 THEN N'OK' ELSE N'FALLA' END,
    N'Si se despliega con otra cuenta, ignorar esta fila';

INSERT @chk SELECT 7, N'Esquema integracion (informativo)',
    N'INFO', CASE WHEN SCHEMA_ID(N'integracion') IS NULL THEN N'No existe: P01 lo crea' ELSE N'Ya existe: P01 solo completa lo que falte' END;

SELECT * FROM @chk ORDER BY Orden, Control;
SELECT ListoParaPase = CASE WHEN EXISTS (SELECT 1 FROM @chk WHERE Resultado = N'FALLA') THEN 0 ELSE 1 END;
