/* 16 - Export SOLO LECTURA desde DBSSO DESA: usuarios y perfiles que SSIPE usa hoy via SSO.
   Sirve para (a) verificar en PAU (PVDPAU_PROD) que existan los perfiles y usuarios equivalentes y
   (b) alimentar integracion.PauPerfil / integracion.PauUsuario en DBSSIPE2 (IdPerfil / IdUsuario / IdArea historicos).
   No expone contrasenas. Documento = clave de cruce con PAU (ENT_V_NRODOC); nunca cruzar por nombre.
   Ejecutar: scripts/Consultar-Catalogos.ps1 -Base SSO -SqlFile <este archivo> -OutputFile evidencias/16_export_SSO_ssipe.json */
IF DB_NAME() <> N'DBSSO' THROW 51001, 'Solo DBSSO DESA.', 1;

/* 1. Perfiles del sistema SSIPE (IdPerfil historico requerido por integracion.PauPerfil.IdPerfil) */
SELECT 'Perfil' AS Categoria, p.IdPerfil, p.CodigoPerfil, p.NombrePerfil, p.IdSistema
FROM login.vw_PerfilesSistemaSsipe p ORDER BY p.CodigoPerfil;

/* 2. Usuarios internos con perfil en SSIPE (IdUsuario/IdArea historicos requeridos por integracion.PauUsuario).
      Cruzar con PAU por (IdTipoDocumento, Documento) = ENT_V_NRODOC. */
SELECT 'UsuarioPerfil' AS Categoria, u.IdUsuario, u.Usuario, u.UsuarioRed, u.IdTipoDocumento, u.Documento,
       u.Nombres, u.ApellidoPaterno, u.ApellidoMaterno, u.IdPerfil, u.CodigoPerfil, u.NombrePerfil, u.GrupoPerfil,
       u.IdArea, u.Area, u.Correo
FROM login.vw_UsuarioInternoSistemaSsipe u ORDER BY u.CodigoPerfil, u.IdUsuario;

/* 3. Usuario de prueba PAU (DNI 42910203): ¿existe ya en SSO con acceso a SSIPE?
      Si no, no tiene IdUsuario historico y hay que definirlo en integracion.PauUsuario (ver script 17). */
SELECT 'UsuarioPrueba' AS Categoria, u.IdUsuario, u.Usuario, u.Documento, u.CodigoPerfil, u.NombrePerfil, u.IdArea, u.Area
FROM login.vw_UsuarioInternoSistemaSsipe u WHERE u.Documento = N'42910203';

/* 4. Areas usadas por usuarios SSIPE (para IdArea de la homologacion) */
SELECT 'Area' AS Categoria, u.IdArea, u.Area, COUNT_BIG(DISTINCT u.IdUsuario) AS Usuarios
FROM login.vw_UsuarioInternoSistemaSsipe u GROUP BY u.IdArea, u.Area ORDER BY u.Area;

/* 5. Menu por perfil SSIPE (alimenta integracion.PauMenu: CodigoMenu, NombreMenu, Url, Icono, Orden) */
SELECT 'Menu' AS Categoria, p.CodigoPerfil, p.NombrePerfil, dsm.IdDetalleSistemaMenu, dsm.IdMenuPadre, m.CodigoMenu, m.NombreMenu,
       dsm.Url, dsm.Icono, dsm.Nivel, dsm.Orden
FROM login.Sistema s
JOIN login.DetallePerfilSistema dps ON dps.IdSistema = s.IdSistema AND dps.Activo = 1
JOIN login.Perfil p ON p.IdPerfil = dps.IdPerfil AND p.Activo = 1
JOIN login.DetallePerfilSistemaMenu dpsm ON dpsm.IdDetallePerfilSistema = dps.IdDetallePerfilSistema AND dpsm.Activo = 1
JOIN login.DetalleSistemaMenu dsm ON dsm.IdDetalleSistemaMenu = dpsm.IdDetalleSistemaMenu AND dsm.Activo = 1
JOIN login.Menu m ON m.IdMenu = dsm.IdMenu AND m.Activo = 1
WHERE s.HasClaim = 'SSIPE'
ORDER BY p.CodigoPerfil, dsm.Nivel, dsm.Orden;

/* 6. Operaciones (HasClaim) por perfil y menu SSIPE (alimenta integracion.PauOperacion) */
SELECT 'Operacion' AS Categoria, p.CodigoPerfil, m.CodigoMenu, o.IdOperacion, o.NombreOperacion AS HasClaim,
       top_.CodigoTipoOperacion, top_.NombreTipoOperacion
FROM login.Sistema s
JOIN login.DetallePerfilSistema dps ON dps.IdSistema = s.IdSistema AND dps.Activo = 1
JOIN login.Perfil p ON p.IdPerfil = dps.IdPerfil AND p.Activo = 1
JOIN login.DetallePerfilSistemaMenu dpsm ON dpsm.IdDetallePerfilSistema = dps.IdDetallePerfilSistema AND dpsm.Activo = 1
JOIN login.DetalleSistemaMenu dsm ON dsm.IdDetalleSistemaMenu = dpsm.IdDetalleSistemaMenu AND dsm.Activo = 1
JOIN login.Menu m ON m.IdMenu = dsm.IdMenu
JOIN login.DetallePerfilOperacion dpo ON dpo.IdDetallePerfilSistemaMenu = dpsm.IdDetallePerfilSistemaMenu AND dpo.Activo = 1
JOIN login.Operacion o ON o.IdOperacion = dpo.IdOperacion AND o.Activo = 1
LEFT JOIN login.TipoOperacion top_ ON top_.IdTipoOperacion = o.IdTipoOperacion
WHERE s.HasClaim = 'SSIPE'
ORDER BY p.CodigoPerfil, m.CodigoMenu, o.NombreOperacion;
