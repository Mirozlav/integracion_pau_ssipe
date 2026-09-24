/*
================================================================================
 SSIPE-PAU - Cambiar a que ambiente redirige el boton de SSIPE dentro del PAU
================================================================================
 QUE ES
   El front del PAU (list-apps.component.ts, redirectApp) abre, al hacer click
   en el boton de SSIPE:
     I_SISTEMA_SIS.SIS_V_LINKSI + '?unique_code=<GUID>&id_sistemas=2020&...'
   Este script SOLO cambia esa URL (SIS_V_LINKSI) para el sistema 2020. No
   toca perfiles, roles, modulos ni asignaciones de usuario (son independientes
   del ambiente al que apunta el sistema).

 POR QUE HACIA FALTA
   El 17/09 se migro SIS_V_LINKSI de 'http://localhost:4200/pau/callback'
   (front SSIPE local) al front desplegado (documentado como parte de
   "cambios para publicacion pau" en ssipe_front/ssipe_back, ver
   integracion/fase1-temporal-pau-ssipe/HANDOFF_CONTINUAR_INTEGRACION.md).
   Para volver a probar el front en localhost:4200 hay que revertir ese valor.

 DONDE SE EJECUTA
   PVDPAU_PROD en 10.4.0.20\artemisa20 (servidor PVDDEV-BD01, DESA del PAU).
   NO ejecutar en PVDPAU (10.3.0.123, produccion real). Ejecutar a mano por
   SSMS (no esta en la lista que acepta Ejecutar-Desarrollo.ps1, que es solo
   para DBSSIPE2).

 ATENCION - IMPACTO GLOBAL Y COMPARTIDO
   SIS_V_LINKSI es una sola fila para todo el PAU de DESA: mientras apunte a
   LOCAL, CUALQUIER usuario que entre a SSIPE desde el PAU (no solo vos) caera
   en tu http://localhost:4200 y le fallara si no tiene el front local
   levantado. Volver a 'DESPLIEGUE' apenas termines de probar.

 REQUISITO ADICIONAL EN EL BACK SSIPE (no lo hace este script)
   Si el PAU que estas usando es el PUBLICADO (https://desarrollo.proviasdes.gob.pe:1002),
   el unique_code lo emite ESE PAU, no uno local. El back de SSIPE debe validar
   el canje contra ESE MISMO PAU: PauIntegration.IntegrationUrl / UserApiUrl deben
   apuntar a https://desarrollo.proviasdes.gob.pe:1001/api/Auth/... (appsettings.json),
   NO a http://localhost:5285/... (appsettings.Development.json, que es para cuando
   el PAU tambien corre local). Si el back local arranca en modo Development
   apuntando a localhost:5285 mientras el PAU real es el publicado, el canje
   fallara con MESSAGE_TOKEN_ERROR_INTEGRATION aunque el LINKSI ya apunte bien.

 ATENCION - ARRANCA EN MODO SIMULACION
   @confirmar = 0 corre todo en una transaccion y hace ROLLBACK, mostrando el
   valor actual y el destino antes de tocar nada. Revisar y recien entonces
   poner @confirmar = 1 y volver a ejecutar. Es idempotente: si ya apunta al
   destino pedido, no hace nada.
================================================================================
*/
SET NOCOUNT ON; SET XACT_ABORT ON;
IF DB_NAME() <> N'PVDPAU_PROD' THROW 50001, 'Seleccionar PVDPAU_PROD (DESA PAU).', 1;
IF CONVERT(nvarchar(128), SERVERPROPERTY('MachineName')) <> N'PVDDEV-BD01' THROW 50002, 'Solo servidor DESA PVDDEV-BD01 (Artemisa20).', 1;

DECLARE @confirmar         bit = 0;              -- 1 = COMMIT, 0 = simula y hace ROLLBACK
DECLARE @sistemaId         int = 2020;           -- SSIPE en el PAU de DESA
DECLARE @destino           varchar(20) = 'LOCAL'; -- 'LOCAL' | 'DESPLIEGUE' | 'PERSONALIZADO'
DECLARE @urlPersonalizada  varchar(255) = NULL;   -- solo si @destino = 'PERSONALIZADO'

-- =====> Ajustar aqui si algun dia cambia el puerto/host del despliegue <=====
DECLARE @urlLocal      varchar(255) = 'http://localhost:4200/pau/callback';
DECLARE @urlDespliegue varchar(255) = 'http://10.4.0.31:9082/pau/callback';

DECLARE @nuevaUrl varchar(255) =
    CASE @destino
        WHEN 'LOCAL' THEN @urlLocal
        WHEN 'DESPLIEGUE' THEN @urlDespliegue
        WHEN 'PERSONALIZADO' THEN @urlPersonalizada
        ELSE NULL
    END;
IF @nuevaUrl IS NULL THROW 50003, '@destino debe ser LOCAL, DESPLIEGUE o PERSONALIZADO (con @urlPersonalizada).', 1;

DECLARE @actual varchar(255) = (SELECT SIS_V_LINKSI FROM I_SISTEMA_SIS WHERE SIS_PK_SISTEM = @sistemaId);
IF @actual IS NULL
BEGIN
    DECLARE @msgNoExiste varchar(255) = CONCAT('No existe el sistema ', @sistemaId, ' en I_SISTEMA_SIS.');
    THROW 50004, @msgNoExiste, 1;
END

PRINT CONCAT('SIS_V_LINKSI actual: ', @actual, '  (copialo si despues quieres volver a este valor exacto con PERSONALIZADO)');
PRINT CONCAT('SIS_V_LINKSI destino (', @destino, '): ', @nuevaUrl);

IF @actual = @nuevaUrl
BEGIN
    PRINT 'Ya apunta al destino pedido; nada que hacer.';
    SELECT SIS_PK_SISTEM, SIS_V_NOMSIS, SIS_V_LINKSI FROM I_SISTEMA_SIS WHERE SIS_PK_SISTEM = @sistemaId;
END
ELSE
BEGIN
    BEGIN TRANSACTION;
    UPDATE I_SISTEMA_SIS SET SIS_V_LINKSI = @nuevaUrl WHERE SIS_PK_SISTEM = @sistemaId;
    SELECT SIS_PK_SISTEM, SIS_V_NOMSIS, SIS_V_LINKSI AS LinkNuevo FROM I_SISTEMA_SIS WHERE SIS_PK_SISTEM = @sistemaId;
    IF @confirmar = 1 BEGIN COMMIT; PRINT 'COMMIT realizado.'; END
    ELSE BEGIN ROLLBACK; PRINT 'Simulacion: ROLLBACK. Revisar el SELECT y poner @confirmar = 1 para aplicar.'; END
END
