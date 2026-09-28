/*
================================================================================
 28 - Identidad de usuario SSIPE desde PAU + catalogo de areas sin desplegar en SSO
================================================================================
 QUE ES
   1) integracion.vw_UsuarioSsipe
      Unica fuente de "quien es quien y con que perfil" para SSIPE. Reemplaza a
      DBSSO.login.vw_UsuarioInternoSistemaSsipe / vw_PerfilesSistemaSsipe en los
      SPs de Asignar Proyecto y Seguimiento (script 29). Toma:
        - IdUsuario / IdArea historicos de SSIPE -> integracion.PauUsuario
        - datos personales y perfil vigente      -> integracion.PauDirectorio
          (lo llena el login PAU y, desde el script 25 v2, tambien la
          homologacion, asi el usuario aparece antes de su primer ingreso)
        - codigo/nombre de perfil SSIPE          -> integracion.PauPerfil
        - nombre del area (solo catalogo)        -> DBSSO.login.Area por IdArea
      Una sola fila por IdUsuario: si hubiera varias dependencias/perfiles
      activos gana el sincronizado mas reciente (el del ultimo ingreso).

   2) integracion.paListarArea
      Reemplaza al BLOQUE 1 de DESPLIEGUE/DESPLIEGUE_2_DBSSO.sql
      (login.paListarLoginArea + login.vw_Area en DBSSO). Misma logica y mismo
      JSON de salida, pero creado en la base SSIPE leyendo las tablas base del
      SSO (que sigue vivo como catalogo). Asi el pase a QA/PROD no necesita
      crear nada en DBSSO. El back (GeneralController.ListarArea) pasa a
      llamarlo por cnx_ssipe.

 DONDE SE EJECUTA
   Base SSIPE del ambiente (DBSSIPE2 en DESA). DBSSO debe estar en la misma
   instancia (asi funciona hoy en DESA y en la copia de produccion DBSSIPE3) y
   el usuario de la aplicacion debe tener SELECT sobre las tablas login.* que
   se leen (lo valida PASE_QA_PROD/P00).
================================================================================
*/
IF DB_NAME() <> N'DBSSIPE2'   -- <<< en QA/PROD reemplazar por el nombre de la base SSIPE del ambiente
   OR OBJECT_ID(N'integracion.PauDirectorio', N'U') IS NULL
   OR OBJECT_ID(N'seguimiento.AsignarProyectoFase', N'U') IS NULL
BEGIN RAISERROR(N'Base incorrecta o falta la infraestructura de integracion: ejecucion cancelada.', 16, 1); SET NOEXEC ON; END
GO

CREATE OR ALTER VIEW integracion.vw_UsuarioSsipe
AS
SELECT x.IdUsuario, x.IdPersona, x.IdPerfil, x.CodigoPerfil, x.NombrePerfil, x.Usuario, x.Documento,
       x.Nombres, x.ApellidoPaterno, x.ApellidoMaterno, x.IdArea, x.Area,
       x.SistemaId, x.UsuarioPauId, x.DependenciaPauId, x.PerfilPauId, x.SincronizadoUtc
FROM (
    SELECT u.IdUsuario, d.EntidadPauId AS IdPersona, p.IdPerfil, p.CodigoPerfil, p.NombrePerfil,
           d.Usuario, d.Documento, d.Nombres, d.ApellidoPaterno, d.ApellidoMaterno,
           u.IdArea,
           -- Nombre del area SSIPE (IdArea) desde el catalogo; si no existe, el nombre de dependencia que mando el PAU
           COALESCE(ar.Area, NULLIF(d.AreaNombre, N'')) AS Area,
           u.SistemaId, u.UsuarioPauId, u.DependenciaPauId, d.PerfilPauId, d.SincronizadoUtc,
           ROW_NUMBER() OVER (PARTITION BY u.IdUsuario ORDER BY d.SincronizadoUtc DESC, d.PerfilPauId DESC) AS rn
    FROM integracion.PauUsuario u
    INNER JOIN integracion.PauDirectorio d
        ON d.SistemaId = u.SistemaId AND d.UsuarioPauId = u.UsuarioPauId
       AND d.DependenciaPauId = u.DependenciaPauId AND d.Activo = 1
    INNER JOIN integracion.PauPerfil p
        ON p.SistemaId = d.SistemaId AND p.PerfilPauId = d.PerfilPauId AND p.Activo = 1
    LEFT JOIN DBSSO.login.Area ar ON ar.IdArea = u.IdArea
    WHERE u.Activo = 1 AND u.VigenteHastaUtc > SYSUTCDATETIME()
) x
WHERE x.rn = 1;
GO

CREATE OR ALTER PROCEDURE integracion.paListarArea
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @result nvarchar(max);

    SELECT @result = (
        SELECT s.IdDetalleArea, s.IdArea, s.Area, s.Sigla
        FROM (
            SELECT da.IdDetalleArea,
                   ar.IdArea,
                   da.Sigla,
                   ar.Area + CASE WHEN ss.EquipoTrabajo IS NOT NULL THEN ' / ' + ss.EquipoTrabajo ELSE '' END AS Area
            FROM DBSSO.login.DetalleArea da
            INNER JOIN DBSSO.login.Area ar ON da.IdArea = ar.IdArea
            INNER JOIN DBSSO.login.TipoArea ta ON ar.IdTipoArea = ta.IdTipoArea
            LEFT JOIN (
                SELECT det.IdDetalleArea, STRING_AGG(et.EquipoTrabajo, ' / ') AS EquipoTrabajo
                FROM DBSSO.login.DetalleAreaEquipoTrabajo det
                INNER JOIN DBSSO.login.EquipoTrabajo et ON det.IdEquipoTrabajo = et.IdEquipoTrabajo
                WHERE det.Activo = 1
                GROUP BY det.IdDetalleArea
            ) ss ON da.IdDetalleArea = ss.IdDetalleArea
            WHERE da.Activo = 1
              AND ta.CodigoTipoArea IN ('TA0001', 'TA0002', 'TA0003')   -- DIRECCION, OFICINA, GERENCIA
        ) s
        ORDER BY s.Area
        FOR JSON PATH
    );

    SELECT ISNULL(@result, '[]');
END;
GO

SELECT objeto = N'integracion.vw_UsuarioSsipe', filas = (SELECT COUNT(*) FROM integracion.vw_UsuarioSsipe);
EXEC integracion.paListarArea;
GO
SET NOEXEC OFF;
GO
