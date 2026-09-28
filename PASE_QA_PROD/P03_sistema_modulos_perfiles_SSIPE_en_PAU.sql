/*
================================================================================
 P03 - SSIPE en el PAU del ambiente: sistema + modulos + perfiles/roles/grupos
================================================================================
 QUE ES
   Version portable (QA/PROD, y DESA para perfiles nuevos) de los scripts 15 y
   18. Deja en el PAU todo lo que SSIPE necesita, SIN asignar usuarios (eso es
   el 24):
     1) Sistema SSIPE (si no se indica @sistemaId, lo busca por nombre o lo crea
        con SIS_V_LINKSI = @linkCallback). Si ya existe NO cambia su link.
     2) Modulos M0001 Seguimiento, M0007 Proyecto, M0043 Convenio y
        M1051 Asignar Proyecto (MOD_V_DESLAR = codigo de menu SSIPE).
     3) Perfiles con su rol (ROL_V_CODIGO = codigo SSIPE), modulos del rol y
        grupo perfil/rol. Los flags PRISEL/PRIINS/PRIUPD/PRIDEL filtran los
        claims que SSIPE entrega en la sesion (27: accesos.leer/crear/...).
   Usa los SP de escritura del propio PAU (auditoria), igual que 15 y 18.
   Idempotente: reutiliza por nombre de perfil / codigo de rol / codigo de modulo.

 PERFILES (Activar = 1 los que van al pase)
   P0001 ADMINISTRADOR                     M0001,M0007,M0043,M1051  SEL INS UPD
   P0023 ADMINISTRADOR DE CONTRATO DE OBRA M0001,M0007,M0043        SEL INS UPD
   P0024 SUPERVISOR DE OBRA                M0001,M0007,M0043        SEL INS
   P0025 COORDINADOR DE OBRA               M0001,M0007,M0043,M1051  SEL INS UPD
   P0028 ESPECIALISTA DE EXPEDIENTE         M0001,M0007,M0043        SEL INS UPD
   P0029 ESPECIALISTA PREINVERSION          M0001,M0007,M0043        SEL INS UPD DEL
   P0045 LECTOR GENERAL (perfil "Seguimiento" del area usuaria)
                                           M0001,M0007,M0043        SEL
         Solo lectura: ve los menus y la data (los listados no lo restringen a
         proyectos asignados, igual que al administrador) pero no registra
         nada: en SSIPE no tiene claims (ni siquiera btn_acciones_*, que en el
         front habilitan Editar/Eliminar) y en PAU solo tiene PRISEL. Mismo
         codigo e IdPerfil (1051) que el P0045 del SSO: queda homologado.
         Sin M1051 (Asignar Proyecto es escritura).

 SALIDA
   'resultado' -> CodigoSSO / PerfilPauId  : completar @map de P02
   'modulos'   -> CodigoMenu / ModuloPauId : completar @modulo de P02
   'sistema'   -> SistemaId                : P02, 24, 25 y PauIntegration:SistemaId

 DONDE SE EJECUTA
   Base del PAU del ambiente (DESA: PVDPAU_PROD en 10.4.0.20\artemisa20, con
   @sistemaId = 2020). En PROD lo corre el equipo PAU/OTI.
   @confirmar = 0 simula (ROLLBACK).
================================================================================
*/
SET NOCOUNT ON; SET XACT_ABORT ON;
IF DB_NAME() <> N'<<<BASE_PAU_DEL_AMBIENTE>>>'   -- <<< DESA: PVDPAU_PROD ; PROD: confirmar con OTI
BEGIN RAISERROR(N'Base incorrecta: ejecucion cancelada (editar la guarda con la base PAU del ambiente).', 16, 1); SET NOEXEC ON; END
GO
DECLARE @confirmar     bit = 0;
DECLARE @sistemaId     int = NULL;            -- <<< DESA: 2020. PROD: NULL si aun no existe (se busca por nombre o se crea)
DECLARE @nombreSistema varchar(255) = 'SSIPE';
DECLARE @linkCallback  varchar(255) = 'https://<<<URL_FRONT_SSIPE_PROD>>>/pau/callback';   -- solo se usa si se crea el sistema
DECLARE @tituloSistema varchar(255) = 'Sistema de Seguimiento de Intervenciones Por Encargo';
DECLARE @grupoSistema  int = 4;               -- I_GRUPO_SISTEMA: 4 = Misional (verificar en el ambiente)
DECLARE @grupoGeneral  int = 2;               -- A_GRUPOS_GENERAL_GRP: 2 = Pvd (verificar en el ambiente)
DECLARE @usuAuditoria  int = 1;               -- USU_PK_USUAR del administrador que registra

DECLARE @perfiles TABLE (Activar bit, CodigoSSO varchar(10), Nombre varchar(255),
    PRISEL bit, PRIINS bit, PRIUPD bit, PRIDEL bit, Menus varchar(100), Descripcion varchar(255));
INSERT @perfiles VALUES
 (1, 'P0001', 'ADMINISTRADOR',                     1, 1, 1, 0, 'M0001,M0007,M0043,M1051', 'Administrador SSIPE (homologa SSO P0001)'),
 (1, 'P0023', 'ADMINISTRADOR DE CONTRATO DE OBRA', 1, 1, 1, 0, 'M0001,M0007,M0043',       'Administrador de contrato SSIPE (homologa SSO P0023)'),
 (1, 'P0024', 'SUPERVISOR DE OBRA',                1, 1, 0, 0, 'M0001,M0007,M0043',       'Supervisor de obra SSIPE (homologa SSO P0024)'),
 (1, 'P0025', 'COORDINADOR DE OBRA',               1, 1, 1, 0, 'M0001,M0007,M0043,M1051', 'Coordinador de obra SSIPE (homologa SSO P0025)'),
 (1, 'P0028', 'ESPECIALISTA DE EXPEDIENTE',         1, 1, 1, 0, 'M0001,M0007,M0043',       'Especialista de Expediente SSIPE (homologa SSO P0028)'),
 (1, 'P0029', 'ESPECIALISTA PREINVERSION',          1, 1, 1, 1, 'M0001,M0007,M0043',       'Especialista Preinversion SSIPE (homologa SSO P0029)'),
 (1, 'P0045', 'LECTOR GENERAL',                    1, 0, 0, 0, 'M0001,M0007,M0043',       'Seguimiento - solo lectura SSIPE (homologa SSO P0045)');

DECLARE @mods TABLE (Codigo varchar(10), Nombre varchar(255), Url varchar(255), Icono varchar(100), Orden int);
INSERT @mods VALUES
 ('M0001', 'Seguimiento',      '/seguimiento',     'heroicons_outline:clipboard-document-list', 1),
 ('M0007', 'Proyecto',         '/intervencion',    'heroicons_outline:folder',                  2),
 ('M0043', 'Convenio',         '/convenio',        'heroicons_outline:document-text',           3),
 ('M1051', 'Asignar Proyecto', '/asignarProyecto', 'heroicons_outline:user-plus',               4);

DECLARE @r TABLE (UltimoId int, Mensaje varchar(255), Ok int);
DECLARE @resultado TABLE (CodigoSSO varchar(10), Nombre varchar(255), PerfilPauId int, RolPauId int, GrupoPerfilRolId int,
    PRISEL bit, PRIINS bit, PRIUPD bit, PRIDEL bit, Menus varchar(100), Estado varchar(60));

BEGIN TRANSACTION;

/* 1. Sistema */
IF @sistemaId IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT 1 FROM I_SISTEMA_SIS WHERE SIS_PK_SISTEM = @sistemaId)
        THROW 53001, 'El @sistemaId indicado no existe en este PAU.', 1;
END
ELSE
BEGIN
    SET @sistemaId = (SELECT TOP 1 SIS_PK_SISTEM FROM I_SISTEMA_SIS WHERE SIS_V_NOMSIS = @nombreSistema ORDER BY SIS_PK_SISTEM);
    IF @sistemaId IS NULL
    BEGIN
        IF @linkCallback LIKE '%<<<%' THROW 53002, 'Completar @linkCallback con la URL del front SSIPE del ambiente + /pau/callback.', 1;
        DELETE @r;
        INSERT @r EXEC SP_INS_SISTEMAS @P_V_SIS_V_NOMSIS = @nombreSistema, @P_V_SIS_V_LINKSI = @linkCallback, @P_V_SIS_V_TITULO = @tituloSistema,
            @P_V_SIS_V_ICONOS = 'heroicons_outline:clipboard-document-check', @P_V_SIS_V_TITLOG = 'SSIPE', @P_V_SIS_V_AUTORS = 'PVD',
            @P_N_SIS_N_USUCRE = @usuAuditoria, @P_N_SIS_N_INDICA = 1, @P_N_SIS_V_RUTARC = 'Configuracion/Sistemas/', @P_N_SIS_V_NOMARC = '',
            @P_V_SIS_V_DESLAR = @tituloSistema, @P_V_SIS_N_GRUPO = @grupoSistema, @P_N_SIS_N_EXTERN = 0;
        SELECT @sistemaId = UltimoId FROM @r WHERE Ok = 1;
        IF ISNULL(@sistemaId, 0) = 0 THROW 53003, 'SP_INS_SISTEMAS fallo.', 1;
        PRINT CONCAT('Sistema creado: ', @sistemaId);
    END
END

/* 2. Modulos */
DECLARE @codigo varchar(10), @nombre varchar(255), @url varchar(255), @icono varchar(100), @orden int, @mod int;
DECLARE cm CURSOR LOCAL FAST_FORWARD FOR SELECT Codigo, Nombre, Url, Icono, Orden FROM @mods ORDER BY Orden;
OPEN cm; FETCH NEXT FROM cm INTO @codigo, @nombre, @url, @icono, @orden;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @mod = (SELECT TOP 1 MOD_PK_MODUL FROM I_MODULO_MOD WHERE MOD_FK_SISTE = @sistemaId AND MOD_V_DESLAR = @codigo AND MOD_B_ESTADO = 1);
    IF @mod IS NULL
    BEGIN
        DELETE @r;
        INSERT @r EXEC SP_INS_MODULO @P_MOD_V_DESCOR = @nombre, @P_MOD_FK_TIPMO = 2, @P_MOD_V_ICONOX = @icono, @P_MOD_N_NIVELX = 1,
            @P_MOD_N_ORDENX = @orden, @P_MOD_V_URLMOD = @url, @P_MOD_FK_MODUL = NULL, @P_MOD_V_DESLAR = @codigo, @P_MOD_N_INDICA = 1,
            @P_MOD_N_USUCRE = @usuAuditoria, @P_MOD_FK_SISTE = @sistemaId;
        SELECT @mod = UltimoId FROM @r WHERE Ok = 1;
        IF ISNULL(@mod, 0) = 0 THROW 53004, 'SP_INS_MODULO fallo.', 1;
    END
    FETCH NEXT FROM cm INTO @codigo, @nombre, @url, @icono, @orden;
END
CLOSE cm; DEALLOCATE cm;

/* 3. Perfiles + rol + modulos del rol + grupo perfil/rol */
DECLARE @c varchar(10), @n varchar(255), @sel bit, @ins bit, @upd bit, @del bit, @menus varchar(100), @desc varchar(255);
DECLARE @per int, @rol int, @gpr int, @rolCsv varchar(20), @estado varchar(60), @menu varchar(10);
DECLARE cp CURSOR LOCAL FAST_FORWARD FOR
    SELECT CodigoSSO, Nombre, PRISEL, PRIINS, PRIUPD, PRIDEL, Menus, Descripcion FROM @perfiles WHERE Activar = 1 ORDER BY CodigoSSO;
OPEN cp; FETCH NEXT FROM cp INTO @c, @n, @sel, @ins, @upd, @del, @menus, @desc;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @estado = 'existia';
    SET @per = (SELECT TOP 1 PER_PK_PERFI FROM A_PERFIL_PER WHERE PER_FK_SISTE = @sistemaId AND UPPER(PER_V_DESCRI) = UPPER(@n) AND PER_B_ESTADO = 1);
    IF @per IS NULL
    BEGIN
        DELETE @r;
        INSERT @r EXEC SP_INS_PERFIL @P_PER_FK_SISTE = @sistemaId, @P_PER_V_DESCRI = @n, @P_PER_B_PRITOT = 0, @P_PER_B_PRISEL = @sel,
            @P_PER_B_PRIINS = @ins, @P_PER_B_PRIUPD = @upd, @P_PER_B_PRIDEL = @del, @P_PER_N_INDICA = 1, @P_PER_N_USUCRE = @usuAuditoria, @P_PER_N_EXTERN = 0;
        SELECT @per = UltimoId FROM @r WHERE Ok = 1;
        IF ISNULL(@per, 0) = 0 THROW 53011, 'SP_INS_PERFIL fallo.', 1;
        SET @estado = 'creado';
    END
    ELSE IF EXISTS (SELECT 1 FROM A_PERFIL_PER WHERE PER_PK_PERFI = @per
                    AND (PER_B_PRITOT <> 0 OR PER_B_PRISEL <> @sel OR PER_B_PRIINS <> @ins OR PER_B_PRIUPD <> @upd OR PER_B_PRIDEL <> @del))
        SET @estado = 'existia - FLAGS DISTINTOS (revisar)';

    SET @rol = (SELECT TOP 1 ROL_PK_ROLES FROM I_ROLES_ROL WHERE ROL_FK_SISTE = @sistemaId AND ROL_V_CODIGO = @c AND ROL_B_ESTADO = 1);
    IF @rol IS NULL
    BEGIN
        DELETE @r;
        INSERT @r EXEC SP_INS_ROLES @P_ROL_FK_SISTE = @sistemaId, @P_ROL_V_DESCRI = @n, @P_ROL_V_CODIGO = @c, @P_ROL_N_INDICA = 1,
            @P_ROL_N_USUCRE = @usuAuditoria, @P_ROL_N_EXTERN = 0;
        SELECT @rol = UltimoId FROM @r WHERE Ok = 1;
        IF ISNULL(@rol, 0) = 0 THROW 53012, 'SP_INS_ROLES fallo.', 1;
    END

    DECLARE cr CURSOR LOCAL FAST_FORWARD FOR SELECT LTRIM(RTRIM(value)) FROM STRING_SPLIT(@menus, ',');
    OPEN cr; FETCH NEXT FROM cr INTO @menu;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @mod = (SELECT TOP 1 MOD_PK_MODUL FROM I_MODULO_MOD WHERE MOD_FK_SISTE = @sistemaId AND MOD_V_DESLAR = @menu AND MOD_B_ESTADO = 1);
        IF @mod IS NULL THROW 53013, 'Modulo del rol no encontrado.', 1;
        IF NOT EXISTS (SELECT 1 FROM I_DETALLE_ROL_DRL WHERE DRL_FK_ROLES = @rol AND DRL_FK_MODUL = @mod AND DRL_B_ESTADO = 1)
        BEGIN
            DELETE @r;
            INSERT @r EXEC SP_INS_DETROL @P_DRL_FK_ROLES = @rol, @P_DRL_FK_MODUL = @mod, @P_DRL_N_USUCRE = @usuAuditoria;
            IF NOT EXISTS (SELECT 1 FROM @r WHERE Ok = 1) THROW 53014, 'SP_INS_DETROL fallo.', 1;
        END
        FETCH NEXT FROM cr INTO @menu;
    END
    CLOSE cr; DEALLOCATE cr;

    SET @rolCsv = CONVERT(varchar(20), @rol);
    SET @gpr = (SELECT TOP 1 GPR_PK_GPFRL FROM I_GRUPO_PERF_ROL_GPR WHERE GPR_FK_SISTE = @sistemaId AND GPR_FK_PERFI = @per AND GPR_B_ESTADO = 1);
    IF @gpr IS NULL
    BEGIN
        DELETE @r;
        INSERT @r EXEC SP_INS_GRUPO_PERF_ROL @GPR_V_TITULO = @n, @GPR_V_DESLAR = @desc, @GPR_V_ICONOX = 'home', @GPR_FK_SISTE = @sistemaId,
            @GPR_FK_PERFI = @per, @GPR_FK_ROLES = @rolCsv, @GPR_FK_GRGEN = @grupoGeneral, @GPR_PK_GRPUZ = NULL, @GPR_N_INDICA = 1,
            @GPR_N_USUCRE = @usuAuditoria, @GPR_N_EXTERN = 0;
        SELECT @gpr = UltimoId FROM @r WHERE Ok = 1;
        IF ISNULL(@gpr, 0) = 0 THROW 53015, 'SP_INS_GRUPO_PERF_ROL fallo.', 1;
    END
    ELSE UPDATE I_GRUPO_PERF_ROL_GPR SET GPR_FK_ROLES = @rolCsv WHERE GPR_PK_GPFRL = @gpr AND ISNULL(GPR_FK_ROLES, '') <> @rolCsv;

    INSERT @resultado VALUES (@c, @n, @per, @rol, @gpr, @sel, @ins, @upd, @del, @menus, @estado);
    FETCH NEXT FROM cp INTO @c, @n, @sel, @ins, @upd, @del, @menus, @desc;
END
CLOSE cp; DEALLOCATE cp;

/* 4. Salida para P02 / 24 / 25 / back */
SELECT 'sistema' AS q, SIS_PK_SISTEM AS SistemaId, SIS_V_NOMSIS, SIS_V_LINKSI FROM I_SISTEMA_SIS WHERE SIS_PK_SISTEM = @sistemaId;
SELECT 'modulos' AS q, MOD_V_DESLAR AS CodigoMenu, MOD_PK_MODUL AS ModuloPauId, MOD_V_DESCOR, MOD_V_URLMOD
FROM I_MODULO_MOD WHERE MOD_FK_SISTE = @sistemaId AND MOD_B_ESTADO = 1 ORDER BY MOD_N_ORDENX;
SELECT 'resultado' AS q, r.*,
       ModulosDelRol = (SELECT STRING_AGG(m.MOD_V_DESLAR, ',') FROM I_DETALLE_ROL_DRL d JOIN I_MODULO_MOD m ON m.MOD_PK_MODUL = d.DRL_FK_MODUL
                        WHERE d.DRL_FK_ROLES = r.RolPauId AND d.DRL_B_ESTADO = 1)
FROM @resultado r ORDER BY r.CodigoSSO;

IF @confirmar = 1 BEGIN COMMIT; PRINT 'COMMIT realizado.'; END
ELSE BEGIN ROLLBACK; PRINT 'Simulacion: ROLLBACK. Poner @confirmar = 1 para aplicar.'; END
GO
SET NOEXEC OFF;
GO
