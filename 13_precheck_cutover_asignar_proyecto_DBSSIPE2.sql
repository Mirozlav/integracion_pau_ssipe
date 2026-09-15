/* Precondiciones del corte Asignar Proyecto. Solo lectura. */
IF DB_NAME()<>N'DBSSIPE2' THROW 51001,'Solo DBSSIPE2 DESA.',1;
SELECT
 (SELECT COUNT_BIG(*) FROM integracion.PauUsuario WHERE Activo=1 AND VigenteHastaUtc>SYSUTCDATETIME()) UsuariosHomologadosVigentes,
 (SELECT COUNT_BIG(*) FROM integracion.PauDirectorio WHERE Activo=1) IdentidadesDirectorioActivas,
 (SELECT COUNT_BIG(*) FROM integracion.PauPerfil WHERE Activo=1) PerfilesHomologadosActivos,
 (SELECT COUNT_BIG(*) FROM integracion.PauMenu WHERE Activo=1) MenusHomologadosActivos,
 (SELECT COUNT_BIG(*) FROM integracion.PauOperacion WHERE Activo=1) OperacionesHomologadasActivas,
 CASE WHEN EXISTS(SELECT 1 FROM integracion.PauDirectorio WHERE Activo=1)
  AND NOT EXISTS(SELECT 1 FROM integracion.PauUsuario u WHERE u.Activo=1 AND u.VigenteHastaUtc>SYSUTCDATETIME()
   AND NOT EXISTS(SELECT 1 FROM integracion.PauDirectorio d WHERE d.SistemaId=u.SistemaId AND d.UsuarioPauId=u.UsuarioPauId
    AND d.DependenciaPauId=u.DependenciaPauId AND d.Activo=1)) THEN 1 ELSE 0 END ListoParaCorte;
