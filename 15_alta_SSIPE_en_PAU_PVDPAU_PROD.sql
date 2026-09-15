/* 15 - Registro de SSIPE (DESA local) en el PAU y asignacion del usuario de prueba 42910203
   con perfil COORDINADOR DE OBRA (equivale a SSO P0025).
   Base: PVDPAU_PROD en 10.4.0.20\artemisa20 (DESA del PAU). NO ejecutar en PVDPAU (10.3.0.123).
   Usa los SP de escritura del propio PAU (los que llama su API) para respetar auditoria.
   Idempotente: si el sistema/perfil/rol/modulos/grupo/asignacion ya existen, los reutiliza.
   Salida final: ids necesarios para SSIPE (PauIntegration:SistemaId) y para DBSSIPE2 (script 17).

   Referencia tomada del SPP (sistema 16) para el mismo usuario: DUP con DEN_PK_DETEN=7911 (dependencia vigente,
   DEN_N_INDICA=1) y SIS_N_GRUPO=4 (Misional). SP_SEL_SISTEMA_X_PERMISOS_X_GRUPO lista sistemas por esa dependencia.

   Flujo Manual del PAU: al hacer clic abre SIS_V_LINKSI?unique_code=<GUID>&id_sistemas=<id>. */
SET NOCOUNT ON; SET XACT_ABORT ON;
IF DB_NAME() <> N'PVDPAU_PROD' THROW 50001, 'Seleccionar PVDPAU_PROD (DESA PAU).', 1;
IF CONVERT(nvarchar(128), SERVERPROPERTY('MachineName')) <> N'PVDDEV-BD01' THROW 50002, 'Solo servidor DESA PVDDEV-BD01 (Artemisa20).', 1;

DECLARE @confirmar       bit = 0;                  -- 1 = COMMIT, 0 = simula y hace ROLLBACK
DECLARE @nombreSistema   varchar(255) = 'SSIPE (DESA local)';
DECLARE @linkCallback    varchar(255) = 'http://localhost:4200/pau/callback';
DECLARE @tituloSistema   varchar(255) = 'Sistema de Seguimiento de Intervenciones Por Encargo';
DECLARE @grupoSistema    int = 4;                  -- I_GRUPO_SISTEMA: 4 = Misional (donde aparece el SPP)
DECLARE @grupoGeneral    int = 2;                  -- A_GRUPOS_GENERAL_GRP: 2 = Pvd
DECLARE @nombrePerfil    varchar(255) = 'COORDINADOR DE OBRA';
DECLARE @codigoRol       varchar(255) = 'P0025';   -- mismo codigo que SSO
DECLARE @usuarioPrueba   int = 4604;               -- USU_PK_USUAR del DNI 42910203
DECLARE @dependencia     int = 7911;               -- DEN_PK_DETEN vigente del usuario (DEN_N_INDICA=1)
DECLARE @usuAuditoria    int = 1;                  -- usuario administrador que registra
DECLARE @r TABLE (UltimoId int, Mensaje varchar(255), Ok int);

IF NOT EXISTS (SELECT 1 FROM I_DETALLE_ENTIDAD_DEN WHERE DEN_PK_DETEN = @dependencia AND DEN_FK_USUAR = @usuarioPrueba AND DEN_B_ESTADO = 1 AND DEN_N_INDICA = 1)
    THROW 50003, 'La dependencia indicada no es la vigente del usuario; revisar I_DETALLE_ENTIDAD_DEN.', 1;

BEGIN TRANSACTION;

/* 1. Sistema */
DECLARE @sis int = (SELECT TOP 1 SIS_PK_SISTEM FROM I_SISTEMA_SIS WHERE SIS_V_NOMSIS = @nombreSistema);
IF @sis IS NULL
BEGIN
    DELETE @r;
    INSERT @r EXEC SP_INS_SISTEMAS @P_V_SIS_V_NOMSIS = @nombreSistema, @P_V_SIS_V_LINKSI = @linkCallback, @P_V_SIS_V_TITULO = @tituloSistema,
        @P_V_SIS_V_ICONOS = 'heroicons_outline:clipboard-document-check', @P_V_SIS_V_TITLOG = 'SSIPE', @P_V_SIS_V_AUTORS = 'PVD',
        @P_N_SIS_N_USUCRE = @usuAuditoria, @P_N_SIS_N_INDICA = 1, @P_N_SIS_V_RUTARC = 'Configuracion/Sistemas/', @P_N_SIS_V_NOMARC = '',
        @P_V_SIS_V_DESLAR = 'SSIPE desarrollo local (front 4200 / back 5105)', @P_V_SIS_N_GRUPO = @grupoSistema, @P_N_SIS_N_EXTERN = 0;
    SELECT @sis = UltimoId FROM @r WHERE Ok = 1;
    IF @sis IS NULL OR @sis = 0 THROW 50010, 'SP_INS_SISTEMAS fallo.', 1;
    PRINT CONCAT('Sistema creado: ', @sis);
END
ELSE
BEGIN
    UPDATE I_SISTEMA_SIS SET SIS_V_LINKSI = @linkCallback, SIS_B_ESTADO = 1, SIS_N_INDICA = 1, SIS_N_GRUPO = @grupoSistema WHERE SIS_PK_SISTEM = @sis;
    PRINT CONCAT('Sistema ya existia: ', @sis);
END

/* 2. Perfil (por sistema) */
DECLARE @per int = (SELECT TOP 1 PER_PK_PERFI FROM A_PERFIL_PER WHERE PER_FK_SISTE = @sis AND UPPER(PER_V_DESCRI) = @nombrePerfil AND PER_B_ESTADO = 1);
IF @per IS NULL
BEGIN
    DELETE @r;
    INSERT @r EXEC SP_INS_PERFIL @P_PER_FK_SISTE = @sis, @P_PER_V_DESCRI = @nombrePerfil, @P_PER_B_PRITOT = 0, @P_PER_B_PRISEL = 1,
        @P_PER_B_PRIINS = 1, @P_PER_B_PRIUPD = 1, @P_PER_B_PRIDEL = 0, @P_PER_N_INDICA = 1, @P_PER_N_USUCRE = @usuAuditoria, @P_PER_N_EXTERN = 0;
    SELECT @per = UltimoId FROM @r WHERE Ok = 1;
    IF @per IS NULL OR @per = 0 THROW 50011, 'SP_INS_PERFIL fallo.', 1;
    PRINT CONCAT('Perfil creado: ', @per);
END ELSE PRINT CONCAT('Perfil ya existia: ', @per);

/* 3. Rol (agrupa los modulos del menu) */
DECLARE @rol int = (SELECT TOP 1 ROL_PK_ROLES FROM I_ROLES_ROL WHERE ROL_FK_SISTE = @sis AND ROL_V_CODIGO = @codigoRol AND ROL_B_ESTADO = 1);
IF @rol IS NULL
BEGIN
    DELETE @r;
    INSERT @r EXEC SP_INS_ROLES @P_ROL_FK_SISTE = @sis, @P_ROL_V_DESCRI = @nombrePerfil, @P_ROL_V_CODIGO = @codigoRol,
        @P_ROL_N_INDICA = 1, @P_ROL_N_USUCRE = @usuAuditoria, @P_ROL_N_EXTERN = 0;
    SELECT @rol = UltimoId FROM @r WHERE Ok = 1;
    IF @rol IS NULL OR @rol = 0 THROW 50012, 'SP_INS_ROLES fallo.', 1;
    PRINT CONCAT('Rol creado: ', @rol);
END ELSE PRINT CONCAT('Rol ya existia: ', @rol);

/* 4. Modulos = menu de P0025 en SSO (MOD_V_DESLAR guarda el CodigoMenu SSO para la homologacion) */
DECLARE @mods TABLE (Codigo varchar(10), Nombre varchar(255), Url varchar(255), Icono varchar(100), Orden int);
INSERT @mods VALUES
 ('M0001', 'Seguimiento',      '/seguimiento',     'heroicons_outline:clipboard-document-list', 1),
 ('M0007', 'Proyecto',         '/intervencion',    'heroicons_outline:folder',                  2),
 ('M0043', 'Convenio',         '/convenio',        'heroicons_outline:document-text',           3),
 ('M1051', 'Asignar Proyecto', '/asignarProyecto', 'heroicons_outline:user-plus',               4);
DECLARE @codigo varchar(10), @nombre varchar(255), @url varchar(255), @icono varchar(100), @orden int, @mod int;
DECLARE cur CURSOR LOCAL FAST_FORWARD FOR SELECT Codigo, Nombre, Url, Icono, Orden FROM @mods ORDER BY Orden;
OPEN cur; FETCH NEXT FROM cur INTO @codigo, @nombre, @url, @icono, @orden;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @mod = (SELECT TOP 1 MOD_PK_MODUL FROM I_MODULO_MOD WHERE MOD_FK_SISTE = @sis AND MOD_V_DESLAR = @codigo AND MOD_B_ESTADO = 1);
    IF @mod IS NULL
    BEGIN
        DELETE @r;
        INSERT @r EXEC SP_INS_MODULO @P_MOD_V_DESCOR = @nombre, @P_MOD_FK_TIPMO = 2, @P_MOD_V_ICONOX = @icono, @P_MOD_N_NIVELX = 1,
            @P_MOD_N_ORDENX = @orden, @P_MOD_V_URLMOD = @url, @P_MOD_FK_MODUL = NULL, @P_MOD_V_DESLAR = @codigo, @P_MOD_N_INDICA = 1,
            @P_MOD_N_USUCRE = @usuAuditoria, @P_MOD_FK_SISTE = @sis;
        SELECT @mod = UltimoId FROM @r WHERE Ok = 1;
        IF @mod IS NULL OR @mod = 0 THROW 50013, 'SP_INS_MODULO fallo.', 1;
        PRINT CONCAT('Modulo creado: ', @codigo, ' -> ', @mod);
    END ELSE PRINT CONCAT('Modulo ya existia: ', @codigo, ' -> ', @mod);
    IF NOT EXISTS (SELECT 1 FROM I_DETALLE_ROL_DRL WHERE DRL_FK_ROLES = @rol AND DRL_FK_MODUL = @mod AND DRL_B_ESTADO = 1)
    BEGIN
        DELETE @r;
        INSERT @r EXEC SP_INS_DETROL @P_DRL_FK_ROLES = @rol, @P_DRL_FK_MODUL = @mod, @P_DRL_N_USUCRE = @usuAuditoria;
        IF NOT EXISTS (SELECT 1 FROM @r WHERE Ok = 1) THROW 50014, 'SP_INS_DETROL fallo.', 1;
    END
    FETCH NEXT FROM cur INTO @codigo, @nombre, @url, @icono, @orden;
END
CLOSE cur; DEALLOCATE cur;

/* 5. Grupo perfil/rol */
DECLARE @rolCsv varchar(max) = CONVERT(varchar(20), @rol);
DECLARE @gpr int = (SELECT TOP 1 GPR_PK_GPFRL FROM I_GRUPO_PERF_ROL_GPR WHERE GPR_FK_SISTE = @sis AND GPR_FK_PERFI = @per AND GPR_B_ESTADO = 1);
IF @gpr IS NULL
BEGIN
    DELETE @r;
    INSERT @r EXEC SP_INS_GRUPO_PERF_ROL @GPR_V_TITULO = @nombrePerfil, @GPR_V_DESLAR = 'Coordinador de obra SSIPE (homologa SSO P0025)',
        @GPR_V_ICONOX = 'home', @GPR_FK_SISTE = @sis, @GPR_FK_PERFI = @per, @GPR_FK_ROLES = @rolCsv, @GPR_FK_GRGEN = @grupoGeneral,
        @GPR_PK_GRPUZ = NULL, @GPR_N_INDICA = 1, @GPR_N_USUCRE = @usuAuditoria, @GPR_N_EXTERN = 0;
    SELECT @gpr = UltimoId FROM @r WHERE Ok = 1;
    IF @gpr IS NULL OR @gpr = 0 THROW 50015, 'SP_INS_GRUPO_PERF_ROL fallo.', 1;
    PRINT CONCAT('Grupo perfil/rol creado: ', @gpr);
END
ELSE
BEGIN
    UPDATE I_GRUPO_PERF_ROL_GPR SET GPR_FK_ROLES = @rolCsv WHERE GPR_PK_GPFRL = @gpr AND ISNULL(GPR_FK_ROLES, '') <> @rolCsv;
    PRINT CONCAT('Grupo perfil/rol ya existia: ', @gpr);
END

/* 6. Asignacion usuario x sistema x dependencia -> grupo */
IF NOT EXISTS (SELECT 1 FROM I_DET_USUARIOS_PERMISOS_DUP WHERE DUP_FK_SISTE = @sis AND DUP_FK_DETEN = @dependencia AND DUP_FK_USUAR = @usuarioPrueba AND DUP_N_INDICA = 1)
BEGIN
    DELETE @r;
    INSERT @r EXEC SP_INS_DET_USUARIOS_PERMISOS @P_DUP_FK_SISTE = @sis, @P_DUP_FK_DETEN = @dependencia, @P_DUP_FK_USUAR = @usuarioPrueba,
        @P_DUP_FK_GPRRL = @gpr, @P_DUP_N_INDICA = 1, @P_DUP_N_USUCRE = @usuAuditoria;
    IF NOT EXISTS (SELECT 1 FROM @r WHERE Ok = 1) THROW 50016, 'SP_INS_DET_USUARIOS_PERMISOS fallo.', 1;
    PRINT 'Asignacion creada.';
END
ELSE
BEGIN
    UPDATE I_DET_USUARIOS_PERMISOS_DUP SET DUP_FK_GPRRL = @gpr, DUP_B_ESTADO = 1
     WHERE DUP_FK_SISTE = @sis AND DUP_FK_DETEN = @dependencia AND DUP_FK_USUAR = @usuarioPrueba AND DUP_N_INDICA = 1;
    PRINT 'Asignacion ya existia (actualizada al grupo).';
END

/* 7. Verificacion: lo mismo que ejecuta el PAU al listar apps y al canjear el ticket para SSIPE */
SELECT 'resumen' AS q, @sis AS SistemaId, @per AS PerfilPauId, @rol AS RolPauId, @gpr AS GrupoPerfilRolId, @usuarioPrueba AS UsuarioPauId, @dependencia AS DependenciaPauId;
SELECT 'modulos' AS q, MOD_V_DESLAR AS CodigoMenuSSO, MOD_PK_MODUL AS ModuloPauId, MOD_V_DESCOR, MOD_V_URLMOD, MOD_N_ORDENX FROM I_MODULO_MOD WHERE MOD_FK_SISTE = @sis AND MOD_B_ESTADO = 1 ORDER BY MOD_N_ORDENX;
EXEC SP_SEL_SISTEMA_X_PERMISOS_X_GRUPO @USU_PK_USUAR = @usuarioPrueba, @SIS_N_GRUPO = @grupoSistema;
EXEC SP_SEL_DET_USUARIOS_PERMISOS_ID_USU_SIS @P_DUP_FK_USUAR = @usuarioPrueba, @P_DUP_FK_SISTE = @sis, @P_DUP_FK_DETEN = @dependencia;
EXEC SP_SEL_GRUPO_PER_ROL_ID_AUTH @P_GPR_PK_GPFRL = @gpr;
EXEC SP_SEL_DETALLE_ROL_IDROL @P_N_DRL_FK_ROLES = @rolCsv;

IF @confirmar = 1 BEGIN COMMIT; PRINT 'COMMIT realizado.'; END
ELSE BEGIN ROLLBACK; PRINT 'Simulacion: ROLLBACK. Poner @confirmar = 1 para aplicar.'; END
