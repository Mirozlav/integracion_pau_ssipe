/*
================================================================================
 30 - Claims de las pestanas de Seguimiento de Ejecucion CVA, version PAU
================================================================================
 QUE ES
   Reemplaza al BLOQUE 2 de DESPLIEGUE/DESPLIEGUE_2_DBSSO.sql. Aquel daba de
   alta 11 operaciones en DBSSO (login.Operacion / DetallePerfilOperacion) para
   P0023, P0024 y P0025. Con SSIPE entrando solo por PAU, los claims que llegan
   al token salen de integracion.PauOperacion (ver paResolverSesionPau), asi
   que el SSO ya no se toca: los mismos 11 claims y la misma matriz por perfil
   se registran aqui.

     #  HasClaim (SSIPE + M0001 + NombreOperacion)        P0025 P0023 P0024  Accion PAU
     1  SSIPEM0001_ejecucion_btn_vincular_proceso           x     x           crear
     2  SSIPEM0001_ejecucion_btn_nuevo_conservacion         x     x     x     crear
     3  SSIPEM0001_ejecucion_btn_acciones_conservacion      x     x     x     leer
     4  SSIPEM0001_ejecucion_btn_nuevo_mejoramiento         x     x     x     crear
     5  SSIPEM0001_ejecucion_btn_acciones_mejoramiento      x     x     x     leer
     6  SSIPEM0001_ejecucion_btn_nuevo_socioambiental       x     x           crear
     7  SSIPEM0001_ejecucion_btn_acciones_socioambiental    x     x           leer
     8  SSIPEM0001_ejecucion_btn_nuevo_liquidacion          x     x           crear
     9  SSIPEM0001_ejecucion_btn_acciones_liquidacion       x     x           leer
    10  SSIPEM0001_ejecucion_btn_nuevo_panelfotografico     x     x     x     crear
    11  SSIPEM0001_ejecucion_btn_acciones_panelfotografico  x     x     x     leer
   (Accion = misma clasificacion con la que ya estan cargados en DESA.)

   En DESA ya existen todos (vinieron en el 19, exportado del SSO de DESA donde
   se habian aplicado): el script no hace nada. En QA/PROD garantiza que
   existan aunque el SSO de ese ambiente nunca los haya tenido.

   Todo se resuelve por codigo (CodigoPerfil, CodigoMenu M0001), nunca por Id,
   porque PerfilPauId / ModuloPauId cambian entre ambientes. ADITIVO e
   idempotente: inserta los que faltan y reactiva los inactivos; no toca otros.

 PRERREQUISITO
   Perfiles P0023/P0024/P0025 homologados en integracion.PauPerfil con su menu
   M0001 en integracion.PauMenu (scripts 18/19 o PASE_QA_PROD/P02).

 ATENCION - ARRANCA EN MODO SIMULACION (@confirmar = 0 -> ROLLBACK)
   Los usuarios ven los claims nuevos al volver a ingresar desde el PAU.
================================================================================
*/
IF DB_NAME() <> N'DBSSIPE2'   -- <<< en QA/PROD reemplazar por el nombre de la base SSIPE del ambiente
   OR OBJECT_ID(N'integracion.PauOperacion', N'U') IS NULL
BEGIN RAISERROR(N'Base incorrecta o falta la infraestructura de integracion: ejecucion cancelada.', 16, 1); SET NOEXEC ON; END
GO
SET NOCOUNT ON; SET XACT_ABORT ON;

DECLARE @confirmar bit = 0;

-- SistemaId de SSIPE en el PAU del ambiente: se toma de la homologacion (debe haber uno solo).
DECLARE @SistemaId int = (SELECT MIN(SistemaId) FROM integracion.PauPerfil WHERE Activo = 1);
IF @SistemaId IS NULL OR EXISTS (SELECT 1 FROM integracion.PauPerfil WHERE Activo = 1 AND SistemaId <> @SistemaId)
    THROW 56001, 'integracion.PauPerfil vacio o con mas de un SistemaId: revisar la homologacion.', 1;

DECLARE @claims TABLE (Orden int, HasClaim varchar(200), Accion varchar(10), P0025 bit, P0023 bit, P0024 bit);
INSERT @claims VALUES
 ( 1, 'SSIPEM0001_ejecucion_btn_vincular_proceso',          'crear', 1, 1, 0),
 ( 2, 'SSIPEM0001_ejecucion_btn_nuevo_conservacion',        'crear', 1, 1, 1),
 ( 3, 'SSIPEM0001_ejecucion_btn_acciones_conservacion',     'leer',  1, 1, 1),
 ( 4, 'SSIPEM0001_ejecucion_btn_nuevo_mejoramiento',        'crear', 1, 1, 1),
 ( 5, 'SSIPEM0001_ejecucion_btn_acciones_mejoramiento',     'leer',  1, 1, 1),
 ( 6, 'SSIPEM0001_ejecucion_btn_nuevo_socioambiental',      'crear', 1, 1, 0),
 ( 7, 'SSIPEM0001_ejecucion_btn_acciones_socioambiental',   'leer',  1, 1, 0),
 ( 8, 'SSIPEM0001_ejecucion_btn_nuevo_liquidacion',         'crear', 1, 1, 0),
 ( 9, 'SSIPEM0001_ejecucion_btn_acciones_liquidacion',      'leer',  1, 1, 0),
 (10, 'SSIPEM0001_ejecucion_btn_nuevo_panelfotografico',    'crear', 1, 1, 1),
 (11, 'SSIPEM0001_ejecucion_btn_acciones_panelfotografico', 'leer',  1, 1, 1);

DECLARE @matriz TABLE (CodigoPerfil varchar(20), HasClaim varchar(200), Accion varchar(10), Orden int);
INSERT @matriz SELECT 'P0025', HasClaim, Accion, Orden FROM @claims WHERE P0025 = 1
UNION ALL SELECT 'P0023', HasClaim, Accion, Orden FROM @claims WHERE P0023 = 1
UNION ALL SELECT 'P0024', HasClaim, Accion, Orden FROM @claims WHERE P0024 = 1;

DECLARE @destino TABLE (CodigoPerfil varchar(20), PerfilPauId int NULL, ModuloPauId nvarchar(100) NULL);
INSERT @destino (CodigoPerfil) VALUES ('P0025'), ('P0023'), ('P0024');
UPDATE d SET PerfilPauId = p.PerfilPauId
FROM @destino d JOIN integracion.PauPerfil p ON p.SistemaId = @SistemaId AND p.CodigoPerfil = d.CodigoPerfil AND p.Activo = 1;
UPDATE d SET ModuloPauId = m.ModuloPauId
FROM @destino d JOIN integracion.PauMenu m ON m.SistemaId = @SistemaId AND m.PerfilPauId = d.PerfilPauId AND m.CodigoMenu = 'M0001' AND m.Activo = 1;

IF EXISTS (SELECT 1 FROM @destino WHERE PerfilPauId IS NULL OR ModuloPauId IS NULL)
BEGIN
    SELECT Problema = 'PERFIL SIN HOMOLOGAR O SIN MENU M0001 (correr 18/19 o P02 antes)', * FROM @destino WHERE PerfilPauId IS NULL OR ModuloPauId IS NULL;
    THROW 56002, 'Falta homologar P0023/P0024/P0025 o su menu M0001.', 1;
END

BEGIN TRANSACTION;

UPDATE o SET Activo = 1
FROM integracion.PauOperacion o
JOIN @destino d ON d.PerfilPauId = o.PerfilPauId AND d.ModuloPauId = o.ModuloPauId
JOIN @matriz x ON x.CodigoPerfil = d.CodigoPerfil AND x.HasClaim = o.HasClaim
WHERE o.SistemaId = @SistemaId AND o.Activo = 0;
DECLARE @reactivados int = @@ROWCOUNT;

INSERT integracion.PauOperacion (SistemaId, PerfilPauId, ModuloPauId, HasClaim, Accion, Activo)
SELECT @SistemaId, d.PerfilPauId, d.ModuloPauId, x.HasClaim, x.Accion, 1
FROM @matriz x JOIN @destino d ON d.CodigoPerfil = x.CodigoPerfil
WHERE NOT EXISTS (SELECT 1 FROM integracion.PauOperacion o
                  WHERE o.SistemaId = @SistemaId AND o.PerfilPauId = d.PerfilPauId AND o.ModuloPauId = d.ModuloPauId AND o.HasClaim = x.HasClaim);
DECLARE @insertados int = @@ROWCOUNT;

SELECT Bloque = 'Resumen', d.CodigoPerfil, d.PerfilPauId,
       Esperados = (SELECT COUNT(*) FROM @matriz x WHERE x.CodigoPerfil = d.CodigoPerfil),
       Activos = (SELECT COUNT(*) FROM @matriz x JOIN integracion.PauOperacion o
                  ON o.SistemaId = @SistemaId AND o.PerfilPauId = d.PerfilPauId AND o.ModuloPauId = d.ModuloPauId AND o.HasClaim = x.HasClaim AND o.Activo = 1
                  WHERE x.CodigoPerfil = d.CodigoPerfil)
FROM @destino d ORDER BY d.CodigoPerfil;
PRINT CONCAT('Claims insertados: ', @insertados, ' | reactivados: ', @reactivados);

IF @confirmar = 1 BEGIN COMMIT; PRINT 'COMMIT realizado.'; END
ELSE BEGIN ROLLBACK; PRINT 'Simulacion: ROLLBACK. Poner @confirmar = 1 para aplicar.'; END
GO
SET NOEXEC OFF;
GO
