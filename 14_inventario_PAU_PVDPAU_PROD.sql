/* 14 - Inventario PAU (SOLO LECTURA) para la integracion PAU -> SSIPE.
   Base: PVDPAU_PROD en 10.4.0.20\artemisa20 (ambiente DESA del PAU).
   NOTA: PVDSMV es la base del SMV, otro sistema. No aplica al PAU.
   Objetivo: responder
     1) ¿SSIPE esta registrado como sistema en PAU? ¿con que id? (SSIPE necesita PauIntegration:SistemaId)
     2) ¿Existe el usuario de prueba DNI 42910203? ¿con que USU_PK_USUAR / DEN_PK_DETEN?
     3) ¿Que perfiles tiene el sistema SSIPE en PAU? ¿existe "COORDINADOR DE OBRA"?
     4) ¿Que asignaciones (DUP) tiene el usuario y en que sistemas?
   Ejecutar con: scripts/Consultar-Catalogos.ps1 -Base PAU -SqlFile <este archivo> -OutputFile evidencias/14_inventario_PAU.json
   (un solo lote, sin GO) o desde SSMS/Navicat seleccionando PVDPAU_PROD. No modifica datos. */
SET NOCOUNT ON;
IF DB_NAME() <> N'PVDPAU_PROD' THROW 50001, 'Seleccionar PVDPAU_PROD (DESA PAU).', 1;

/* 0. Contexto */
SELECT 'contexto' AS seccion, @@SERVERNAME AS servidor, DB_NAME() AS base, SUSER_SNAME() AS usuario_sql, SYSDATETIME() AS fecha;

/* 1. Tablas reales del modelo (los DTO del codigo usan prefijos I_/A_/C_; aqui se confirman los nombres) */
SELECT 'tablas' AS seccion, TABLE_SCHEMA, TABLE_NAME
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_TYPE = 'BASE TABLE'
  AND (TABLE_NAME LIKE '%USUARIO%' OR TABLE_NAME LIKE '%PERFIL%' OR TABLE_NAME LIKE '%SISTEMA%'
       OR TABLE_NAME LIKE '%ENTIDAD%' OR TABLE_NAME LIKE '%GRUPO%' OR TABLE_NAME LIKE '%ROL%'
       OR TABLE_NAME LIKE '%PERMISO%' OR TABLE_NAME LIKE '%TOKEN%' OR TABLE_NAME LIKE '%MODULO%')
ORDER BY TABLE_SCHEMA, TABLE_NAME;

/* 2. Sistemas registrados en PAU: buscar SSIPE (SP sin parametros, el mismo que usa la pantalla Sistemas) */
EXEC SP_SEL_SISTEMAS;

/* 3. Usuario de prueba por documento (mismo SP que usa la pantalla de usuarios del PAU) */
EXEC SP_SEL_USUARIO_DNI_CE @P_ENT_V_NRODOC = N'42910203';

/* 4. Tabla de sistemas cruda + grupos perfil/rol por sistema (segunda pasada, requiere el id) */
-- EXEC SP_SEL_GRUPO_PER_ROL @P_GPR_FK_SISTE = <ID_SISTEMA_SSIPE>;

/* ---- Segunda pasada: descomentar y reemplazar con los ids obtenidos arriba ----

-- 5. Asignaciones del usuario (usuario x sistema x dependencia -> grupo perfil/rol)
EXEC SP_SEL_DET_USUARIOS_PERMISOS_FILTRO @P_DUP_FK_USUAR = <USU_PK_USUAR>, @P_V_FILTRO = N'';

-- 6. Perfiles del sistema SSIPE en PAU / buscar COORDINADOR DE OBRA
EXEC SP_SEL_PERFIL_FILTRO @P_PER_FK_SISTE = <ID_SISTEMA_SSIPE>, @P_V_FILTRO = N'';
EXEC SP_SEL_PERFIL_FILTRO @P_PER_FK_SISTE = <ID_SISTEMA_SSIPE>, @P_V_FILTRO = N'COORDINADOR';

-- 7. Lo que SSIPE recibira realmente (simula el backend PAU: ReadAuthService.GetUsuarioLoginPorIdSis).
--    Si SP_SEL_DET_USUARIOS_PERMISOS_ID_USU_SIS devuelve vacio, PAU responde MESSAGE_TOKEN_ERROR_ROL y SSIPE rechaza el canje.
EXEC SP_SEL_USUARIO_LOGIN_ID @P_USU_PK_USUAR = <USU_PK_USUAR>;
EXEC SP_SEL_DET_USUARIOS_PERMISOS_ID_USU_SIS @P_DUP_FK_USUAR = <USU_PK_USUAR>, @P_DUP_FK_SISTE = <ID_SISTEMA_SSIPE>, @P_DUP_FK_DETEN = <DEN_PK_DETEN>;
EXEC SP_SEL_GRUPO_PER_ROL_ID_AUTH @P_GPR_PK_GPFRL = <DUP_FK_GPRRL>;
EXEC SP_SEL_PERFIL_ID @P_PER_PK_PERFI = <GPR_FK_PERFI>;
*/
