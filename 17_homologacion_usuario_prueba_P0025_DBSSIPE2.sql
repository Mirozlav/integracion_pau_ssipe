/* 17 - Homologacion en DBSSIPE2 del usuario de prueba PAU (DNI 42910203) con perfil SSO P0025 COORDINADOR DE OBRA.
   Generado el 15/09/2026 desde evidencias/16_export_SSO_ssipe.json (DBSSO DESA, solo lectura).
   Datos historicos SSO: IdUsuario=46, IdArea=14 (GERENCIA DE OBRAS), IdPerfil=32 (P0025).
   Menus P0025: 4. Operaciones P0025: 75. HasClaim = 'SSIPE' + CodigoMenu + NombreOperacion.

   PRERREQUISITO: ids reales del PAU (PVDPAU_PROD) obtenidos con 14_inventario_PAU_PVDPAU_PROD.sql y, si hizo falta,
   creados con 15_alta_perfil_coordinador_obra_PAU_PVDPAU_PROD.sql. Completar las variables. Corre en transaccion;
   ROLLBACK salvo @confirmar = 1. Idempotente (no duplica filas). Requiere tablas del script 01. */
SET NOCOUNT ON; SET XACT_ABORT ON;
IF DB_NAME() <> N'DBSSIPE2' THROW 50001, 'Seleccionar DBSSIPE2 DESA.', 1;
IF CONVERT(nvarchar(128), SERVERPROPERTY('MachineName')) <> N'PVDDEV-BD07' THROW 51001, 'Solo servidor DESA PVDDEV-BD07.', 1;

DECLARE @confirmar      bit = 0;              -- 1 = COMMIT
DECLARE @SistemaId      int = NULL;           -- id de SSIPE en PAU (SP_SEL_SISTEMAS). Mismo valor que PauIntegration:SistemaId en SSIPE
DECLARE @PerfilPauId    int = NULL;           -- PER_PK_PERFI de 'COORDINADOR DE OBRA' en PAU para ese sistema
DECLARE @UsuarioPauId   int = NULL;           -- USU_PK_USUAR del DNI 42910203 en PAU
DECLARE @DependenciaPauId int = NULL;         -- DEN_PK_DETEN (dependencia) del usuario en PAU
DECLARE @RevisadoPor    nvarchar(100) = N'42910203';
DECLARE @VigenteHasta   datetime2 = DATEADD(DAY, 90, SYSUTCDATETIME());   -- vigencia de prueba
/* Modulos PAU (id del nodo del menu que PAU devuelve en permisos.menu[].id para los roles del grupo).
   Deben existir en PAU como modulos del sistema SSIPE y estar en GPR_FK_ROLES del grupo; si PAU aun no tiene modulos
   para SSIPE, crearlos desde el front PAU (Modulos/Roles) usando estos mismos codigos como referencia. */
DECLARE @Mod_M0001 nvarchar(100) = NULL;   -- Seguimiento (/seguimiento)
DECLARE @Mod_M0007 nvarchar(100) = NULL;   -- Proyecto (/intervencion)
DECLARE @Mod_M0043 nvarchar(100) = NULL;   -- Convenio (/convenio)
DECLARE @Mod_M1051 nvarchar(100) = NULL;   -- Asignar Proyecto (/asignarProyecto)

IF @SistemaId IS NULL OR @PerfilPauId IS NULL OR @UsuarioPauId IS NULL OR @DependenciaPauId IS NULL
    THROW 50002, 'Completar @SistemaId, @PerfilPauId, @UsuarioPauId y @DependenciaPauId con los ids del PAU.', 1;
IF @Mod_M0001 IS NULL OR @Mod_M0007 IS NULL OR @Mod_M0043 IS NULL OR @Mod_M1051 IS NULL
    THROW 50003, 'Completar los ids de modulo PAU (@Mod_*).', 1;

BEGIN TRANSACTION;

/* 1. Perfil */
IF NOT EXISTS (SELECT 1 FROM integracion.PauPerfil WHERE SistemaId = @SistemaId AND PerfilPauId = @PerfilPauId)
    INSERT integracion.PauPerfil (SistemaId, PerfilPauId, IdPerfil, CodigoPerfil, NombrePerfil, Activo)
    VALUES (@SistemaId, @PerfilPauId, 32, 'P0025', N'COORDINADOR DE OBRA', 1);
ELSE UPDATE integracion.PauPerfil SET IdPerfil = 32, CodigoPerfil = 'P0025', NombrePerfil = N'COORDINADOR DE OBRA', Activo = 1
     WHERE SistemaId = @SistemaId AND PerfilPauId = @PerfilPauId;

/* 2. Menus */
IF NOT EXISTS (SELECT 1 FROM integracion.PauMenu WHERE SistemaId = @SistemaId AND PerfilPauId = @PerfilPauId AND ModuloPauId = @Mod_M0001)
    INSERT integracion.PauMenu (SistemaId, PerfilPauId, ModuloPauId, CodigoMenu, NombreMenu, Url, Icono, Orden, Activo)
    VALUES (@SistemaId, @PerfilPauId, @Mod_M0001, 'M0001', N'Seguimiento', N'/seguimiento', N'mdi-account-box', 1, 1);
IF NOT EXISTS (SELECT 1 FROM integracion.PauMenu WHERE SistemaId = @SistemaId AND PerfilPauId = @PerfilPauId AND ModuloPauId = @Mod_M0007)
    INSERT integracion.PauMenu (SistemaId, PerfilPauId, ModuloPauId, CodigoMenu, NombreMenu, Url, Icono, Orden, Activo)
    VALUES (@SistemaId, @PerfilPauId, @Mod_M0007, 'M0007', N'Proyecto', N'/intervencion', N'mdi-folder-edit-outline', 2, 1);
IF NOT EXISTS (SELECT 1 FROM integracion.PauMenu WHERE SistemaId = @SistemaId AND PerfilPauId = @PerfilPauId AND ModuloPauId = @Mod_M0043)
    INSERT integracion.PauMenu (SistemaId, PerfilPauId, ModuloPauId, CodigoMenu, NombreMenu, Url, Icono, Orden, Activo)
    VALUES (@SistemaId, @PerfilPauId, @Mod_M0043, 'M0043', N'Convenio', N'/convenio', N'mdi-folder', 3, 1);
IF NOT EXISTS (SELECT 1 FROM integracion.PauMenu WHERE SistemaId = @SistemaId AND PerfilPauId = @PerfilPauId AND ModuloPauId = @Mod_M1051)
    INSERT integracion.PauMenu (SistemaId, PerfilPauId, ModuloPauId, CodigoMenu, NombreMenu, Url, Icono, Orden, Activo)
    VALUES (@SistemaId, @PerfilPauId, @Mod_M1051, 'M1051', N'Asignar Proyecto', N'/asignarProyecto', N'mdi-folder-account-outline', 4, 1);

/* 3. Operaciones (HasClaim) */
DECLARE @op TABLE (Modulo nvarchar(100), HasClaim varchar(200), Accion varchar(10));
INSERT @op (Modulo, HasClaim, Accion) VALUES
 (@Mod_M0001, 'SSIPEM0001_ejecucion_btn_acciones_adelanto_directo', 'leer'),
 (@Mod_M0001, 'SSIPEM0001_ejecucion_btn_acciones_adelanto_material', 'leer'),
 (@Mod_M0001, 'SSIPEM0001_ejecucion_btn_acciones_adicional_deductivo', 'leer'),
 (@Mod_M0001, 'SSIPEM0001_ejecucion_btn_acciones_ampliacion', 'leer'),
 (@Mod_M0001, 'SSIPEM0001_ejecucion_btn_acciones_conservacion', 'leer'),
 (@Mod_M0001, 'SSIPEM0001_ejecucion_btn_acciones_contrato', 'leer'),
 (@Mod_M0001, 'SSIPEM0001_ejecucion_btn_acciones_cronograma', 'leer'),
 (@Mod_M0001, 'SSIPEM0001_ejecucion_btn_acciones_impedimento', 'leer'),
 (@Mod_M0001, 'SSIPEM0001_ejecucion_btn_acciones_interferencia', 'leer'),
 (@Mod_M0001, 'SSIPEM0001_ejecucion_btn_acciones_liquidacion', 'leer'),
 (@Mod_M0001, 'SSIPEM0001_ejecucion_btn_acciones_mejoramiento', 'leer'),
 (@Mod_M0001, 'SSIPEM0001_ejecucion_btn_acciones_otroplazo', 'leer'),
 (@Mod_M0001, 'SSIPEM0001_ejecucion_btn_acciones_panelfotografico', 'leer'),
 (@Mod_M0001, 'SSIPEM0001_ejecucion_btn_acciones_paralizacion', 'leer'),
 (@Mod_M0001, 'SSIPEM0001_ejecucion_btn_acciones_recepcion', 'leer'),
 (@Mod_M0001, 'SSIPEM0001_ejecucion_btn_acciones_reduccion', 'leer'),
 (@Mod_M0001, 'SSIPEM0001_ejecucion_btn_acciones_resolucion_contrato', 'leer'),
 (@Mod_M0001, 'SSIPEM0001_ejecucion_btn_acciones_responsable', 'leer'),
 (@Mod_M0001, 'SSIPEM0001_ejecucion_btn_acciones_socioambiental', 'leer'),
 (@Mod_M0001, 'SSIPEM0001_ejecucion_btn_acciones_suspension', 'leer'),
 (@Mod_M0001, 'SSIPEM0001_ejecucion_btn_acciones_tramo', 'leer'),
 (@Mod_M0001, 'SSIPEM0001_ejecucion_btn_acciones_transferencia', 'leer'),
 (@Mod_M0001, 'SSIPEM0001_ejecucion_btn_acciones_valorizacion', 'leer'),
 (@Mod_M0001, 'SSIPEM0001_ejecucion_btn_acciones_visita_entidad', 'leer'),
 (@Mod_M0001, 'SSIPEM0001_ejecucion_btn_guardar_adelanto_directo', 'editar'),
 (@Mod_M0001, 'SSIPEM0001_ejecucion_btn_guardar_adelanto_material', 'editar'),
 (@Mod_M0001, 'SSIPEM0001_ejecucion_btn_guardar_adicional_deductivo', 'editar'),
 (@Mod_M0001, 'SSIPEM0001_ejecucion_btn_guardar_ampliacion', 'editar'),
 (@Mod_M0001, 'SSIPEM0001_ejecucion_btn_guardar_contrato', 'editar'),
 (@Mod_M0001, 'SSIPEM0001_ejecucion_btn_guardar_cronograma', 'editar'),
 (@Mod_M0001, 'SSIPEM0001_ejecucion_btn_guardar_impedimento', 'editar'),
 (@Mod_M0001, 'SSIPEM0001_ejecucion_btn_guardar_interferencia', 'editar'),
 (@Mod_M0001, 'SSIPEM0001_ejecucion_btn_guardar_liquidacion', 'editar'),
 (@Mod_M0001, 'SSIPEM0001_ejecucion_btn_guardar_otroplazo', 'editar'),
 (@Mod_M0001, 'SSIPEM0001_ejecucion_btn_guardar_paralizacion', 'editar'),
 (@Mod_M0001, 'SSIPEM0001_ejecucion_btn_guardar_recepcion', 'editar'),
 (@Mod_M0001, 'SSIPEM0001_ejecucion_btn_guardar_reduccion', 'editar'),
 (@Mod_M0001, 'SSIPEM0001_ejecucion_btn_guardar_resolucion_contrato', 'editar'),
 (@Mod_M0001, 'SSIPEM0001_ejecucion_btn_guardar_responsable', 'editar'),
 (@Mod_M0001, 'SSIPEM0001_ejecucion_btn_guardar_suspension', 'editar'),
 (@Mod_M0001, 'SSIPEM0001_ejecucion_btn_guardar_tramo', 'editar'),
 (@Mod_M0001, 'SSIPEM0001_ejecucion_btn_guardar_transferencia', 'editar'),
 (@Mod_M0001, 'SSIPEM0001_ejecucion_btn_guardar_valorizacion', 'editar'),
 (@Mod_M0001, 'SSIPEM0001_ejecucion_btn_guardar_visita_entidad', 'editar'),
 (@Mod_M0001, 'SSIPEM0001_ejecucion_btn_modifica_fecha_real', 'editar'),
 (@Mod_M0001, 'SSIPEM0001_ejecucion_btn_nuevo_adelanto_directo', 'crear'),
 (@Mod_M0001, 'SSIPEM0001_ejecucion_btn_nuevo_adelanto_material', 'crear'),
 (@Mod_M0001, 'SSIPEM0001_ejecucion_btn_nuevo_adicional_deductivo', 'crear'),
 (@Mod_M0001, 'SSIPEM0001_ejecucion_btn_nuevo_ampliacion', 'crear'),
 (@Mod_M0001, 'SSIPEM0001_ejecucion_btn_nuevo_conservacion', 'crear'),
 (@Mod_M0001, 'SSIPEM0001_ejecucion_btn_nuevo_contrato', 'crear'),
 (@Mod_M0001, 'SSIPEM0001_ejecucion_btn_nuevo_cronograma', 'crear'),
 (@Mod_M0001, 'SSIPEM0001_ejecucion_btn_nuevo_impedimento', 'crear'),
 (@Mod_M0001, 'SSIPEM0001_ejecucion_btn_nuevo_interferencia', 'crear'),
 (@Mod_M0001, 'SSIPEM0001_ejecucion_btn_nuevo_liquidacion', 'crear'),
 (@Mod_M0001, 'SSIPEM0001_ejecucion_btn_nuevo_mejoramiento', 'crear'),
 (@Mod_M0001, 'SSIPEM0001_ejecucion_btn_nuevo_otroplazo', 'crear'),
 (@Mod_M0001, 'SSIPEM0001_ejecucion_btn_nuevo_panelfotografico', 'crear'),
 (@Mod_M0001, 'SSIPEM0001_ejecucion_btn_nuevo_paralizacion', 'crear'),
 (@Mod_M0001, 'SSIPEM0001_ejecucion_btn_nuevo_recepcion', 'crear'),
 (@Mod_M0001, 'SSIPEM0001_ejecucion_btn_nuevo_reduccion', 'crear'),
 (@Mod_M0001, 'SSIPEM0001_ejecucion_btn_nuevo_resolucion_contrato', 'crear'),
 (@Mod_M0001, 'SSIPEM0001_ejecucion_btn_nuevo_responsable', 'crear'),
 (@Mod_M0001, 'SSIPEM0001_ejecucion_btn_nuevo_socioambiental', 'crear'),
 (@Mod_M0001, 'SSIPEM0001_ejecucion_btn_nuevo_suspension', 'crear'),
 (@Mod_M0001, 'SSIPEM0001_ejecucion_btn_nuevo_tramo', 'crear'),
 (@Mod_M0001, 'SSIPEM0001_ejecucion_btn_nuevo_transferencia', 'crear'),
 (@Mod_M0001, 'SSIPEM0001_ejecucion_btn_nuevo_valorizacion', 'crear'),
 (@Mod_M0001, 'SSIPEM0001_ejecucion_btn_nuevo_visita_entidad', 'crear'),
 (@Mod_M0001, 'SSIPEM0001_ejecucion_btn_vincular_proceso', 'crear'),
 (@Mod_M0001, 'SSIPEM0001btn_mostrar_seguimiento', 'leer'),
 (@Mod_M0007, 'SSIPEM0007btn_acciones_intervencion', 'leer'),
 (@Mod_M0007, 'SSIPEM0007btn_nueva_intervencion', 'crear'),
 (@Mod_M0043, 'SSIPEM0043btn_acciones_convenio', 'leer'),
 (@Mod_M0043, 'SSIPEM0043btn_nuevo_convenio', 'crear');
INSERT integracion.PauOperacion (SistemaId, PerfilPauId, ModuloPauId, HasClaim, Accion, Activo)
SELECT @SistemaId, @PerfilPauId, o.Modulo, o.HasClaim, o.Accion, 1
FROM @op o
WHERE NOT EXISTS (SELECT 1 FROM integracion.PauOperacion p WHERE p.SistemaId = @SistemaId AND p.PerfilPauId = @PerfilPauId AND p.ModuloPauId = o.Modulo AND p.HasClaim = o.HasClaim);

/* 4. Usuario (IdUsuario/IdArea historicos de SSO; UsuarioAuditoria = documento, como en SSO) */
IF NOT EXISTS (SELECT 1 FROM integracion.PauUsuario WHERE SistemaId = @SistemaId AND UsuarioPauId = @UsuarioPauId AND DependenciaPauId = @DependenciaPauId)
    INSERT integracion.PauUsuario (SistemaId, UsuarioPauId, DependenciaPauId, IdUsuario, IdArea, UsuarioAuditoria, Activo, VigenteHastaUtc, RevisadoPor)
    VALUES (@SistemaId, @UsuarioPauId, @DependenciaPauId, 46, 14, N'42910203', 1, @VigenteHasta, @RevisadoPor);
ELSE UPDATE integracion.PauUsuario SET IdUsuario = 46, IdArea = 14, Activo = 1, VigenteHastaUtc = @VigenteHasta, RevisadoPor = @RevisadoPor, RevisadoUtc = SYSUTCDATETIME()
     WHERE SistemaId = @SistemaId AND UsuarioPauId = @UsuarioPauId AND DependenciaPauId = @DependenciaPauId;

/* 5. Verificacion */
SELECT 'PauPerfil' t, * FROM integracion.PauPerfil WHERE SistemaId = @SistemaId AND PerfilPauId = @PerfilPauId;
SELECT 'PauMenu' t, * FROM integracion.PauMenu WHERE SistemaId = @SistemaId AND PerfilPauId = @PerfilPauId ORDER BY Orden;
SELECT 'PauOperacion' t, COUNT(*) total FROM integracion.PauOperacion WHERE SistemaId = @SistemaId AND PerfilPauId = @PerfilPauId;
SELECT 'PauUsuario' t, * FROM integracion.PauUsuario WHERE SistemaId = @SistemaId AND UsuarioPauId = @UsuarioPauId;

IF @confirmar = 1 BEGIN COMMIT; PRINT 'COMMIT realizado.'; END
ELSE BEGIN ROLLBACK; PRINT 'Simulacion: ROLLBACK. Poner @confirmar = 1 para aplicar.'; END
