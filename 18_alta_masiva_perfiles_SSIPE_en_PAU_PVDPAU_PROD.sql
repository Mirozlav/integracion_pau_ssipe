/* 18 - Alta masiva en PAU (PVDPAU_PROD, DESA) de los perfiles SSIPE que faltan: perfil + rol + modulos del rol + grupo perfil/rol.
   Generado el 17/09/2026 desde evidencias/privado/16_export_SSO_ssipe.json. P0025 (COORDINADOR DE OBRA) se omite: ya existe (PerfilPauId 2034).
   Sistema SSIPE en PAU = 2020. Modulos existentes: M0001=2182, M0007=2183, M0043=2184, M1051=2185.
   Flags del perfil PAU derivados de los claims que el perfil tiene en SSO (leer->PRISEL, crear->PRIINS, editar->PRIUPD, eliminar->PRIDEL),
   porque paResolverSesionPau filtra por ellos mientras no se aplique la Fase 1 de PROPUESTA_CLAIMS_BOTONERIA_PAU.md.
   Idempotente (reutiliza lo existente por nombre/codigo). @confirmar=0 simula y hace ROLLBACK.
   Marcar Activar=1 SOLO en los perfiles aprobados por el dueno funcional.
   Las asignaciones a usuarios van aparte (18b, con DNIs, fuera de git). */
SET NOCOUNT ON; SET XACT_ABORT ON;
IF DB_NAME() <> N'PVDPAU_PROD' THROW 50001, 'Seleccionar PVDPAU_PROD (DESA PAU).', 1;
IF CONVERT(nvarchar(128), SERVERPROPERTY('MachineName')) <> N'PVDDEV-BD01' THROW 50002, 'Solo servidor DESA PVDDEV-BD01 (Artemisa20).', 1;

DECLARE @confirmar bit = 0;
DECLARE @sis int = 2020, @grupoGeneral int = 2, @usuAuditoria int = 1;
DECLARE @r TABLE (UltimoId int, Mensaje varchar(255), Ok int);

DECLARE @perfiles TABLE (Activar bit, CodigoSSO varchar(10), Nombre varchar(255), IdPerfilSSO int,
    PRISEL bit, PRIINS bit, PRIUPD bit, PRIDEL bit, Menus varchar(100), Claims int, UsuariosSSO int);
INSERT @perfiles (Activar, CodigoSSO, Nombre, IdPerfilSSO, PRISEL, PRIINS, PRIUPD, PRIDEL, Menus, Claims, UsuariosSSO) VALUES
 (1, 'P0001', N'ADMINISTRADOR', 1, 1, 1, 1, 0, 'M0001,M0007,M0043,M1051', 137, 6),
 (0, 'P0021', N'GERENTE DE OBRA', 28, 1, 1, 0, 0, 'M0001,M0007,M0043', 2, 0),
 (0, 'P0022', N'JEFE DE OBRA', 29, 1, 1, 0, 0, 'M0001,M0007,M0043', 2, 0),
 (1, 'P0023', N'ADMINISTRADOR DE CONTRATO DE OBRA', 30, 1, 1, 1, 0, 'M0001,M0007,M0043', 136, 1),
 (1, 'P0024', N'SUPERVISOR DE OBRA', 31, 1, 1, 0, 0, 'M0001,M0007,M0043', 10, 3),
 (0, 'P0027', N'COORDINADOR EXPEDIENTE', 34, 1, 1, 1, 0, 'M0001,M0007,M0043,M1051', 39, 0),
 (0, 'P0028', N'ESPECIALISTA DE EXPEDIENTE', 35, 1, 1, 1, 0, 'M0001,M0007,M0043', 34, 0),
 (0, 'P0029', N'ESPECIALISTA PREINVERSION', 36, 1, 1, 1, 1, 'M0001,M0007,M0043', 32, 0),
 (0, 'P0041', N'RESPONSABLE EXPEDIENTE TECNICO', 1047, 0, 0, 0, 0, 'M0001', 0, 0),
 (0, 'P0042', N'RESPONSABLE PACRI', 1048, 1, 0, 1, 0, 'M0001', 2, 0),
 (0, 'P0043', N'RESPONSABLE EJECUCION', 1049, 1, 1, 1, 0, 'M0001', 89, 0),
 (0, 'P0044', N'COORDINADOR PATS', 1050, 1, 1, 1, 0, 'M0001,M0007,M0043,M1051', 152, 1),
 (0, 'P0045', N'LECTOR GENERAL', 1051, 0, 0, 0, 0, 'M0001', 0, 1),
 (0, 'P0046', N'RESPONSABLE ABASTECIMIENTO', 1052, 0, 0, 0, 0, 'M0001', 0, 0);

IF EXISTS (SELECT 1 FROM @perfiles WHERE Activar = 1 AND Menus = '')
    PRINT 'AVISO: hay perfiles activados sin menu en SSO; se crearan sin modulos (no veran nada en SSIPE).';

DECLARE @mod TABLE (CodigoMenu varchar(10), ModuloPauId int);
INSERT @mod VALUES ('M0001', 2182), ('M0007', 2183), ('M0043', 2184), ('M1051', 2185);
IF (SELECT COUNT(*) FROM I_MODULO_MOD WHERE MOD_PK_MODUL IN (SELECT ModuloPauId FROM @mod) AND MOD_FK_SISTE = @sis AND MOD_B_ESTADO = 1) <> 4
    THROW 50003, 'Los 4 modulos SSIPE (2182-2185) no estan completos en PAU; ejecutar antes el script 15.', 1;

DECLARE @resultado TABLE (CodigoSSO varchar(10), Nombre varchar(255), PerfilPauId int, RolPauId int, GrupoPerfilRolId int, Estado varchar(30));
BEGIN TRANSACTION;

DECLARE @c varchar(10), @n varchar(255), @sel bit, @ins bit, @upd bit, @del bit, @menus varchar(100);
DECLARE @per int, @rol int, @gpr int, @rolCsv varchar(20), @estado varchar(30);
DECLARE cur CURSOR LOCAL FAST_FORWARD FOR SELECT CodigoSSO, Nombre, PRISEL, PRIINS, PRIUPD, PRIDEL, Menus FROM @perfiles WHERE Activar = 1 ORDER BY CodigoSSO;
OPEN cur; FETCH NEXT FROM cur INTO @c, @n, @sel, @ins, @upd, @del, @menus;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @estado = 'existia';
    /* perfil */
    SET @per = (SELECT TOP 1 PER_PK_PERFI FROM A_PERFIL_PER WHERE PER_FK_SISTE = @sis AND UPPER(PER_V_DESCRI) = UPPER(@n) AND PER_B_ESTADO = 1);
    IF @per IS NULL
    BEGIN
        DELETE @r;
        INSERT @r EXEC SP_INS_PERFIL @P_PER_FK_SISTE = @sis, @P_PER_V_DESCRI = @n, @P_PER_B_PRITOT = 0, @P_PER_B_PRISEL = @sel,
            @P_PER_B_PRIINS = @ins, @P_PER_B_PRIUPD = @upd, @P_PER_B_PRIDEL = @del, @P_PER_N_INDICA = 1, @P_PER_N_USUCRE = @usuAuditoria, @P_PER_N_EXTERN = 0;
        SELECT @per = UltimoId FROM @r WHERE Ok = 1;
        IF ISNULL(@per, 0) = 0 THROW 50011, 'SP_INS_PERFIL fallo.', 1;
        SET @estado = 'creado';
    END
    /* rol (codigo = codigo SSO) */
    SET @rol = (SELECT TOP 1 ROL_PK_ROLES FROM I_ROLES_ROL WHERE ROL_FK_SISTE = @sis AND ROL_V_CODIGO = @c AND ROL_B_ESTADO = 1);
    IF @rol IS NULL
    BEGIN
        DELETE @r;
        INSERT @r EXEC SP_INS_ROLES @P_ROL_FK_SISTE = @sis, @P_ROL_V_DESCRI = @n, @P_ROL_V_CODIGO = @c, @P_ROL_N_INDICA = 1, @P_ROL_N_USUCRE = @usuAuditoria, @P_ROL_N_EXTERN = 0;
        SELECT @rol = UltimoId FROM @r WHERE Ok = 1;
        IF ISNULL(@rol, 0) = 0 THROW 50012, 'SP_INS_ROLES fallo.', 1;
    END
    /* modulos del rol: solo los menus que el perfil ve en SSO */
    INSERT I_DETALLE_ROL_DRL (DRL_FK_ROLES, DRL_FK_MODUL, DRL_N_USUCRE, DRL_D_FECCRE)
    SELECT @rol, m.ModuloPauId, @usuAuditoria, CURRENT_TIMESTAMP
    FROM @mod m
    WHERE m.CodigoMenu IN (SELECT value FROM STRING_SPLIT(@menus, ','))
      AND NOT EXISTS (SELECT 1 FROM I_DETALLE_ROL_DRL d WHERE d.DRL_FK_ROLES = @rol AND d.DRL_FK_MODUL = m.ModuloPauId AND d.DRL_B_ESTADO = 1);
    /* grupo perfil/rol */
    SET @rolCsv = CONVERT(varchar(20), @rol);
    SET @gpr = (SELECT TOP 1 GPR_PK_GPFRL FROM I_GRUPO_PERF_ROL_GPR WHERE GPR_FK_SISTE = @sis AND GPR_FK_PERFI = @per AND GPR_B_ESTADO = 1);
    IF @gpr IS NULL
    BEGIN
        DELETE @r;
        INSERT @r EXEC SP_INS_GRUPO_PERF_ROL @GPR_V_TITULO = @n, @GPR_V_DESLAR = @n, @GPR_V_ICONOX = 'home', @GPR_FK_SISTE = @sis,
            @GPR_FK_PERFI = @per, @GPR_FK_ROLES = @rolCsv, @GPR_FK_GRGEN = @grupoGeneral, @GPR_PK_GRPUZ = NULL, @GPR_N_INDICA = 1,
            @GPR_N_USUCRE = @usuAuditoria, @GPR_N_EXTERN = 0;
        SELECT @gpr = UltimoId FROM @r WHERE Ok = 1;
        IF ISNULL(@gpr, 0) = 0 THROW 50015, 'SP_INS_GRUPO_PERF_ROL fallo.', 1;
    END
    ELSE UPDATE I_GRUPO_PERF_ROL_GPR SET GPR_FK_ROLES = @rolCsv WHERE GPR_PK_GPFRL = @gpr AND ISNULL(GPR_FK_ROLES, '') <> @rolCsv;
    INSERT @resultado VALUES (@c, @n, @per, @rol, @gpr, @estado);
    FETCH NEXT FROM cur INTO @c, @n, @sel, @ins, @upd, @del, @menus;
END
CLOSE cur; DEALLOCATE cur;

/* Salida: copiar CodigoSSO -> PerfilPauId en el script 19 (@map) */
SELECT 'resultado' AS q, * FROM @resultado ORDER BY CodigoSSO;
SELECT 'no_activados' AS q, CodigoSSO, Nombre, Menus, Claims, UsuariosSSO FROM @perfiles WHERE Activar = 0 ORDER BY CodigoSSO;

IF @confirmar = 1 BEGIN COMMIT; PRINT 'COMMIT realizado.'; END
ELSE BEGIN ROLLBACK; PRINT 'Simulacion: ROLLBACK. Poner @confirmar = 1 para aplicar.'; END
