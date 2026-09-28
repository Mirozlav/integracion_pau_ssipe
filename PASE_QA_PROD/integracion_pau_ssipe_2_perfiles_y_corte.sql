/*
================================================================================
 integracion_pau_ssipe_2_perfiles_y_corte.sql
================================================================================
 PASE PAU -> SSIPE, PARTE 2 de 2 (perfiles y corte). Base SSIPE del ambiente.
   P02 perfiles/menus/claims SSIPE con los ids del PAU del ambiente
       (P0001, P0023, P0024, P0025, P0028, P0029 y P0045 LECTOR GENERAL = "Seguimiento", solo lectura)
   30  11 claims de Ejecucion CVA (reemplaza el bloque 2 de DESPLIEGUE_2_DBSSO)
   29  corte de identidad: Asignar Proyecto y filtros de listados leen PAU
 Requiere: parte 1 y DESPLIEGUE_1_DBSSIPE.sql aplicados, y los ids que entrega el
 equipo PAU al correr P03_sistema_modulos_perfiles_SSIPE_en_PAU.sql en el PAU.
 Ejecutar en la MISMA ventana en que se publican back y front (rama dev_pau).
 Rollback: integracion_pau_ssipe_R_rollback_corte.sql + PauIntegration:Enabled=false.

 COMO SE EJECUTA
   - Modo SQLCMD obligatorio (SSMS: menu Consulta > Modo SQLCMD; o sqlcmd -b -I).
     Sin SQLCMD no ejecuta nada.
   - Conectado a la base SSIPE del ambiente, con una cuenta con permisos DDL.
   - Primero con CONFIRMAR "0" (simula todo y hace ROLLBACK). Revisar la salida.
     Luego CONFIRMAR "1" en una conexion nueva.
   - Corta ante el primer error; si corta, la transaccion se revierte completa.
 GENERADO por herramientas/armar_integracion_pau_ssipe.py: no editar a mano,
 salvo el bloque :setvar de abajo.
================================================================================
*/
:on error exit
:setvar __MODO_SQLCMD "SI"         -- no tocar
:setvar BASE_SSIPE "DBSSIPE"       -- base SSIPE del ambiente
:setvar CONFIRMAR "0"              -- 0 = simular, 1 = aplicar
:setvar PAU_SISTEMA_ID "NULL"      -- P03 'sistema': SistemaId (= PauIntegration:SistemaId)
:setvar PAU_PERFIL_P0001 "NULL"    -- P03 'resultado': PerfilPauId de P0001
:setvar PAU_PERFIL_P0023 "NULL"    -- P03 'resultado': PerfilPauId de P0023
:setvar PAU_PERFIL_P0024 "NULL"    -- P03 'resultado': PerfilPauId de P0024
:setvar PAU_PERFIL_P0025 "NULL"    -- P03 'resultado': PerfilPauId de P0025
:setvar PAU_PERFIL_P0028 "NULL"    -- P03 'resultado': PerfilPauId de P0028
:setvar PAU_PERFIL_P0029 "NULL"    -- P03 'resultado': PerfilPauId de P0029
:setvar PAU_PERFIL_P0045 "NULL"    -- P03 'resultado': PerfilPauId de P0045
:setvar PAU_MODULO_M0001 "NULL"    -- P03 'modulos': ModuloPauId de M0001
:setvar PAU_MODULO_M0007 "NULL"    -- P03 'modulos': ModuloPauId de M0007
:setvar PAU_MODULO_M0043 "NULL"    -- P03 'modulos': ModuloPauId de M0043
:setvar PAU_MODULO_M1051 "NULL"    -- P03 'modulos': ModuloPauId de M1051
GO
IF N'$(__MODO_SQLCMD)' <> N'SI'
BEGIN RAISERROR(N'Ejecutar en modo SQLCMD (SSMS: Consulta > Modo SQLCMD). No se ejecuto nada.', 16, 1); SET NOEXEC ON; END
GO
IF DB_NAME() <> N'$(BASE_SSIPE)' OR N'$(CONFIRMAR)' NOT IN (N'0', N'1')
BEGIN RAISERROR(N'Base distinta de BASE_SSIPE o CONFIRMAR distinto de 0/1: ejecucion cancelada.', 16, 1); SET NOEXEC ON; END
GO
IF TRY_CONVERT(int, N'$(PAU_SISTEMA_ID)') IS NULL OR TRY_CONVERT(int, N'$(PAU_PERFIL_P0001)') IS NULL OR TRY_CONVERT(int, N'$(PAU_PERFIL_P0023)') IS NULL OR TRY_CONVERT(int, N'$(PAU_PERFIL_P0024)') IS NULL OR TRY_CONVERT(int, N'$(PAU_PERFIL_P0025)') IS NULL OR TRY_CONVERT(int, N'$(PAU_PERFIL_P0028)') IS NULL OR TRY_CONVERT(int, N'$(PAU_PERFIL_P0029)') IS NULL OR TRY_CONVERT(int, N'$(PAU_PERFIL_P0045)') IS NULL OR TRY_CONVERT(int, N'$(PAU_MODULO_M0001)') IS NULL OR TRY_CONVERT(int, N'$(PAU_MODULO_M0007)') IS NULL OR TRY_CONVERT(int, N'$(PAU_MODULO_M0043)') IS NULL OR TRY_CONVERT(int, N'$(PAU_MODULO_M1051)') IS NULL
BEGIN RAISERROR(N'Completar en :setvar los ids del PAU del ambiente (salida de P03). No se ejecuto nada.', 16, 1); SET NOEXEC ON; END
GO
SET XACT_ABORT ON;
BEGIN TRANSACTION;
PRINT CONCAT(N'Inicio en ', @@SERVERNAME, N'.', DB_NAME(), N' | CONFIRMAR=$(CONFIRMAR) | ', CONVERT(varchar(19), SYSDATETIME(), 120));
GO
-- ############################################################################
-- FUENTE: PASE_QA_PROD/P02_homologacion_perfiles_QA_PROD.sql
-- ############################################################################
/*
================================================================================
 P02 - Homologacion de perfiles SSIPE (PauPerfil + PauMenu + PauOperacion) para QA/PROD
================================================================================
 QUE ES
   Version portable de 19_homologacion_masiva_perfiles_DBSSIPE2.sql. Mismos
   datos (perfiles, menus y 710 claims exportados del SSO de DESA, que ya
   incluyen los 11 claims de Ejecucion CVA del BLOQUE 2 de DESPLIEGUE_2_DBSSO),
   pero sin ids de DESA:
     - @SistemaId : SistemaId de SSIPE en el PAU del ambiente.
     - @map       : PerfilPauId de cada perfil creado en el PAU del ambiente
                    (salida 'resultado' del script 18 adaptado al ambiente).
                    Los que queden en NULL se omiten.
     - @modulo    : ModuloPauId (MOD_PK_MODUL) de cada menu SSIPE en el PAU del
                    ambiente. Los ids 2182..2185 de las tablas de datos son solo
                    la clave de DESA para cruzar.
   Idempotente. @confirmar = 0 simula (ROLLBACK).

 DONDE SE EJECUTA
   Base SSIPE del ambiente, despues de P01. No toca PauUsuario (eso es el 24/25).
================================================================================
*/
IF DB_NAME() <> N'$(BASE_SSIPE)'
   OR OBJECT_ID(N'integracion.PauOperacion', N'U') IS NULL
BEGIN RAISERROR(N'Base incorrecta o falta P01: ejecucion cancelada.', 16, 1); SET NOEXEC ON; END
GO
SET NOCOUNT ON; SET XACT_ABORT ON;

DECLARE @confirmar bit = 1;   -- consolidado: lo decide la transaccion exterior (CONFIRMAR)
DECLARE @SistemaId int = $(PAU_SISTEMA_ID);   -- <<< SistemaId de SSIPE en el PAU del ambiente (= PauIntegration:SistemaId del back)
IF @SistemaId IS NULL THROW 57001, 'Completar @SistemaId con el id de SSIPE en el PAU del ambiente.', 1;

DECLARE @map TABLE (CodigoSSO varchar(10), PerfilPauId int NULL, IdPerfilSSO int, NombrePerfil nvarchar(200));
INSERT @map (CodigoSSO, PerfilPauId, IdPerfilSSO, NombrePerfil) VALUES
 ('P0001', $(PAU_PERFIL_P0001), 1, N'ADMINISTRADOR'),
 ('P0021', NULL, 28, N'GERENTE DE OBRA'),
 ('P0022', NULL, 29, N'JEFE DE OBRA'),
 ('P0023', $(PAU_PERFIL_P0023), 30, N'ADMINISTRADOR DE CONTRATO DE OBRA'),
 ('P0024', $(PAU_PERFIL_P0024), 31, N'SUPERVISOR DE OBRA'),
 ('P0025', $(PAU_PERFIL_P0025), 32, N'COORDINADOR DE OBRA'),
 ('P0027', NULL, 34, N'COORDINADOR EXPEDIENTE'),
 ('P0028', $(PAU_PERFIL_P0028), 35, N'ESPECIALISTA DE EXPEDIENTE'),
 ('P0029', $(PAU_PERFIL_P0029), 36, N'ESPECIALISTA PREINVERSION'),
 ('P0041', NULL, 1047, N'RESPONSABLE EXPEDIENTE TECNICO'),
 ('P0042', NULL, 1048, N'RESPONSABLE PACRI'),
 ('P0043', NULL, 1049, N'RESPONSABLE EJECUCION'),
 ('P0044', NULL, 1050, N'COORDINADOR PATS'),
 ('P0045', $(PAU_PERFIL_P0045), 1051, N'LECTOR GENERAL'),
 ('P0046', NULL, 1052, N'RESPONSABLE ABASTECIMIENTO');   -- <<< reemplazar NULL por el PerfilPauId del script 18

DECLARE @menu TABLE (CodigoSSO varchar(10), CodigoMenu varchar(10), ModuloPauId nvarchar(100), NombreMenu nvarchar(200), Url nvarchar(300), Icono nvarchar(100), Orden int);
INSERT @menu VALUES
 ('P0001', 'M0001', N'2182', N'Seguimiento', N'/seguimiento', N'mdi-account-box', 1),
 ('P0001', 'M0007', N'2183', N'Proyecto', N'/intervencion', N'mdi-folder-edit-outline', 2),
 ('P0001', 'M0043', N'2184', N'Convenio', N'/convenio', N'mdi-folder', 3),
 ('P0001', 'M1051', N'2185', N'Asignar Proyecto', N'/asignarProyecto', N'mdi-folder-account-outline', 4),
 ('P0021', 'M0001', N'2182', N'Seguimiento', N'/seguimiento', N'mdi-account-box', 1),
 ('P0021', 'M0007', N'2183', N'Proyecto', N'/intervencion', N'mdi-folder-edit-outline', 2),
 ('P0021', 'M0043', N'2184', N'Convenio', N'/convenio', N'mdi-folder', 3),
 ('P0022', 'M0001', N'2182', N'Seguimiento', N'/seguimiento', N'mdi-account-box', 1),
 ('P0022', 'M0007', N'2183', N'Proyecto', N'/intervencion', N'mdi-folder-edit-outline', 2),
 ('P0022', 'M0043', N'2184', N'Convenio', N'/convenio', N'mdi-folder', 3),
 ('P0023', 'M0001', N'2182', N'Seguimiento', N'/seguimiento', N'mdi-account-box', 1),
 ('P0023', 'M0007', N'2183', N'Proyecto', N'/intervencion', N'mdi-folder-edit-outline', 2),
 ('P0023', 'M0043', N'2184', N'Convenio', N'/convenio', N'mdi-folder', 3),
 ('P0024', 'M0001', N'2182', N'Seguimiento', N'/seguimiento', N'mdi-account-box', 1),
 ('P0024', 'M0007', N'2183', N'Proyecto', N'/intervencion', N'mdi-folder-edit-outline', 2),
 ('P0024', 'M0043', N'2184', N'Convenio', N'/convenio', N'mdi-folder', 3),
 ('P0025', 'M0001', N'2182', N'Seguimiento', N'/seguimiento', N'mdi-account-box', 1),
 ('P0025', 'M0007', N'2183', N'Proyecto', N'/intervencion', N'mdi-folder-edit-outline', 2),
 ('P0025', 'M0043', N'2184', N'Convenio', N'/convenio', N'mdi-folder', 3),
 ('P0025', 'M1051', N'2185', N'Asignar Proyecto', N'/asignarProyecto', N'mdi-folder-account-outline', 4),
 ('P0027', 'M0001', N'2182', N'Seguimiento', N'/seguimiento', N'mdi-account-box', 1),
 ('P0027', 'M0007', N'2183', N'Proyecto', N'/intervencion', N'mdi-folder-edit-outline', 2),
 ('P0027', 'M0043', N'2184', N'Convenio', N'/convenio', N'mdi-folder', 3),
 ('P0027', 'M1051', N'2185', N'Asignar Proyecto', N'/asignarProyecto', N'mdi-folder-account-outline', 4),
 ('P0028', 'M0001', N'2182', N'Seguimiento', N'/seguimiento', N'mdi-account-box', 1),
 ('P0028', 'M0007', N'2183', N'Proyecto', N'/intervencion', N'mdi-folder-edit-outline', 2),
 ('P0028', 'M0043', N'2184', N'Convenio', N'/convenio', N'mdi-folder', 3),
 ('P0029', 'M0001', N'2182', N'Seguimiento', N'/seguimiento', N'mdi-account-box', 1),
 ('P0029', 'M0007', N'2183', N'Proyecto', N'/intervencion', N'mdi-folder-edit-outline', 2),
 ('P0029', 'M0043', N'2184', N'Convenio', N'/convenio', N'mdi-folder', 3),
 ('P0041', 'M0001', N'2182', N'Seguimiento', N'/seguimiento', N'mdi-account-box', 1),
 ('P0042', 'M0001', N'2182', N'Seguimiento', N'/seguimiento', N'mdi-account-box', 1),
 ('P0043', 'M0001', N'2182', N'Seguimiento', N'/seguimiento', N'mdi-account-box', 1),
 ('P0044', 'M0001', N'2182', N'Seguimiento', N'/seguimiento', N'mdi-account-box', 1),
 ('P0044', 'M0007', N'2183', N'Proyecto', N'/intervencion', N'mdi-folder-edit-outline', 2),
 ('P0044', 'M0043', N'2184', N'Convenio', N'/convenio', N'mdi-folder', 3),
 ('P0044', 'M1051', N'2185', N'Asignar Proyecto', N'/asignarProyecto', N'mdi-folder-account-outline', 4),
 ('P0045', 'M0001', N'2182', N'Seguimiento', N'/seguimiento', N'mdi-account-box', 1),
 ('P0045', 'M0007', N'2183', N'Proyecto', N'/intervencion', N'mdi-folder-edit-outline', 2),   -- P0045 = Seguimiento solo lectura: menus sin claims (28/09)
 ('P0045', 'M0043', N'2184', N'Convenio', N'/convenio', N'mdi-folder', 3),
 ('P0046', 'M0001', N'2182', N'Seguimiento', N'/seguimiento', N'mdi-account-box', 1);

DECLARE @op TABLE (CodigoSSO varchar(10), ModuloPauId nvarchar(100), HasClaim varchar(200), Accion varchar(10));
INSERT @op VALUES
 ('P0001', N'2182', 'SSIPEM0001_btn_acciones_actos_preparatorios', 'leer'),
 ('P0001', N'2182', 'SSIPEM0001_btn_acciones_adendas_sup', 'leer'),
 ('P0001', N'2182', 'SSIPEM0001_btn_acciones_ampliaciones', 'leer'),
 ('P0001', N'2182', 'SSIPEM0001_btn_acciones_comisiones_visitas', 'leer'),
 ('P0001', N'2182', 'SSIPEM0001_btn_acciones_comite_seleccion', 'leer'),
 ('P0001', N'2182', 'SSIPEM0001_btn_acciones_convocatoria_osce', 'leer'),
 ('P0001', N'2182', 'SSIPEM0001_btn_acciones_fase_seleccion', 'leer'),
 ('P0001', N'2182', 'SSIPEM0001_btn_acciones_liquidacion_contrato', 'leer'),
 ('P0001', N'2182', 'SSIPEM0001_btn_acciones_maquinaria', 'leer'),
 ('P0001', N'2182', 'SSIPEM0001_btn_acciones_maquinaria_sup', 'leer'),
 ('P0001', N'2182', 'SSIPEM0001_btn_acciones_modificaciones_gastos', 'editar'),
 ('P0001', N'2182', 'SSIPEM0001_btn_acciones_panel_fotografico', 'leer'),
 ('P0001', N'2182', 'SSIPEM0001_btn_acciones_paralizaciones', 'leer'),
 ('P0001', N'2182', 'SSIPEM0001_btn_acciones_paralizaciones_det', 'leer'),
 ('P0001', N'2182', 'SSIPEM0001_btn_acciones_personal_clave', 'leer'),
 ('P0001', N'2182', 'SSIPEM0001_btn_acciones_personal_clave_sup', 'leer'),
 ('P0001', N'2182', 'SSIPEM0001_btn_acciones_programacion_perfil', 'leer'),
 ('P0001', N'2182', 'SSIPEM0001_btn_acciones_recepcion_pats', 'leer'),
 ('P0001', N'2182', 'SSIPEM0001_btn_acciones_resolucion_contrato_pats', 'leer'),
 ('P0001', N'2182', 'SSIPEM0001_btn_acciones_riesgos', 'leer'),
 ('P0001', N'2182', 'SSIPEM0001_btn_acciones_suspensiones', 'leer'),
 ('P0001', N'2182', 'SSIPEM0001_btn_acciones_suspensiones_det', 'leer'),
 ('P0001', N'2182', 'SSIPEM0001_btn_acciones_tramo_proyecto', 'leer'),
 ('P0001', N'2182', 'SSIPEM0001_btn_acciones_transferencia_pats', 'leer'),
 ('P0001', N'2182', 'SSIPEM0001_btn_acciones_valorizaciones_base', 'leer'),
 ('P0001', N'2182', 'SSIPEM0001_btn_acciones_valorizaciones_supervision', 'leer'),
 ('P0001', N'2182', 'SSIPEM0001_btn_acciones_variaciones', 'leer'),
 ('P0001', N'2182', 'SSIPEM0001_btn_acciones_variaciones_det', 'leer'),
 ('P0001', N'2182', 'SSIPEM0001_btn_acciones_variaciones_supervision', 'leer'),
 ('P0001', N'2182', 'SSIPEM0001_btn_editar_comite_seleccion', 'editar'),
 ('P0001', N'2182', 'SSIPEM0001_btn_editar_fase_seleccion', 'editar'),
 ('P0001', N'2182', 'SSIPEM0001_btn_guardar_actos_preparatorios', 'editar'),
 ('P0001', N'2182', 'SSIPEM0001_btn_guardar_adendas_sup', 'editar'),
 ('P0001', N'2182', 'SSIPEM0001_btn_guardar_ampliaciones', 'editar'),
 ('P0001', N'2182', 'SSIPEM0001_btn_guardar_comisiones_visitas', 'editar'),
 ('P0001', N'2182', 'SSIPEM0001_btn_guardar_comite_seleccion', 'editar'),
 ('P0001', N'2182', 'SSIPEM0001_btn_guardar_contrato_ejecucion', 'editar'),
 ('P0001', N'2182', 'SSIPEM0001_btn_guardar_contrato_supervision', 'editar'),
 ('P0001', N'2182', 'SSIPEM0001_btn_guardar_convocatoria_osce', 'editar'),
 ('P0001', N'2182', 'SSIPEM0001_btn_guardar_estado_situacional', 'editar'),
 ('P0001', N'2182', 'SSIPEM0001_btn_guardar_estado_situacional_sup', 'editar'),
 ('P0001', N'2182', 'SSIPEM0001_btn_guardar_fase_seleccion', 'editar'),
 ('P0001', N'2182', 'SSIPEM0001_btn_guardar_liquidacion_contrato', 'editar'),
 ('P0001', N'2182', 'SSIPEM0001_btn_guardar_maquinaria', 'editar'),
 ('P0001', N'2182', 'SSIPEM0001_btn_guardar_maquinaria_sup', 'editar'),
 ('P0001', N'2182', 'SSIPEM0001_btn_guardar_modificaciones_gastos', 'editar'),
 ('P0001', N'2182', 'SSIPEM0001_btn_guardar_paralizaciones', 'editar'),
 ('P0001', N'2182', 'SSIPEM0001_btn_guardar_paralizaciones_det', 'editar'),
 ('P0001', N'2182', 'SSIPEM0001_btn_guardar_personal_clave', 'editar'),
 ('P0001', N'2182', 'SSIPEM0001_btn_guardar_personal_clave_sup', 'editar'),
 ('P0001', N'2182', 'SSIPEM0001_btn_guardar_programacion_perfil', 'editar'),
 ('P0001', N'2182', 'SSIPEM0001_btn_guardar_recepcion_pats', 'editar'),
 ('P0001', N'2182', 'SSIPEM0001_btn_guardar_resolucion_contrato_pats', 'editar'),
 ('P0001', N'2182', 'SSIPEM0001_btn_guardar_riesgos', 'editar'),
 ('P0001', N'2182', 'SSIPEM0001_btn_guardar_suspensiones', 'editar'),
 ('P0001', N'2182', 'SSIPEM0001_btn_guardar_suspensiones_det', 'editar'),
 ('P0001', N'2182', 'SSIPEM0001_btn_guardar_tramo_proyecto', 'editar'),
 ('P0001', N'2182', 'SSIPEM0001_btn_guardar_transferencia_pats', 'editar'),
 ('P0001', N'2182', 'SSIPEM0001_btn_guardar_valorizaciones_base', 'editar'),
 ('P0001', N'2182', 'SSIPEM0001_btn_guardar_valorizaciones_supervision', 'editar'),
 ('P0001', N'2182', 'SSIPEM0001_btn_guardar_variaciones', 'editar'),
 ('P0001', N'2182', 'SSIPEM0001_btn_guardar_variaciones_det', 'editar'),
 ('P0001', N'2182', 'SSIPEM0001_btn_guardar_variaciones_supervision', 'editar'),
 ('P0001', N'2182', 'SSIPEM0001_btn_nuevo_actos_preparatorios', 'crear'),
 ('P0001', N'2182', 'SSIPEM0001_btn_nuevo_adendas_sup', 'crear'),
 ('P0001', N'2182', 'SSIPEM0001_btn_nuevo_ampliaciones', 'crear'),
 ('P0001', N'2182', 'SSIPEM0001_btn_nuevo_comisiones_visitas', 'crear'),
 ('P0001', N'2182', 'SSIPEM0001_btn_nuevo_comite_seleccion', 'crear'),
 ('P0001', N'2182', 'SSIPEM0001_btn_nuevo_convocatoria_osce', 'crear'),
 ('P0001', N'2182', 'SSIPEM0001_btn_nuevo_fase_seleccion', 'crear'),
 ('P0001', N'2182', 'SSIPEM0001_btn_nuevo_liquidacion_contrato', 'crear'),
 ('P0001', N'2182', 'SSIPEM0001_btn_nuevo_maquinaria', 'crear'),
 ('P0001', N'2182', 'SSIPEM0001_btn_nuevo_maquinaria_sup', 'crear'),
 ('P0001', N'2182', 'SSIPEM0001_btn_nuevo_modificaciones_gastos', 'crear'),
 ('P0001', N'2182', 'SSIPEM0001_btn_nuevo_panel_fotografico', 'crear'),
 ('P0001', N'2182', 'SSIPEM0001_btn_nuevo_paralizaciones', 'crear'),
 ('P0001', N'2182', 'SSIPEM0001_btn_nuevo_paralizaciones_det', 'crear'),
 ('P0001', N'2182', 'SSIPEM0001_btn_nuevo_personal_clave', 'crear'),
 ('P0001', N'2182', 'SSIPEM0001_btn_nuevo_personal_clave_sup', 'crear'),
 ('P0001', N'2182', 'SSIPEM0001_btn_nuevo_programacion_perfil', 'crear'),
 ('P0001', N'2182', 'SSIPEM0001_btn_nuevo_recepcion_pats', 'crear'),
 ('P0001', N'2182', 'SSIPEM0001_btn_nuevo_resolucion_contrato_pats', 'crear'),
 ('P0001', N'2182', 'SSIPEM0001_btn_nuevo_riesgos', 'crear'),
 ('P0001', N'2182', 'SSIPEM0001_btn_nuevo_suspensiones', 'crear'),
 ('P0001', N'2182', 'SSIPEM0001_btn_nuevo_suspensiones_det', 'crear'),
 ('P0001', N'2182', 'SSIPEM0001_btn_nuevo_tramo_proyecto', 'crear'),
 ('P0001', N'2182', 'SSIPEM0001_btn_nuevo_transferencia_pats', 'crear'),
 ('P0001', N'2182', 'SSIPEM0001_btn_nuevo_variaciones', 'crear'),
 ('P0001', N'2182', 'SSIPEM0001_btn_nuevo_variaciones_det', 'crear'),
 ('P0001', N'2182', 'SSIPEM0001_btn_nuevo_variaciones_supervision', 'crear'),
 ('P0001', N'2182', 'SSIPEM0001_ejecucion_btn_acciones_paralizacion', 'leer'),
 ('P0001', N'2182', 'SSIPEM0001_ejecucion_btn_acciones_tramo', 'leer'),
 ('P0001', N'2182', 'SSIPEM0001_ejecucion_btn_guardar_paralizacion', 'editar'),
 ('P0001', N'2182', 'SSIPEM0001_ejecucion_btn_guardar_tramo', 'editar'),
 ('P0001', N'2182', 'SSIPEM0001_ejecucion_btn_nuevo_paralizacion', 'crear'),
 ('P0001', N'2182', 'SSIPEM0001_ejecucion_btn_nuevo_tramo', 'crear'),
 ('P0001', N'2182', 'SSIPEM0001_expediente_btn_acciones_accion_monitoreo', 'leer'),
 ('P0001', N'2182', 'SSIPEM0001_expediente_btn_acciones_ampliacion', 'leer'),
 ('P0001', N'2182', 'SSIPEM0001_expediente_btn_acciones_aprobacion', 'leer'),
 ('P0001', N'2182', 'SSIPEM0001_expediente_btn_acciones_contrato', 'leer'),
 ('P0001', N'2182', 'SSIPEM0001_expediente_btn_acciones_cronograma', 'leer'),
 ('P0001', N'2182', 'SSIPEM0001_expediente_btn_acciones_paralizacion', 'leer'),
 ('P0001', N'2182', 'SSIPEM0001_expediente_btn_acciones_resolucion_contrato', 'leer'),
 ('P0001', N'2182', 'SSIPEM0001_expediente_btn_acciones_responsable', 'leer'),
 ('P0001', N'2182', 'SSIPEM0001_expediente_btn_acciones_responsable_et', 'leer'),
 ('P0001', N'2182', 'SSIPEM0001_expediente_btn_acciones_suspension', 'leer'),
 ('P0001', N'2182', 'SSIPEM0001_expediente_btn_acciones_valorizacion', 'leer'),
 ('P0001', N'2182', 'SSIPEM0001_expediente_btn_guardar_accion_monitoreo', 'editar'),
 ('P0001', N'2182', 'SSIPEM0001_expediente_btn_guardar_ampliacion', 'editar'),
 ('P0001', N'2182', 'SSIPEM0001_expediente_btn_guardar_aprobacion', 'editar'),
 ('P0001', N'2182', 'SSIPEM0001_expediente_btn_guardar_contrato', 'editar'),
 ('P0001', N'2182', 'SSIPEM0001_expediente_btn_guardar_cronograma', 'editar'),
 ('P0001', N'2182', 'SSIPEM0001_expediente_btn_guardar_paralizacion', 'editar'),
 ('P0001', N'2182', 'SSIPEM0001_expediente_btn_guardar_resolucion_contrato', 'editar'),
 ('P0001', N'2182', 'SSIPEM0001_expediente_btn_guardar_responsable', 'editar'),
 ('P0001', N'2182', 'SSIPEM0001_expediente_btn_guardar_responsable_et', 'editar'),
 ('P0001', N'2182', 'SSIPEM0001_expediente_btn_guardar_suspension', 'editar'),
 ('P0001', N'2182', 'SSIPEM0001_expediente_btn_guardar_valorizacion', 'editar'),
 ('P0001', N'2182', 'SSIPEM0001_expediente_btn_modifica_fecha_real', 'editar'),
 ('P0001', N'2182', 'SSIPEM0001_expediente_btn_nuevo_accion_monitoreo', 'crear'),
 ('P0001', N'2182', 'SSIPEM0001_expediente_btn_nuevo_ampliacion', 'crear'),
 ('P0001', N'2182', 'SSIPEM0001_expediente_btn_nuevo_aprobacion', 'crear'),
 ('P0001', N'2182', 'SSIPEM0001_expediente_btn_nuevo_contrato', 'crear'),
 ('P0001', N'2182', 'SSIPEM0001_expediente_btn_nuevo_cronograma', 'crear'),
 ('P0001', N'2182', 'SSIPEM0001_expediente_btn_nuevo_paralizacion', 'crear'),
 ('P0001', N'2182', 'SSIPEM0001_expediente_btn_nuevo_resolucion_contrato', 'crear'),
 ('P0001', N'2182', 'SSIPEM0001_expediente_btn_nuevo_responsable', 'crear'),
 ('P0001', N'2182', 'SSIPEM0001_expediente_btn_nuevo_responsable_et', 'crear'),
 ('P0001', N'2182', 'SSIPEM0001_expediente_btn_nuevo_suspension', 'crear'),
 ('P0001', N'2182', 'SSIPEM0001_expediente_btn_nuevo_valorizacion', 'crear'),
 ('P0001', N'2182', 'SSIPEM0001_preinversion_btn_guardar_ampliacion', 'editar'),
 ('P0001', N'2182', 'SSIPEM0001btn_mostrar_seguimiento', 'leer'),
 ('P0001', N'2183', 'SSIPEM0007btn_acciones_intervencion', 'leer'),
 ('P0001', N'2183', 'SSIPEM0007btn_cambio_fase', 'editar'),
 ('P0001', N'2183', 'SSIPEM0007btn_nueva_intervencion', 'crear'),
 ('P0001', N'2184', 'SSIPEM0043btn_acciones_convenio', 'leer'),
 ('P0001', N'2184', 'SSIPEM0043btn_nuevo_convenio', 'crear'),
 ('P0021', N'2183', 'SSIPEM0007btn_acciones_intervencion', 'leer'),
 ('P0021', N'2183', 'SSIPEM0007btn_nueva_intervencion', 'crear'),
 ('P0022', N'2183', 'SSIPEM0007btn_acciones_intervencion', 'leer'),
 ('P0022', N'2183', 'SSIPEM0007btn_nueva_intervencion', 'crear'),
 ('P0023', N'2182', 'SSIPEM0001_ejecucion_btn_acciones_adelanto_directo', 'leer'),
 ('P0023', N'2182', 'SSIPEM0001_ejecucion_btn_acciones_adelanto_material', 'leer'),
 ('P0023', N'2182', 'SSIPEM0001_ejecucion_btn_acciones_adicional_deductivo', 'leer'),
 ('P0023', N'2182', 'SSIPEM0001_ejecucion_btn_acciones_ampliacion', 'leer'),
 ('P0023', N'2182', 'SSIPEM0001_ejecucion_btn_acciones_conservacion', 'leer'),
 ('P0023', N'2182', 'SSIPEM0001_ejecucion_btn_acciones_contrato', 'leer'),
 ('P0023', N'2182', 'SSIPEM0001_ejecucion_btn_acciones_cronograma', 'leer'),
 ('P0023', N'2182', 'SSIPEM0001_ejecucion_btn_acciones_impedimento', 'leer'),
 ('P0023', N'2182', 'SSIPEM0001_ejecucion_btn_acciones_interferencia', 'leer'),
 ('P0023', N'2182', 'SSIPEM0001_ejecucion_btn_acciones_liquidacion', 'leer'),
 ('P0023', N'2182', 'SSIPEM0001_ejecucion_btn_acciones_mejoramiento', 'leer'),
 ('P0023', N'2182', 'SSIPEM0001_ejecucion_btn_acciones_otroplazo', 'leer'),
 ('P0023', N'2182', 'SSIPEM0001_ejecucion_btn_acciones_panelfotografico', 'leer'),
 ('P0023', N'2182', 'SSIPEM0001_ejecucion_btn_acciones_paralizacion', 'leer'),
 ('P0023', N'2182', 'SSIPEM0001_ejecucion_btn_acciones_recepcion', 'leer'),
 ('P0023', N'2182', 'SSIPEM0001_ejecucion_btn_acciones_reduccion', 'leer'),
 ('P0023', N'2182', 'SSIPEM0001_ejecucion_btn_acciones_resolucion_contrato', 'leer'),
 ('P0023', N'2182', 'SSIPEM0001_ejecucion_btn_acciones_responsable', 'leer'),
 ('P0023', N'2182', 'SSIPEM0001_ejecucion_btn_acciones_socioambiental', 'leer'),
 ('P0023', N'2182', 'SSIPEM0001_ejecucion_btn_acciones_suspension', 'leer'),
 ('P0023', N'2182', 'SSIPEM0001_ejecucion_btn_acciones_tramo', 'leer'),
 ('P0023', N'2182', 'SSIPEM0001_ejecucion_btn_acciones_transferencia', 'leer'),
 ('P0023', N'2182', 'SSIPEM0001_ejecucion_btn_acciones_valorizacion', 'leer'),
 ('P0023', N'2182', 'SSIPEM0001_ejecucion_btn_acciones_visita_entidad', 'leer'),
 ('P0023', N'2182', 'SSIPEM0001_ejecucion_btn_guardar_adelanto_directo', 'editar'),
 ('P0023', N'2182', 'SSIPEM0001_ejecucion_btn_guardar_adelanto_material', 'editar'),
 ('P0023', N'2182', 'SSIPEM0001_ejecucion_btn_guardar_adicional_deductivo', 'editar'),
 ('P0023', N'2182', 'SSIPEM0001_ejecucion_btn_guardar_ampliacion', 'editar'),
 ('P0023', N'2182', 'SSIPEM0001_ejecucion_btn_guardar_contrato', 'editar'),
 ('P0023', N'2182', 'SSIPEM0001_ejecucion_btn_guardar_cronograma', 'editar'),
 ('P0023', N'2182', 'SSIPEM0001_ejecucion_btn_guardar_impedimento', 'editar'),
 ('P0023', N'2182', 'SSIPEM0001_ejecucion_btn_guardar_interferencia', 'editar'),
 ('P0023', N'2182', 'SSIPEM0001_ejecucion_btn_guardar_liquidacion', 'editar'),
 ('P0023', N'2182', 'SSIPEM0001_ejecucion_btn_guardar_otroplazo', 'editar'),
 ('P0023', N'2182', 'SSIPEM0001_ejecucion_btn_guardar_paralizacion', 'editar'),
 ('P0023', N'2182', 'SSIPEM0001_ejecucion_btn_guardar_recepcion', 'editar'),
 ('P0023', N'2182', 'SSIPEM0001_ejecucion_btn_guardar_reduccion', 'editar'),
 ('P0023', N'2182', 'SSIPEM0001_ejecucion_btn_guardar_resolucion_contrato', 'editar'),
 ('P0023', N'2182', 'SSIPEM0001_ejecucion_btn_guardar_responsable', 'editar'),
 ('P0023', N'2182', 'SSIPEM0001_ejecucion_btn_guardar_suspension', 'editar'),
 ('P0023', N'2182', 'SSIPEM0001_ejecucion_btn_guardar_tramo', 'editar'),
 ('P0023', N'2182', 'SSIPEM0001_ejecucion_btn_guardar_transferencia', 'editar'),
 ('P0023', N'2182', 'SSIPEM0001_ejecucion_btn_guardar_valorizacion', 'editar'),
 ('P0023', N'2182', 'SSIPEM0001_ejecucion_btn_guardar_visita_entidad', 'editar'),
 ('P0023', N'2182', 'SSIPEM0001_ejecucion_btn_modifica_fecha_real', 'editar'),
 ('P0023', N'2182', 'SSIPEM0001_ejecucion_btn_nuevo_adelanto_directo', 'crear'),
 ('P0023', N'2182', 'SSIPEM0001_ejecucion_btn_nuevo_adelanto_material', 'crear'),
 ('P0023', N'2182', 'SSIPEM0001_ejecucion_btn_nuevo_adicional_deductivo', 'crear'),
 ('P0023', N'2182', 'SSIPEM0001_ejecucion_btn_nuevo_ampliacion', 'crear'),
 ('P0023', N'2182', 'SSIPEM0001_ejecucion_btn_nuevo_conservacion', 'crear'),
 ('P0023', N'2182', 'SSIPEM0001_ejecucion_btn_nuevo_contrato', 'crear'),
 ('P0023', N'2182', 'SSIPEM0001_ejecucion_btn_nuevo_cronograma', 'crear'),
 ('P0023', N'2182', 'SSIPEM0001_ejecucion_btn_nuevo_impedimento', 'crear'),
 ('P0023', N'2182', 'SSIPEM0001_ejecucion_btn_nuevo_interferencia', 'crear'),
 ('P0023', N'2182', 'SSIPEM0001_ejecucion_btn_nuevo_liquidacion', 'crear'),
 ('P0023', N'2182', 'SSIPEM0001_ejecucion_btn_nuevo_mejoramiento', 'crear'),
 ('P0023', N'2182', 'SSIPEM0001_ejecucion_btn_nuevo_otroplazo', 'crear'),
 ('P0023', N'2182', 'SSIPEM0001_ejecucion_btn_nuevo_panelfotografico', 'crear'),
 ('P0023', N'2182', 'SSIPEM0001_ejecucion_btn_nuevo_paralizacion', 'crear'),
 ('P0023', N'2182', 'SSIPEM0001_ejecucion_btn_nuevo_recepcion', 'crear'),
 ('P0023', N'2182', 'SSIPEM0001_ejecucion_btn_nuevo_reduccion', 'crear'),
 ('P0023', N'2182', 'SSIPEM0001_ejecucion_btn_nuevo_resolucion_contrato', 'crear'),
 ('P0023', N'2182', 'SSIPEM0001_ejecucion_btn_nuevo_responsable', 'crear'),
 ('P0023', N'2182', 'SSIPEM0001_ejecucion_btn_nuevo_socioambiental', 'crear'),
 ('P0023', N'2182', 'SSIPEM0001_ejecucion_btn_nuevo_suspension', 'crear'),
 ('P0023', N'2182', 'SSIPEM0001_ejecucion_btn_nuevo_tramo', 'crear'),
 ('P0023', N'2182', 'SSIPEM0001_ejecucion_btn_nuevo_transferencia', 'crear'),
 ('P0023', N'2182', 'SSIPEM0001_ejecucion_btn_nuevo_valorizacion', 'crear'),
 ('P0023', N'2182', 'SSIPEM0001_ejecucion_btn_nuevo_visita_entidad', 'crear'),
 ('P0023', N'2182', 'SSIPEM0001_ejecucion_btn_vincular_proceso', 'crear'),
 ('P0023', N'2182', 'SSIPEM0001_expediente_btn_acciones_accion_monitoreo', 'leer'),
 ('P0023', N'2182', 'SSIPEM0001_expediente_btn_acciones_ampliacion', 'leer'),
 ('P0023', N'2182', 'SSIPEM0001_expediente_btn_acciones_aprobacion', 'leer'),
 ('P0023', N'2182', 'SSIPEM0001_expediente_btn_acciones_contrato', 'leer'),
 ('P0023', N'2182', 'SSIPEM0001_expediente_btn_acciones_cronograma', 'leer'),
 ('P0023', N'2182', 'SSIPEM0001_expediente_btn_acciones_paralizacion', 'leer'),
 ('P0023', N'2182', 'SSIPEM0001_expediente_btn_acciones_resolucion_contrato', 'leer'),
 ('P0023', N'2182', 'SSIPEM0001_expediente_btn_acciones_responsable', 'leer'),
 ('P0023', N'2182', 'SSIPEM0001_expediente_btn_acciones_responsable_et', 'leer'),
 ('P0023', N'2182', 'SSIPEM0001_expediente_btn_acciones_suspension', 'leer'),
 ('P0023', N'2182', 'SSIPEM0001_expediente_btn_acciones_valorizacion', 'leer'),
 ('P0023', N'2182', 'SSIPEM0001_expediente_btn_guardar_accion_monitoreo', 'editar'),
 ('P0023', N'2182', 'SSIPEM0001_expediente_btn_guardar_ampliacion', 'editar'),
 ('P0023', N'2182', 'SSIPEM0001_expediente_btn_guardar_aprobacion', 'editar'),
 ('P0023', N'2182', 'SSIPEM0001_expediente_btn_guardar_contrato', 'editar'),
 ('P0023', N'2182', 'SSIPEM0001_expediente_btn_guardar_cronograma', 'editar'),
 ('P0023', N'2182', 'SSIPEM0001_expediente_btn_guardar_paralizacion', 'editar'),
 ('P0023', N'2182', 'SSIPEM0001_expediente_btn_guardar_resolucion_contrato', 'editar'),
 ('P0023', N'2182', 'SSIPEM0001_expediente_btn_guardar_responsable', 'editar'),
 ('P0023', N'2182', 'SSIPEM0001_expediente_btn_guardar_responsable_et', 'editar'),
 ('P0023', N'2182', 'SSIPEM0001_expediente_btn_guardar_suspension', 'editar'),
 ('P0023', N'2182', 'SSIPEM0001_expediente_btn_guardar_valorizacion', 'editar'),
 ('P0023', N'2182', 'SSIPEM0001_expediente_btn_modifica_fecha_real', 'editar'),
 ('P0023', N'2182', 'SSIPEM0001_expediente_btn_nuevo_accion_monitoreo', 'crear'),
 ('P0023', N'2182', 'SSIPEM0001_expediente_btn_nuevo_ampliacion', 'crear'),
 ('P0023', N'2182', 'SSIPEM0001_expediente_btn_nuevo_aprobacion', 'crear'),
 ('P0023', N'2182', 'SSIPEM0001_expediente_btn_nuevo_contrato', 'crear'),
 ('P0023', N'2182', 'SSIPEM0001_expediente_btn_nuevo_cronograma', 'crear'),
 ('P0023', N'2182', 'SSIPEM0001_expediente_btn_nuevo_paralizacion', 'crear'),
 ('P0023', N'2182', 'SSIPEM0001_expediente_btn_nuevo_resolucion_contrato', 'crear'),
 ('P0023', N'2182', 'SSIPEM0001_expediente_btn_nuevo_responsable', 'crear'),
 ('P0023', N'2182', 'SSIPEM0001_expediente_btn_nuevo_responsable_et', 'crear'),
 ('P0023', N'2182', 'SSIPEM0001_expediente_btn_nuevo_suspension', 'crear'),
 ('P0023', N'2182', 'SSIPEM0001_expediente_btn_nuevo_valorizacion', 'crear'),
 ('P0023', N'2182', 'SSIPEM0001_preinversion_btn_acciones_actividad_monitoreo', 'leer'),
 ('P0023', N'2182', 'SSIPEM0001_preinversion_btn_acciones_ampliacion', 'leer'),
 ('P0023', N'2182', 'SSIPEM0001_preinversion_btn_acciones_avance_programacion', 'leer'),
 ('P0023', N'2182', 'SSIPEM0001_preinversion_btn_acciones_contrato', 'leer'),
 ('P0023', N'2182', 'SSIPEM0001_preinversion_btn_acciones_liquidacion', 'leer'),
 ('P0023', N'2182', 'SSIPEM0001_preinversion_btn_acciones_programacion', 'leer'),
 ('P0023', N'2182', 'SSIPEM0001_preinversion_btn_acciones_recepcion', 'leer'),
 ('P0023', N'2182', 'SSIPEM0001_preinversion_btn_acciones_resolucion_contrato', 'leer'),
 ('P0023', N'2182', 'SSIPEM0001_preinversion_btn_acciones_responsable', 'leer'),
 ('P0023', N'2182', 'SSIPEM0001_preinversion_btn_acciones_responsable_elab', 'leer'),
 ('P0023', N'2182', 'SSIPEM0001_preinversion_btn_guardar_actividad_monitoreo', 'editar'),
 ('P0023', N'2182', 'SSIPEM0001_preinversion_btn_guardar_ampliacion', 'editar'),
 ('P0023', N'2182', 'SSIPEM0001_preinversion_btn_guardar_avance_programacion', 'editar'),
 ('P0023', N'2182', 'SSIPEM0001_preinversion_btn_guardar_contrato', 'editar'),
 ('P0023', N'2182', 'SSIPEM0001_preinversion_btn_guardar_liquidacion', 'editar'),
 ('P0023', N'2182', 'SSIPEM0001_preinversion_btn_guardar_programacion', 'editar'),
 ('P0023', N'2182', 'SSIPEM0001_preinversion_btn_guardar_recepcion', 'editar'),
 ('P0023', N'2182', 'SSIPEM0001_preinversion_btn_guardar_resolucion_contrato', 'editar'),
 ('P0023', N'2182', 'SSIPEM0001_preinversion_btn_guardar_responsable', 'editar'),
 ('P0023', N'2182', 'SSIPEM0001_preinversion_btn_guardar_responsable_elab', 'editar'),
 ('P0023', N'2182', 'SSIPEM0001_preinversion_btn_modifica_fecha_real', 'editar'),
 ('P0023', N'2182', 'SSIPEM0001_preinversion_btn_nuevo_actividad_monitoreo', 'crear'),
 ('P0023', N'2182', 'SSIPEM0001_preinversion_btn_nuevo_ampliacion', 'crear'),
 ('P0023', N'2182', 'SSIPEM0001_preinversion_btn_nuevo_avance_programacion', 'crear'),
 ('P0023', N'2182', 'SSIPEM0001_preinversion_btn_nuevo_contrato', 'crear'),
 ('P0023', N'2182', 'SSIPEM0001_preinversion_btn_nuevo_liquidacion', 'crear'),
 ('P0023', N'2182', 'SSIPEM0001_preinversion_btn_nuevo_programacion', 'crear'),
 ('P0023', N'2182', 'SSIPEM0001_preinversion_btn_nuevo_recepcion', 'crear'),
 ('P0023', N'2182', 'SSIPEM0001_preinversion_btn_nuevo_resolucion_contrato', 'crear'),
 ('P0023', N'2182', 'SSIPEM0001_preinversion_btn_nuevo_responsable', 'crear'),
 ('P0023', N'2182', 'SSIPEM0001_preinversion_btn_nuevo_responsable_elab', 'crear'),
 ('P0023', N'2182', 'SSIPEM0001btn_mostrar_seguimiento', 'leer'),
 ('P0024', N'2182', 'SSIPEM0001_ejecucion_btn_acciones_conservacion', 'leer'),
 ('P0024', N'2182', 'SSIPEM0001_ejecucion_btn_acciones_mejoramiento', 'leer'),
 ('P0024', N'2182', 'SSIPEM0001_ejecucion_btn_acciones_panelfotografico', 'leer'),
 ('P0024', N'2182', 'SSIPEM0001_ejecucion_btn_nuevo_conservacion', 'crear'),
 ('P0024', N'2182', 'SSIPEM0001_ejecucion_btn_nuevo_contrato', 'crear'),
 ('P0024', N'2182', 'SSIPEM0001_ejecucion_btn_nuevo_mejoramiento', 'crear'),
 ('P0024', N'2182', 'SSIPEM0001_ejecucion_btn_nuevo_panelfotografico', 'crear'),
 ('P0024', N'2182', 'SSIPEM0001btn_mostrar_seguimiento', 'leer'),
 ('P0024', N'2183', 'SSIPEM0007btn_acciones_intervencion', 'leer'),
 ('P0024', N'2183', 'SSIPEM0007btn_nueva_intervencion', 'crear'),
 ('P0025', N'2182', 'SSIPEM0001_ejecucion_btn_acciones_adelanto_directo', 'leer'),
 ('P0025', N'2182', 'SSIPEM0001_ejecucion_btn_acciones_adelanto_material', 'leer'),
 ('P0025', N'2182', 'SSIPEM0001_ejecucion_btn_acciones_adicional_deductivo', 'leer'),
 ('P0025', N'2182', 'SSIPEM0001_ejecucion_btn_acciones_ampliacion', 'leer'),
 ('P0025', N'2182', 'SSIPEM0001_ejecucion_btn_acciones_conservacion', 'leer'),
 ('P0025', N'2182', 'SSIPEM0001_ejecucion_btn_acciones_contrato', 'leer'),
 ('P0025', N'2182', 'SSIPEM0001_ejecucion_btn_acciones_cronograma', 'leer'),
 ('P0025', N'2182', 'SSIPEM0001_ejecucion_btn_acciones_impedimento', 'leer'),
 ('P0025', N'2182', 'SSIPEM0001_ejecucion_btn_acciones_interferencia', 'leer'),
 ('P0025', N'2182', 'SSIPEM0001_ejecucion_btn_acciones_liquidacion', 'leer'),
 ('P0025', N'2182', 'SSIPEM0001_ejecucion_btn_acciones_mejoramiento', 'leer'),
 ('P0025', N'2182', 'SSIPEM0001_ejecucion_btn_acciones_otroplazo', 'leer'),
 ('P0025', N'2182', 'SSIPEM0001_ejecucion_btn_acciones_panelfotografico', 'leer'),
 ('P0025', N'2182', 'SSIPEM0001_ejecucion_btn_acciones_paralizacion', 'leer'),
 ('P0025', N'2182', 'SSIPEM0001_ejecucion_btn_acciones_recepcion', 'leer'),
 ('P0025', N'2182', 'SSIPEM0001_ejecucion_btn_acciones_reduccion', 'leer'),
 ('P0025', N'2182', 'SSIPEM0001_ejecucion_btn_acciones_resolucion_contrato', 'leer'),
 ('P0025', N'2182', 'SSIPEM0001_ejecucion_btn_acciones_responsable', 'leer'),
 ('P0025', N'2182', 'SSIPEM0001_ejecucion_btn_acciones_socioambiental', 'leer'),
 ('P0025', N'2182', 'SSIPEM0001_ejecucion_btn_acciones_suspension', 'leer'),
 ('P0025', N'2182', 'SSIPEM0001_ejecucion_btn_acciones_tramo', 'leer'),
 ('P0025', N'2182', 'SSIPEM0001_ejecucion_btn_acciones_transferencia', 'leer'),
 ('P0025', N'2182', 'SSIPEM0001_ejecucion_btn_acciones_valorizacion', 'leer'),
 ('P0025', N'2182', 'SSIPEM0001_ejecucion_btn_acciones_visita_entidad', 'leer'),
 ('P0025', N'2182', 'SSIPEM0001_ejecucion_btn_guardar_adelanto_directo', 'editar'),
 ('P0025', N'2182', 'SSIPEM0001_ejecucion_btn_guardar_adelanto_material', 'editar'),
 ('P0025', N'2182', 'SSIPEM0001_ejecucion_btn_guardar_adicional_deductivo', 'editar'),
 ('P0025', N'2182', 'SSIPEM0001_ejecucion_btn_guardar_ampliacion', 'editar'),
 ('P0025', N'2182', 'SSIPEM0001_ejecucion_btn_guardar_contrato', 'editar'),
 ('P0025', N'2182', 'SSIPEM0001_ejecucion_btn_guardar_cronograma', 'editar'),
 ('P0025', N'2182', 'SSIPEM0001_ejecucion_btn_guardar_impedimento', 'editar'),
 ('P0025', N'2182', 'SSIPEM0001_ejecucion_btn_guardar_interferencia', 'editar'),
 ('P0025', N'2182', 'SSIPEM0001_ejecucion_btn_guardar_liquidacion', 'editar'),
 ('P0025', N'2182', 'SSIPEM0001_ejecucion_btn_guardar_otroplazo', 'editar'),
 ('P0025', N'2182', 'SSIPEM0001_ejecucion_btn_guardar_paralizacion', 'editar'),
 ('P0025', N'2182', 'SSIPEM0001_ejecucion_btn_guardar_recepcion', 'editar'),
 ('P0025', N'2182', 'SSIPEM0001_ejecucion_btn_guardar_reduccion', 'editar'),
 ('P0025', N'2182', 'SSIPEM0001_ejecucion_btn_guardar_resolucion_contrato', 'editar'),
 ('P0025', N'2182', 'SSIPEM0001_ejecucion_btn_guardar_responsable', 'editar'),
 ('P0025', N'2182', 'SSIPEM0001_ejecucion_btn_guardar_suspension', 'editar'),
 ('P0025', N'2182', 'SSIPEM0001_ejecucion_btn_guardar_tramo', 'editar'),
 ('P0025', N'2182', 'SSIPEM0001_ejecucion_btn_guardar_transferencia', 'editar'),
 ('P0025', N'2182', 'SSIPEM0001_ejecucion_btn_guardar_valorizacion', 'editar'),
 ('P0025', N'2182', 'SSIPEM0001_ejecucion_btn_guardar_visita_entidad', 'editar'),
 ('P0025', N'2182', 'SSIPEM0001_ejecucion_btn_modifica_fecha_real', 'editar'),
 ('P0025', N'2182', 'SSIPEM0001_ejecucion_btn_nuevo_adelanto_directo', 'crear'),
 ('P0025', N'2182', 'SSIPEM0001_ejecucion_btn_nuevo_adelanto_material', 'crear'),
 ('P0025', N'2182', 'SSIPEM0001_ejecucion_btn_nuevo_adicional_deductivo', 'crear'),
 ('P0025', N'2182', 'SSIPEM0001_ejecucion_btn_nuevo_ampliacion', 'crear'),
 ('P0025', N'2182', 'SSIPEM0001_ejecucion_btn_nuevo_conservacion', 'crear'),
 ('P0025', N'2182', 'SSIPEM0001_ejecucion_btn_nuevo_contrato', 'crear'),
 ('P0025', N'2182', 'SSIPEM0001_ejecucion_btn_nuevo_cronograma', 'crear'),
 ('P0025', N'2182', 'SSIPEM0001_ejecucion_btn_nuevo_impedimento', 'crear'),
 ('P0025', N'2182', 'SSIPEM0001_ejecucion_btn_nuevo_interferencia', 'crear'),
 ('P0025', N'2182', 'SSIPEM0001_ejecucion_btn_nuevo_liquidacion', 'crear'),
 ('P0025', N'2182', 'SSIPEM0001_ejecucion_btn_nuevo_mejoramiento', 'crear'),
 ('P0025', N'2182', 'SSIPEM0001_ejecucion_btn_nuevo_otroplazo', 'crear'),
 ('P0025', N'2182', 'SSIPEM0001_ejecucion_btn_nuevo_panelfotografico', 'crear'),
 ('P0025', N'2182', 'SSIPEM0001_ejecucion_btn_nuevo_paralizacion', 'crear'),
 ('P0025', N'2182', 'SSIPEM0001_ejecucion_btn_nuevo_recepcion', 'crear'),
 ('P0025', N'2182', 'SSIPEM0001_ejecucion_btn_nuevo_reduccion', 'crear'),
 ('P0025', N'2182', 'SSIPEM0001_ejecucion_btn_nuevo_resolucion_contrato', 'crear'),
 ('P0025', N'2182', 'SSIPEM0001_ejecucion_btn_nuevo_responsable', 'crear'),
 ('P0025', N'2182', 'SSIPEM0001_ejecucion_btn_nuevo_socioambiental', 'crear'),
 ('P0025', N'2182', 'SSIPEM0001_ejecucion_btn_nuevo_suspension', 'crear'),
 ('P0025', N'2182', 'SSIPEM0001_ejecucion_btn_nuevo_tramo', 'crear'),
 ('P0025', N'2182', 'SSIPEM0001_ejecucion_btn_nuevo_transferencia', 'crear'),
 ('P0025', N'2182', 'SSIPEM0001_ejecucion_btn_nuevo_valorizacion', 'crear'),
 ('P0025', N'2182', 'SSIPEM0001_ejecucion_btn_nuevo_visita_entidad', 'crear'),
 ('P0025', N'2182', 'SSIPEM0001_ejecucion_btn_vincular_proceso', 'crear'),
 ('P0025', N'2182', 'SSIPEM0001btn_mostrar_seguimiento', 'leer'),
 ('P0025', N'2183', 'SSIPEM0007btn_acciones_intervencion', 'leer'),
 ('P0025', N'2183', 'SSIPEM0007btn_nueva_intervencion', 'crear'),
 ('P0025', N'2184', 'SSIPEM0043btn_acciones_convenio', 'leer'),
 ('P0025', N'2184', 'SSIPEM0043btn_nuevo_convenio', 'crear'),
 ('P0027', N'2182', 'SSIPEM0001_expediente_btn_acciones_accion_monitoreo', 'leer'),
 ('P0027', N'2182', 'SSIPEM0001_expediente_btn_acciones_ampliacion', 'leer'),
 ('P0027', N'2182', 'SSIPEM0001_expediente_btn_acciones_aprobacion', 'leer'),
 ('P0027', N'2182', 'SSIPEM0001_expediente_btn_acciones_contrato', 'leer'),
 ('P0027', N'2182', 'SSIPEM0001_expediente_btn_acciones_cronograma', 'leer'),
 ('P0027', N'2182', 'SSIPEM0001_expediente_btn_acciones_paralizacion', 'leer'),
 ('P0027', N'2182', 'SSIPEM0001_expediente_btn_acciones_resolucion_contrato', 'leer'),
 ('P0027', N'2182', 'SSIPEM0001_expediente_btn_acciones_responsable', 'leer'),
 ('P0027', N'2182', 'SSIPEM0001_expediente_btn_acciones_responsable_et', 'leer'),
 ('P0027', N'2182', 'SSIPEM0001_expediente_btn_acciones_suspension', 'leer'),
 ('P0027', N'2182', 'SSIPEM0001_expediente_btn_acciones_valorizacion', 'leer'),
 ('P0027', N'2182', 'SSIPEM0001_expediente_btn_guardar_accion_monitoreo', 'editar'),
 ('P0027', N'2182', 'SSIPEM0001_expediente_btn_guardar_ampliacion', 'editar'),
 ('P0027', N'2182', 'SSIPEM0001_expediente_btn_guardar_aprobacion', 'editar'),
 ('P0027', N'2182', 'SSIPEM0001_expediente_btn_guardar_contrato', 'editar'),
 ('P0027', N'2182', 'SSIPEM0001_expediente_btn_guardar_cronograma', 'editar'),
 ('P0027', N'2182', 'SSIPEM0001_expediente_btn_guardar_paralizacion', 'editar'),
 ('P0027', N'2182', 'SSIPEM0001_expediente_btn_guardar_resolucion_contrato', 'editar'),
 ('P0027', N'2182', 'SSIPEM0001_expediente_btn_guardar_responsable', 'editar'),
 ('P0027', N'2182', 'SSIPEM0001_expediente_btn_guardar_responsable_et', 'editar'),
 ('P0027', N'2182', 'SSIPEM0001_expediente_btn_guardar_suspension', 'editar'),
 ('P0027', N'2182', 'SSIPEM0001_expediente_btn_guardar_valorizacion', 'editar'),
 ('P0027', N'2182', 'SSIPEM0001_expediente_btn_modifica_fecha_real', 'editar'),
 ('P0027', N'2182', 'SSIPEM0001_expediente_btn_nuevo_accion_monitoreo', 'crear'),
 ('P0027', N'2182', 'SSIPEM0001_expediente_btn_nuevo_ampliacion', 'crear'),
 ('P0027', N'2182', 'SSIPEM0001_expediente_btn_nuevo_aprobacion', 'crear'),
 ('P0027', N'2182', 'SSIPEM0001_expediente_btn_nuevo_contrato', 'crear'),
 ('P0027', N'2182', 'SSIPEM0001_expediente_btn_nuevo_cronograma', 'crear'),
 ('P0027', N'2182', 'SSIPEM0001_expediente_btn_nuevo_paralizacion', 'crear'),
 ('P0027', N'2182', 'SSIPEM0001_expediente_btn_nuevo_resolucion_contrato', 'crear'),
 ('P0027', N'2182', 'SSIPEM0001_expediente_btn_nuevo_responsable', 'crear'),
 ('P0027', N'2182', 'SSIPEM0001_expediente_btn_nuevo_responsable_et', 'crear'),
 ('P0027', N'2182', 'SSIPEM0001_expediente_btn_nuevo_suspension', 'crear'),
 ('P0027', N'2182', 'SSIPEM0001_expediente_btn_nuevo_valorizacion', 'crear'),
 ('P0027', N'2183', 'SSIPEM0007btn_acciones_intervencion', 'leer'),
 ('P0027', N'2183', 'SSIPEM0007btn_cambio_fase', 'editar'),
 ('P0027', N'2183', 'SSIPEM0007btn_nueva_intervencion', 'crear'),
 ('P0027', N'2184', 'SSIPEM0043btn_acciones_convenio', 'leer'),
 ('P0027', N'2184', 'SSIPEM0043btn_nuevo_convenio', 'crear'),
 ('P0028', N'2182', 'SSIPEM0001_expediente_btn_acciones_accion_monitoreo', 'leer'),
 ('P0028', N'2182', 'SSIPEM0001_expediente_btn_acciones_ampliacion', 'leer'),
 ('P0028', N'2182', 'SSIPEM0001_expediente_btn_acciones_aprobacion', 'leer'),
 ('P0028', N'2182', 'SSIPEM0001_expediente_btn_acciones_contrato', 'leer'),
 ('P0028', N'2182', 'SSIPEM0001_expediente_btn_acciones_cronograma', 'leer'),
 ('P0028', N'2182', 'SSIPEM0001_expediente_btn_acciones_paralizacion', 'leer'),
 ('P0028', N'2182', 'SSIPEM0001_expediente_btn_acciones_resolucion_contrato', 'leer'),
 ('P0028', N'2182', 'SSIPEM0001_expediente_btn_acciones_responsable', 'leer'),
 ('P0028', N'2182', 'SSIPEM0001_expediente_btn_acciones_responsable_et', 'leer'),
 ('P0028', N'2182', 'SSIPEM0001_expediente_btn_acciones_suspension', 'leer'),
 ('P0028', N'2182', 'SSIPEM0001_expediente_btn_acciones_valorizacion', 'leer'),
 ('P0028', N'2182', 'SSIPEM0001_expediente_btn_guardar_accion_monitoreo', 'editar'),
 ('P0028', N'2182', 'SSIPEM0001_expediente_btn_guardar_ampliacion', 'editar'),
 ('P0028', N'2182', 'SSIPEM0001_expediente_btn_guardar_aprobacion', 'editar'),
 ('P0028', N'2182', 'SSIPEM0001_expediente_btn_guardar_contrato', 'editar'),
 ('P0028', N'2182', 'SSIPEM0001_expediente_btn_guardar_cronograma', 'editar'),
 ('P0028', N'2182', 'SSIPEM0001_expediente_btn_guardar_paralizacion', 'editar'),
 ('P0028', N'2182', 'SSIPEM0001_expediente_btn_guardar_resolucion_contrato', 'editar'),
 ('P0028', N'2182', 'SSIPEM0001_expediente_btn_guardar_responsable', 'editar'),
 ('P0028', N'2182', 'SSIPEM0001_expediente_btn_guardar_responsable_et', 'editar'),
 ('P0028', N'2182', 'SSIPEM0001_expediente_btn_guardar_suspension', 'editar'),
 ('P0028', N'2182', 'SSIPEM0001_expediente_btn_guardar_valorizacion', 'editar'),
 ('P0028', N'2182', 'SSIPEM0001_expediente_btn_modifica_fecha_real', 'editar'),
 ('P0028', N'2182', 'SSIPEM0001_expediente_btn_nuevo_accion_monitoreo', 'crear'),
 ('P0028', N'2182', 'SSIPEM0001_expediente_btn_nuevo_ampliacion', 'crear'),
 ('P0028', N'2182', 'SSIPEM0001_expediente_btn_nuevo_aprobacion', 'crear'),
 ('P0028', N'2182', 'SSIPEM0001_expediente_btn_nuevo_contrato', 'crear'),
 ('P0028', N'2182', 'SSIPEM0001_expediente_btn_nuevo_cronograma', 'crear'),
 ('P0028', N'2182', 'SSIPEM0001_expediente_btn_nuevo_paralizacion', 'crear'),
 ('P0028', N'2182', 'SSIPEM0001_expediente_btn_nuevo_resolucion_contrato', 'crear'),
 ('P0028', N'2182', 'SSIPEM0001_expediente_btn_nuevo_responsable', 'crear'),
 ('P0028', N'2182', 'SSIPEM0001_expediente_btn_nuevo_responsable_et', 'crear'),
 ('P0028', N'2182', 'SSIPEM0001_expediente_btn_nuevo_suspension', 'crear'),
 ('P0028', N'2182', 'SSIPEM0001_expediente_btn_nuevo_valorizacion', 'crear'),
 ('P0029', N'2182', 'SSIPEM0001_preinversion_btn_acciones_actividad_monitoreo', 'leer'),
 ('P0029', N'2182', 'SSIPEM0001_preinversion_btn_acciones_ampliacion', 'leer'),
 ('P0029', N'2182', 'SSIPEM0001_preinversion_btn_acciones_avance_programacion', 'leer'),
 ('P0029', N'2182', 'SSIPEM0001_preinversion_btn_acciones_contrato', 'leer'),
 ('P0029', N'2182', 'SSIPEM0001_preinversion_btn_acciones_liquidacion', 'leer'),
 ('P0029', N'2182', 'SSIPEM0001_preinversion_btn_acciones_programacion', 'leer'),
 ('P0029', N'2182', 'SSIPEM0001_preinversion_btn_acciones_recepcion', 'leer'),
 ('P0029', N'2182', 'SSIPEM0001_preinversion_btn_acciones_resolucion_contrato', 'leer'),
 ('P0029', N'2182', 'SSIPEM0001_preinversion_btn_acciones_responsable', 'leer'),
 ('P0029', N'2182', 'SSIPEM0001_preinversion_btn_acciones_responsable_elab', 'leer'),
 ('P0029', N'2182', 'SSIPEM0001_preinversion_btn_eliminar_ampliacion', 'eliminar'),
 ('P0029', N'2182', 'SSIPEM0001_preinversion_btn_guardar_actividad_monitoreo', 'editar'),
 ('P0029', N'2182', 'SSIPEM0001_preinversion_btn_guardar_ampliacion', 'editar'),
 ('P0029', N'2182', 'SSIPEM0001_preinversion_btn_guardar_avance_programacion', 'editar'),
 ('P0029', N'2182', 'SSIPEM0001_preinversion_btn_guardar_contrato', 'editar'),
 ('P0029', N'2182', 'SSIPEM0001_preinversion_btn_guardar_liquidacion', 'editar'),
 ('P0029', N'2182', 'SSIPEM0001_preinversion_btn_guardar_programacion', 'editar'),
 ('P0029', N'2182', 'SSIPEM0001_preinversion_btn_guardar_recepcion', 'editar'),
 ('P0029', N'2182', 'SSIPEM0001_preinversion_btn_guardar_resolucion_contrato', 'editar'),
 ('P0029', N'2182', 'SSIPEM0001_preinversion_btn_guardar_responsable', 'editar'),
 ('P0029', N'2182', 'SSIPEM0001_preinversion_btn_guardar_responsable_elab', 'editar'),
 ('P0029', N'2182', 'SSIPEM0001_preinversion_btn_modifica_fecha_real', 'editar'),
 ('P0029', N'2182', 'SSIPEM0001_preinversion_btn_nuevo_actividad_monitoreo', 'crear'),
 ('P0029', N'2182', 'SSIPEM0001_preinversion_btn_nuevo_ampliacion', 'crear'),
 ('P0029', N'2182', 'SSIPEM0001_preinversion_btn_nuevo_avance_programacion', 'crear'),
 ('P0029', N'2182', 'SSIPEM0001_preinversion_btn_nuevo_contrato', 'crear'),
 ('P0029', N'2182', 'SSIPEM0001_preinversion_btn_nuevo_liquidacion', 'crear'),
 ('P0029', N'2182', 'SSIPEM0001_preinversion_btn_nuevo_programacion', 'crear'),
 ('P0029', N'2182', 'SSIPEM0001_preinversion_btn_nuevo_recepcion', 'crear'),
 ('P0029', N'2182', 'SSIPEM0001_preinversion_btn_nuevo_resolucion_contrato', 'crear'),
 ('P0029', N'2182', 'SSIPEM0001_preinversion_btn_nuevo_responsable', 'crear'),
 ('P0029', N'2182', 'SSIPEM0001_preinversion_btn_nuevo_responsable_elab', 'crear'),
 ('P0042', N'2182', 'SSIPEM0001_btn_acciones_programacion_perfil', 'leer'),
 ('P0042', N'2182', 'SSIPEM0001_btn_guardar_programacion_perfil', 'editar'),
 ('P0043', N'2182', 'SSIPEM0001_btn_acciones_actos_preparatorios', 'leer'),
 ('P0043', N'2182', 'SSIPEM0001_btn_acciones_adendas_sup', 'leer'),
 ('P0043', N'2182', 'SSIPEM0001_btn_acciones_ampliaciones', 'leer'),
 ('P0043', N'2182', 'SSIPEM0001_btn_acciones_comisiones_visitas', 'leer'),
 ('P0043', N'2182', 'SSIPEM0001_btn_acciones_comite_seleccion', 'leer'),
 ('P0043', N'2182', 'SSIPEM0001_btn_acciones_convocatoria_osce', 'leer'),
 ('P0043', N'2182', 'SSIPEM0001_btn_acciones_fase_seleccion', 'leer'),
 ('P0043', N'2182', 'SSIPEM0001_btn_acciones_liquidacion_contrato', 'leer'),
 ('P0043', N'2182', 'SSIPEM0001_btn_acciones_maquinaria', 'leer'),
 ('P0043', N'2182', 'SSIPEM0001_btn_acciones_maquinaria_sup', 'leer'),
 ('P0043', N'2182', 'SSIPEM0001_btn_acciones_modificaciones_gastos', 'editar'),
 ('P0043', N'2182', 'SSIPEM0001_btn_acciones_panel_fotografico', 'leer'),
 ('P0043', N'2182', 'SSIPEM0001_btn_acciones_paralizaciones', 'leer'),
 ('P0043', N'2182', 'SSIPEM0001_btn_acciones_paralizaciones_det', 'leer'),
 ('P0043', N'2182', 'SSIPEM0001_btn_acciones_personal_clave', 'leer'),
 ('P0043', N'2182', 'SSIPEM0001_btn_acciones_personal_clave_sup', 'leer'),
 ('P0043', N'2182', 'SSIPEM0001_btn_acciones_programacion_perfil', 'leer'),
 ('P0043', N'2182', 'SSIPEM0001_btn_acciones_recepcion_pats', 'leer'),
 ('P0043', N'2182', 'SSIPEM0001_btn_acciones_resolucion_contrato_pats', 'leer'),
 ('P0043', N'2182', 'SSIPEM0001_btn_acciones_riesgos', 'leer'),
 ('P0043', N'2182', 'SSIPEM0001_btn_acciones_suspensiones', 'leer'),
 ('P0043', N'2182', 'SSIPEM0001_btn_acciones_suspensiones_det', 'leer'),
 ('P0043', N'2182', 'SSIPEM0001_btn_acciones_tramo_proyecto', 'leer'),
 ('P0043', N'2182', 'SSIPEM0001_btn_acciones_transferencia_pats', 'leer'),
 ('P0043', N'2182', 'SSIPEM0001_btn_acciones_valorizaciones_base', 'leer'),
 ('P0043', N'2182', 'SSIPEM0001_btn_acciones_valorizaciones_supervision', 'leer'),
 ('P0043', N'2182', 'SSIPEM0001_btn_acciones_variaciones', 'leer'),
 ('P0043', N'2182', 'SSIPEM0001_btn_acciones_variaciones_det', 'leer'),
 ('P0043', N'2182', 'SSIPEM0001_btn_acciones_variaciones_supervision', 'leer'),
 ('P0043', N'2182', 'SSIPEM0001_btn_editar_comite_seleccion', 'editar'),
 ('P0043', N'2182', 'SSIPEM0001_btn_editar_fase_seleccion', 'editar'),
 ('P0043', N'2182', 'SSIPEM0001_btn_guardar_actos_preparatorios', 'editar'),
 ('P0043', N'2182', 'SSIPEM0001_btn_guardar_adendas_sup', 'editar'),
 ('P0043', N'2182', 'SSIPEM0001_btn_guardar_ampliaciones', 'editar'),
 ('P0043', N'2182', 'SSIPEM0001_btn_guardar_comisiones_visitas', 'editar'),
 ('P0043', N'2182', 'SSIPEM0001_btn_guardar_comite_seleccion', 'editar'),
 ('P0043', N'2182', 'SSIPEM0001_btn_guardar_contrato_ejecucion', 'editar'),
 ('P0043', N'2182', 'SSIPEM0001_btn_guardar_contrato_supervision', 'editar'),
 ('P0043', N'2182', 'SSIPEM0001_btn_guardar_convocatoria_osce', 'editar'),
 ('P0043', N'2182', 'SSIPEM0001_btn_guardar_estado_situacional', 'editar'),
 ('P0043', N'2182', 'SSIPEM0001_btn_guardar_estado_situacional_sup', 'editar'),
 ('P0043', N'2182', 'SSIPEM0001_btn_guardar_fase_seleccion', 'editar'),
 ('P0043', N'2182', 'SSIPEM0001_btn_guardar_liquidacion_contrato', 'editar'),
 ('P0043', N'2182', 'SSIPEM0001_btn_guardar_maquinaria', 'editar'),
 ('P0043', N'2182', 'SSIPEM0001_btn_guardar_maquinaria_sup', 'editar'),
 ('P0043', N'2182', 'SSIPEM0001_btn_guardar_modificaciones_gastos', 'editar'),
 ('P0043', N'2182', 'SSIPEM0001_btn_guardar_paralizaciones', 'editar'),
 ('P0043', N'2182', 'SSIPEM0001_btn_guardar_paralizaciones_det', 'editar'),
 ('P0043', N'2182', 'SSIPEM0001_btn_guardar_personal_clave', 'editar'),
 ('P0043', N'2182', 'SSIPEM0001_btn_guardar_personal_clave_sup', 'editar'),
 ('P0043', N'2182', 'SSIPEM0001_btn_guardar_programacion_perfil', 'editar'),
 ('P0043', N'2182', 'SSIPEM0001_btn_guardar_recepcion_pats', 'editar'),
 ('P0043', N'2182', 'SSIPEM0001_btn_guardar_resolucion_contrato_pats', 'editar'),
 ('P0043', N'2182', 'SSIPEM0001_btn_guardar_riesgos', 'editar'),
 ('P0043', N'2182', 'SSIPEM0001_btn_guardar_suspensiones', 'editar'),
 ('P0043', N'2182', 'SSIPEM0001_btn_guardar_suspensiones_det', 'editar'),
 ('P0043', N'2182', 'SSIPEM0001_btn_guardar_tramo_proyecto', 'editar'),
 ('P0043', N'2182', 'SSIPEM0001_btn_guardar_transferencia_pats', 'editar'),
 ('P0043', N'2182', 'SSIPEM0001_btn_guardar_valorizaciones_base', 'editar'),
 ('P0043', N'2182', 'SSIPEM0001_btn_guardar_valorizaciones_supervision', 'editar'),
 ('P0043', N'2182', 'SSIPEM0001_btn_guardar_variaciones', 'editar'),
 ('P0043', N'2182', 'SSIPEM0001_btn_guardar_variaciones_det', 'editar'),
 ('P0043', N'2182', 'SSIPEM0001_btn_guardar_variaciones_supervision', 'editar'),
 ('P0043', N'2182', 'SSIPEM0001_btn_nuevo_actos_preparatorios', 'crear'),
 ('P0043', N'2182', 'SSIPEM0001_btn_nuevo_adendas_sup', 'crear'),
 ('P0043', N'2182', 'SSIPEM0001_btn_nuevo_ampliaciones', 'crear'),
 ('P0043', N'2182', 'SSIPEM0001_btn_nuevo_comisiones_visitas', 'crear'),
 ('P0043', N'2182', 'SSIPEM0001_btn_nuevo_comite_seleccion', 'crear'),
 ('P0043', N'2182', 'SSIPEM0001_btn_nuevo_convocatoria_osce', 'crear'),
 ('P0043', N'2182', 'SSIPEM0001_btn_nuevo_fase_seleccion', 'crear'),
 ('P0043', N'2182', 'SSIPEM0001_btn_nuevo_liquidacion_contrato', 'crear'),
 ('P0043', N'2182', 'SSIPEM0001_btn_nuevo_maquinaria', 'crear'),
 ('P0043', N'2182', 'SSIPEM0001_btn_nuevo_maquinaria_sup', 'crear'),
 ('P0043', N'2182', 'SSIPEM0001_btn_nuevo_modificaciones_gastos', 'crear'),
 ('P0043', N'2182', 'SSIPEM0001_btn_nuevo_panel_fotografico', 'crear'),
 ('P0043', N'2182', 'SSIPEM0001_btn_nuevo_paralizaciones', 'crear'),
 ('P0043', N'2182', 'SSIPEM0001_btn_nuevo_paralizaciones_det', 'crear'),
 ('P0043', N'2182', 'SSIPEM0001_btn_nuevo_personal_clave', 'crear'),
 ('P0043', N'2182', 'SSIPEM0001_btn_nuevo_personal_clave_sup', 'crear'),
 ('P0043', N'2182', 'SSIPEM0001_btn_nuevo_recepcion_pats', 'crear'),
 ('P0043', N'2182', 'SSIPEM0001_btn_nuevo_resolucion_contrato_pats', 'crear'),
 ('P0043', N'2182', 'SSIPEM0001_btn_nuevo_riesgos', 'crear'),
 ('P0043', N'2182', 'SSIPEM0001_btn_nuevo_suspensiones', 'crear'),
 ('P0043', N'2182', 'SSIPEM0001_btn_nuevo_suspensiones_det', 'crear'),
 ('P0043', N'2182', 'SSIPEM0001_btn_nuevo_tramo_proyecto', 'crear'),
 ('P0043', N'2182', 'SSIPEM0001_btn_nuevo_transferencia_pats', 'crear'),
 ('P0043', N'2182', 'SSIPEM0001_btn_nuevo_variaciones', 'crear'),
 ('P0043', N'2182', 'SSIPEM0001_btn_nuevo_variaciones_det', 'crear'),
 ('P0043', N'2182', 'SSIPEM0001_btn_nuevo_variaciones_supervision', 'crear'),
 ('P0044', N'2182', 'SSIPEM0001_btn_acciones_actos_preparatorios', 'leer'),
 ('P0044', N'2182', 'SSIPEM0001_btn_acciones_actos_preparatorios_et', 'leer'),
 ('P0044', N'2182', 'SSIPEM0001_btn_acciones_adendas_sup', 'leer'),
 ('P0044', N'2182', 'SSIPEM0001_btn_acciones_ampliaciones', 'leer'),
 ('P0044', N'2182', 'SSIPEM0001_btn_acciones_ampliaciones_et', 'leer'),
 ('P0044', N'2182', 'SSIPEM0001_btn_acciones_comisiones_visitas', 'leer'),
 ('P0044', N'2182', 'SSIPEM0001_btn_acciones_comite_seleccion', 'leer'),
 ('P0044', N'2182', 'SSIPEM0001_btn_acciones_convocatoria_osce', 'leer'),
 ('P0044', N'2182', 'SSIPEM0001_btn_acciones_convocatoria_osce_et', 'leer'),
 ('P0044', N'2182', 'SSIPEM0001_btn_acciones_dispositivo_financiero_et', 'leer'),
 ('P0044', N'2182', 'SSIPEM0001_btn_acciones_entregables_et', 'leer'),
 ('P0044', N'2182', 'SSIPEM0001_btn_acciones_fase_seleccion', 'leer'),
 ('P0044', N'2182', 'SSIPEM0001_btn_acciones_fase_seleccion_et', 'leer'),
 ('P0044', N'2182', 'SSIPEM0001_btn_acciones_liquidacion_contrato', 'leer'),
 ('P0044', N'2182', 'SSIPEM0001_btn_acciones_liquidacion_contrato_et', 'leer'),
 ('P0044', N'2182', 'SSIPEM0001_btn_acciones_maquinaria', 'leer'),
 ('P0044', N'2182', 'SSIPEM0001_btn_acciones_maquinaria_sup', 'leer'),
 ('P0044', N'2182', 'SSIPEM0001_btn_acciones_modificaciones_gastos', 'editar'),
 ('P0044', N'2182', 'SSIPEM0001_btn_acciones_observaciones_entregable_et', 'leer'),
 ('P0044', N'2182', 'SSIPEM0001_btn_acciones_pagos_entregable_et', 'leer'),
 ('P0044', N'2182', 'SSIPEM0001_btn_acciones_panel_fotografico', 'leer'),
 ('P0044', N'2182', 'SSIPEM0001_btn_acciones_paralizaciones', 'leer'),
 ('P0044', N'2182', 'SSIPEM0001_btn_acciones_paralizaciones_det', 'leer'),
 ('P0044', N'2182', 'SSIPEM0001_btn_acciones_paralizaciones_det_et', 'leer'),
 ('P0044', N'2182', 'SSIPEM0001_btn_acciones_paralizaciones_et', 'leer'),
 ('P0044', N'2182', 'SSIPEM0001_btn_acciones_personal_clave', 'leer'),
 ('P0044', N'2182', 'SSIPEM0001_btn_acciones_personal_clave_sup', 'leer'),
 ('P0044', N'2182', 'SSIPEM0001_btn_acciones_programacion_perfil', 'leer'),
 ('P0044', N'2182', 'SSIPEM0001_btn_acciones_programacion_perfil_et', 'leer'),
 ('P0044', N'2182', 'SSIPEM0001_btn_acciones_recepcion_et', 'leer'),
 ('P0044', N'2182', 'SSIPEM0001_btn_acciones_recepcion_pats', 'leer'),
 ('P0044', N'2182', 'SSIPEM0001_btn_acciones_resolucion_contrato_et', 'leer'),
 ('P0044', N'2182', 'SSIPEM0001_btn_acciones_resolucion_contrato_pats', 'leer'),
 ('P0044', N'2182', 'SSIPEM0001_btn_acciones_riesgos', 'leer'),
 ('P0044', N'2182', 'SSIPEM0001_btn_acciones_riesgos_et', 'leer'),
 ('P0044', N'2182', 'SSIPEM0001_btn_acciones_suspensiones', 'leer'),
 ('P0044', N'2182', 'SSIPEM0001_btn_acciones_suspensiones_det', 'leer'),
 ('P0044', N'2182', 'SSIPEM0001_btn_acciones_suspensiones_det_et', 'leer'),
 ('P0044', N'2182', 'SSIPEM0001_btn_acciones_suspensiones_et', 'leer'),
 ('P0044', N'2182', 'SSIPEM0001_btn_acciones_tramo_proyecto', 'leer'),
 ('P0044', N'2182', 'SSIPEM0001_btn_acciones_tramo_proyecto_et', 'leer'),
 ('P0044', N'2182', 'SSIPEM0001_btn_acciones_transferencia_et', 'leer'),
 ('P0044', N'2182', 'SSIPEM0001_btn_acciones_transferencia_pats', 'leer'),
 ('P0044', N'2182', 'SSIPEM0001_btn_acciones_valorizaciones_base', 'leer'),
 ('P0044', N'2182', 'SSIPEM0001_btn_acciones_valorizaciones_supervision', 'leer'),
 ('P0044', N'2182', 'SSIPEM0001_btn_acciones_variaciones', 'leer'),
 ('P0044', N'2182', 'SSIPEM0001_btn_acciones_variaciones_det', 'leer'),
 ('P0044', N'2182', 'SSIPEM0001_btn_acciones_variaciones_supervision', 'leer'),
 ('P0044', N'2182', 'SSIPEM0001_btn_editar_comite_seleccion', 'editar'),
 ('P0044', N'2182', 'SSIPEM0001_btn_editar_fase_seleccion', 'editar'),
 ('P0044', N'2182', 'SSIPEM0001_btn_guardar_actos_preparatorios', 'editar'),
 ('P0044', N'2182', 'SSIPEM0001_btn_guardar_actos_preparatorios_et', 'editar'),
 ('P0044', N'2182', 'SSIPEM0001_btn_guardar_adendas_sup', 'editar'),
 ('P0044', N'2182', 'SSIPEM0001_btn_guardar_ampliaciones', 'editar'),
 ('P0044', N'2182', 'SSIPEM0001_btn_guardar_ampliaciones_et', 'editar'),
 ('P0044', N'2182', 'SSIPEM0001_btn_guardar_comisiones_visitas', 'editar'),
 ('P0044', N'2182', 'SSIPEM0001_btn_guardar_comite_seleccion', 'editar'),
 ('P0044', N'2182', 'SSIPEM0001_btn_guardar_contrato_ejecucion', 'editar'),
 ('P0044', N'2182', 'SSIPEM0001_btn_guardar_contrato_estudio_et', 'editar'),
 ('P0044', N'2182', 'SSIPEM0001_btn_guardar_contrato_supervision', 'editar'),
 ('P0044', N'2182', 'SSIPEM0001_btn_guardar_convocatoria_osce', 'editar'),
 ('P0044', N'2182', 'SSIPEM0001_btn_guardar_convocatoria_osce_et', 'editar'),
 ('P0044', N'2182', 'SSIPEM0001_btn_guardar_dispositivo_financiero_et', 'editar'),
 ('P0044', N'2182', 'SSIPEM0001_btn_guardar_entregables_et', 'editar'),
 ('P0044', N'2182', 'SSIPEM0001_btn_guardar_estado_situacional', 'editar'),
 ('P0044', N'2182', 'SSIPEM0001_btn_guardar_estado_situacional_et', 'editar'),
 ('P0044', N'2182', 'SSIPEM0001_btn_guardar_estado_situacional_sup', 'editar'),
 ('P0044', N'2182', 'SSIPEM0001_btn_guardar_fase_seleccion', 'editar'),
 ('P0044', N'2182', 'SSIPEM0001_btn_guardar_fase_seleccion_et', 'editar'),
 ('P0044', N'2182', 'SSIPEM0001_btn_guardar_liquidacion_contrato', 'editar'),
 ('P0044', N'2182', 'SSIPEM0001_btn_guardar_liquidacion_contrato_et', 'editar'),
 ('P0044', N'2182', 'SSIPEM0001_btn_guardar_maquinaria', 'editar'),
 ('P0044', N'2182', 'SSIPEM0001_btn_guardar_maquinaria_sup', 'editar'),
 ('P0044', N'2182', 'SSIPEM0001_btn_guardar_modificaciones_gastos', 'editar'),
 ('P0044', N'2182', 'SSIPEM0001_btn_guardar_observaciones_entregable_et', 'editar'),
 ('P0044', N'2182', 'SSIPEM0001_btn_guardar_pagos_entregable_et', 'editar'),
 ('P0044', N'2182', 'SSIPEM0001_btn_guardar_paralizaciones', 'editar'),
 ('P0044', N'2182', 'SSIPEM0001_btn_guardar_paralizaciones_det', 'editar'),
 ('P0044', N'2182', 'SSIPEM0001_btn_guardar_paralizaciones_det_et', 'editar'),
 ('P0044', N'2182', 'SSIPEM0001_btn_guardar_paralizaciones_et', 'editar'),
 ('P0044', N'2182', 'SSIPEM0001_btn_guardar_personal_clave', 'editar'),
 ('P0044', N'2182', 'SSIPEM0001_btn_guardar_personal_clave_sup', 'editar'),
 ('P0044', N'2182', 'SSIPEM0001_btn_guardar_programacion_perfil', 'editar'),
 ('P0044', N'2182', 'SSIPEM0001_btn_guardar_programacion_perfil_et', 'editar'),
 ('P0044', N'2182', 'SSIPEM0001_btn_guardar_recepcion_et', 'editar'),
 ('P0044', N'2182', 'SSIPEM0001_btn_guardar_recepcion_pats', 'editar'),
 ('P0044', N'2182', 'SSIPEM0001_btn_guardar_resolucion_contrato_et', 'editar'),
 ('P0044', N'2182', 'SSIPEM0001_btn_guardar_resolucion_contrato_pats', 'editar'),
 ('P0044', N'2182', 'SSIPEM0001_btn_guardar_riesgos', 'editar'),
 ('P0044', N'2182', 'SSIPEM0001_btn_guardar_riesgos_et', 'editar'),
 ('P0044', N'2182', 'SSIPEM0001_btn_guardar_suspensiones', 'editar'),
 ('P0044', N'2182', 'SSIPEM0001_btn_guardar_suspensiones_det', 'editar'),
 ('P0044', N'2182', 'SSIPEM0001_btn_guardar_suspensiones_det_et', 'editar'),
 ('P0044', N'2182', 'SSIPEM0001_btn_guardar_suspensiones_et', 'editar'),
 ('P0044', N'2182', 'SSIPEM0001_btn_guardar_tramo_proyecto', 'editar'),
 ('P0044', N'2182', 'SSIPEM0001_btn_guardar_tramo_proyecto_et', 'editar'),
 ('P0044', N'2182', 'SSIPEM0001_btn_guardar_transferencia_et', 'editar'),
 ('P0044', N'2182', 'SSIPEM0001_btn_guardar_transferencia_pats', 'editar'),
 ('P0044', N'2182', 'SSIPEM0001_btn_guardar_valorizaciones_base', 'editar'),
 ('P0044', N'2182', 'SSIPEM0001_btn_guardar_valorizaciones_supervision', 'editar'),
 ('P0044', N'2182', 'SSIPEM0001_btn_guardar_variaciones', 'editar'),
 ('P0044', N'2182', 'SSIPEM0001_btn_guardar_variaciones_det', 'editar'),
 ('P0044', N'2182', 'SSIPEM0001_btn_guardar_variaciones_supervision', 'editar'),
 ('P0044', N'2182', 'SSIPEM0001_btn_nuevo_actos_preparatorios', 'crear'),
 ('P0044', N'2182', 'SSIPEM0001_btn_nuevo_actos_preparatorios_et', 'crear'),
 ('P0044', N'2182', 'SSIPEM0001_btn_nuevo_adendas_sup', 'crear'),
 ('P0044', N'2182', 'SSIPEM0001_btn_nuevo_ampliaciones', 'crear'),
 ('P0044', N'2182', 'SSIPEM0001_btn_nuevo_ampliaciones_et', 'crear'),
 ('P0044', N'2182', 'SSIPEM0001_btn_nuevo_comisiones_visitas', 'crear'),
 ('P0044', N'2182', 'SSIPEM0001_btn_nuevo_comite_seleccion', 'crear'),
 ('P0044', N'2182', 'SSIPEM0001_btn_nuevo_convocatoria_osce', 'crear'),
 ('P0044', N'2182', 'SSIPEM0001_btn_nuevo_convocatoria_osce_et', 'crear'),
 ('P0044', N'2182', 'SSIPEM0001_btn_nuevo_dispositivo_financiero_et', 'crear'),
 ('P0044', N'2182', 'SSIPEM0001_btn_nuevo_fase_seleccion', 'crear'),
 ('P0044', N'2182', 'SSIPEM0001_btn_nuevo_fase_seleccion_et', 'crear'),
 ('P0044', N'2182', 'SSIPEM0001_btn_nuevo_liquidacion_contrato', 'crear'),
 ('P0044', N'2182', 'SSIPEM0001_btn_nuevo_liquidacion_contrato_et', 'crear'),
 ('P0044', N'2182', 'SSIPEM0001_btn_nuevo_maquinaria', 'crear'),
 ('P0044', N'2182', 'SSIPEM0001_btn_nuevo_maquinaria_sup', 'crear'),
 ('P0044', N'2182', 'SSIPEM0001_btn_nuevo_modificaciones_gastos', 'crear'),
 ('P0044', N'2182', 'SSIPEM0001_btn_nuevo_observaciones_entregable_et', 'crear'),
 ('P0044', N'2182', 'SSIPEM0001_btn_nuevo_panel_fotografico', 'crear'),
 ('P0044', N'2182', 'SSIPEM0001_btn_nuevo_paralizaciones', 'crear'),
 ('P0044', N'2182', 'SSIPEM0001_btn_nuevo_paralizaciones_det', 'crear'),
 ('P0044', N'2182', 'SSIPEM0001_btn_nuevo_paralizaciones_det_et', 'crear'),
 ('P0044', N'2182', 'SSIPEM0001_btn_nuevo_paralizaciones_et', 'crear'),
 ('P0044', N'2182', 'SSIPEM0001_btn_nuevo_personal_clave', 'crear'),
 ('P0044', N'2182', 'SSIPEM0001_btn_nuevo_personal_clave_sup', 'crear'),
 ('P0044', N'2182', 'SSIPEM0001_btn_nuevo_programacion_perfil', 'crear'),
 ('P0044', N'2182', 'SSIPEM0001_btn_nuevo_programacion_perfil_et', 'crear'),
 ('P0044', N'2182', 'SSIPEM0001_btn_nuevo_recepcion_et', 'crear'),
 ('P0044', N'2182', 'SSIPEM0001_btn_nuevo_recepcion_pats', 'crear'),
 ('P0044', N'2182', 'SSIPEM0001_btn_nuevo_resolucion_contrato_et', 'crear'),
 ('P0044', N'2182', 'SSIPEM0001_btn_nuevo_resolucion_contrato_pats', 'crear'),
 ('P0044', N'2182', 'SSIPEM0001_btn_nuevo_riesgos', 'crear'),
 ('P0044', N'2182', 'SSIPEM0001_btn_nuevo_riesgos_et', 'crear'),
 ('P0044', N'2182', 'SSIPEM0001_btn_nuevo_suspensiones', 'crear'),
 ('P0044', N'2182', 'SSIPEM0001_btn_nuevo_suspensiones_det', 'crear'),
 ('P0044', N'2182', 'SSIPEM0001_btn_nuevo_suspensiones_det_et', 'crear'),
 ('P0044', N'2182', 'SSIPEM0001_btn_nuevo_suspensiones_et', 'crear'),
 ('P0044', N'2182', 'SSIPEM0001_btn_nuevo_tramo_proyecto', 'crear'),
 ('P0044', N'2182', 'SSIPEM0001_btn_nuevo_tramo_proyecto_et', 'crear'),
 ('P0044', N'2182', 'SSIPEM0001_btn_nuevo_transferencia_et', 'crear'),
 ('P0044', N'2182', 'SSIPEM0001_btn_nuevo_transferencia_pats', 'crear'),
 ('P0044', N'2182', 'SSIPEM0001_btn_nuevo_variaciones', 'crear'),
 ('P0044', N'2182', 'SSIPEM0001_btn_nuevo_variaciones_det', 'crear'),
 ('P0044', N'2182', 'SSIPEM0001_btn_nuevo_variaciones_supervision', 'crear'),
 ('P0044', N'2183', 'SSIPEM0007btn_acciones_intervencion', 'leer'),
 ('P0044', N'2183', 'SSIPEM0007btn_cambio_fase', 'editar'),
 ('P0044', N'2183', 'SSIPEM0007btn_nueva_intervencion', 'crear'),
 ('P0044', N'2184', 'SSIPEM0043btn_acciones_convenio', 'leer'),
 ('P0044', N'2184', 'SSIPEM0043btn_nuevo_convenio', 'crear');


DECLARE @modulo TABLE (ModuloDesa nvarchar(100), CodigoMenu varchar(10), ModuloPauId nvarchar(100) NULL);
INSERT @modulo VALUES
 (N'2182', 'M0001', N'$(PAU_MODULO_M0001)'),   -- Seguimiento       <<< MOD_PK_MODUL del ambiente
 (N'2183', 'M0007', N'$(PAU_MODULO_M0007)'),   -- Proyecto          <<< MOD_PK_MODUL del ambiente
 (N'2184', 'M0043', N'$(PAU_MODULO_M0043)'),   -- Convenio          <<< MOD_PK_MODUL del ambiente
 (N'2185', 'M1051', N'$(PAU_MODULO_M1051)');   -- Asignar Proyecto  <<< MOD_PK_MODUL del ambiente
IF EXISTS (SELECT 1 FROM @modulo WHERE ModuloPauId IS NULL)
    THROW 57002, 'Completar @modulo con los ModuloPauId (MOD_PK_MODUL) de SSIPE en el PAU del ambiente.', 1;
IF NOT EXISTS (SELECT 1 FROM @map WHERE PerfilPauId IS NOT NULL)
    THROW 57003, 'Completar @map con los PerfilPauId del PAU del ambiente.', 1;

SELECT 'omitidos_sin_PerfilPauId' AS q, CodigoSSO, NombrePerfil FROM @map WHERE PerfilPauId IS NULL;
BEGIN TRANSACTION;

/* 1. Perfiles */
MERGE integracion.PauPerfil AS d
USING (SELECT @SistemaId SistemaId, PerfilPauId, IdPerfilSSO, CodigoSSO, NombrePerfil FROM @map WHERE PerfilPauId IS NOT NULL) AS s
   ON d.SistemaId = s.SistemaId AND d.PerfilPauId = s.PerfilPauId
WHEN MATCHED THEN UPDATE SET IdPerfil = s.IdPerfilSSO, CodigoPerfil = s.CodigoSSO, NombrePerfil = s.NombrePerfil, Activo = 1
WHEN NOT MATCHED THEN INSERT (SistemaId, PerfilPauId, IdPerfil, CodigoPerfil, NombrePerfil, Activo) VALUES (s.SistemaId, s.PerfilPauId, s.IdPerfilSSO, s.CodigoSSO, s.NombrePerfil, 1);

/* 2. Menus (ModuloPauId del ambiente via @modulo) */
INSERT integracion.PauMenu (SistemaId, PerfilPauId, ModuloPauId, CodigoMenu, NombreMenu, Url, Icono, Orden, Activo)
SELECT @SistemaId, m.PerfilPauId, mo.ModuloPauId, e.CodigoMenu, e.NombreMenu, e.Url, e.Icono, e.Orden, 1
FROM @menu e
JOIN @map m ON m.CodigoSSO = e.CodigoSSO AND m.PerfilPauId IS NOT NULL
JOIN @modulo mo ON mo.ModuloDesa = e.ModuloPauId
WHERE NOT EXISTS (SELECT 1 FROM integracion.PauMenu p WHERE p.SistemaId = @SistemaId AND p.PerfilPauId = m.PerfilPauId AND p.ModuloPauId = mo.ModuloPauId);

/* 3. Operaciones */
INSERT integracion.PauOperacion (SistemaId, PerfilPauId, ModuloPauId, HasClaim, Accion, Activo)
SELECT @SistemaId, m.PerfilPauId, mo.ModuloPauId, o.HasClaim, o.Accion, 1
FROM @op o
JOIN @map m ON m.CodigoSSO = o.CodigoSSO AND m.PerfilPauId IS NOT NULL
JOIN @modulo mo ON mo.ModuloDesa = o.ModuloPauId
WHERE NOT EXISTS (SELECT 1 FROM integracion.PauOperacion p WHERE p.SistemaId = @SistemaId AND p.PerfilPauId = m.PerfilPauId AND p.ModuloPauId = mo.ModuloPauId AND p.HasClaim = o.HasClaim);

/* 4. Verificacion */
SELECT 'resumen' AS q, p.CodigoPerfil, p.PerfilPauId, p.NombrePerfil,
       (SELECT COUNT(*) FROM integracion.PauMenu x WHERE x.SistemaId = p.SistemaId AND x.PerfilPauId = p.PerfilPauId AND x.Activo = 1) Menus,
       (SELECT COUNT(*) FROM integracion.PauOperacion x WHERE x.SistemaId = p.SistemaId AND x.PerfilPauId = p.PerfilPauId AND x.Activo = 1) Claims
FROM integracion.PauPerfil p WHERE p.SistemaId = @SistemaId ORDER BY p.CodigoPerfil;

IF @confirmar = 1 BEGIN COMMIT; PRINT 'Bloque OK (se confirma o revierte al final segun CONFIRMAR).'; END
ELSE BEGIN ROLLBACK; PRINT 'Simulacion: ROLLBACK. Poner @confirmar = 1 para aplicar.'; END
GO
GO
GO
-- ############################################################################
-- FUENTE: 30_claims_ejecucion_cva_PAU.sql
-- ############################################################################
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
IF DB_NAME() <> N'$(BASE_SSIPE)'
   OR OBJECT_ID(N'integracion.PauOperacion', N'U') IS NULL
BEGIN RAISERROR(N'Base incorrecta o falta la infraestructura de integracion: ejecucion cancelada.', 16, 1); SET NOEXEC ON; END
GO
SET NOCOUNT ON; SET XACT_ABORT ON;

DECLARE @confirmar bit = 1;   -- consolidado: lo decide la transaccion exterior (CONFIRMAR)

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

IF @confirmar = 1 BEGIN COMMIT; PRINT 'Bloque OK (se confirma o revierte al final segun CONFIRMAR).'; END
ELSE BEGIN ROLLBACK; PRINT 'Simulacion: ROLLBACK. Poner @confirmar = 1 para aplicar.'; END
GO
GO
GO
-- ############################################################################
-- FUENTE: 29_corte_identidad_sso_asignar_proyecto.sql
-- ############################################################################
/*
================================================================================
 29 - Corte de identidad SSO -> PAU: Asignar Proyecto y filtros de Seguimiento
================================================================================
 QUE ES
   Reemplaza a 13_cutover_asignar_proyecto_PAU_DBSSIPE2.sql (que solo cubria 1
   de los 4 SPs afectados). Deja a SSIPE sin leer identidad ni perfiles del SSO:

   1) seguimiento.paListarAsignarProyectoFaseUsuario (reescrito)
      - Candidatos a asignar: integracion.vw_UsuarioSsipe (PAU), perfiles
        P0023 / P0028 / P0029 como antes.
      - El "tipo de fase" (administrador / obra / expediente / preinversion) ya
        NO lo manda el front: se calcula aqui con el perfil del usuario de la
        sesion (IdUsuarioSesion, que inyecta el back desde el token PAU) usando
        la misma regla que aplicaba el front sobre NombrePerfil.
      - Misma forma de salida: {"Usuarios":[...]}.

   2) seguimiento.paListarSeguimientoProyecto / paListarSeguimientoSeguimiento /
      paListarSeguimientoConvenio (parche de UNA linea)
      Obtenian el CodigoPerfil del usuario desde DBSSO.login.vw_UsuarioInternoSistemaSsipe
      para decidir si solo ve sus proyectos asignados. Pasan a leerlo de
      integracion.vw_UsuarioSsipe (perfil que otorgo el PAU). Con esto:
        - un usuario nuevo en PAU (sin cuenta en el SSO) ya no queda con perfil
          NULL (que hoy lo dejaba sin ver nada salvo lo asignado),
        - se filtra con el perfil PAU y no con el viejo del SSO,
        - se elimina la ambiguedad de la vista SSO (usuarios con varias filas).
      El parche se aplica sobre la definicion VIGENTE del ambiente (no se
      reescribe el SP completo), por eso sirve igual en DESA, QA y PROD aunque
      otro script del pase haya tocado esos SPs. Exige encontrar la referencia
      exactamente una vez; si no, aborta sin tocar nada. Si ya estaba aplicado,
      lo informa y sigue (idempotente).

   Los otros 4 SPs del modulo (paInsertar / paAnular / paListar /
   paListar...Proyecto) no cambian: solo usan IdUsuario, que sigue siendo el
   historico de SSIPE (lo garantiza la homologacion, script 25).

 PRERREQUISITOS
   27 y 28 aplicados; back SSIPE con la version que inyecta IdUsuario/IdUsuarioSesion
   desde la sesion (rama dev_pau). Rollback: 29R.
================================================================================
*/
IF DB_NAME() <> N'$(BASE_SSIPE)'
   OR OBJECT_ID(N'integracion.vw_UsuarioSsipe', N'V') IS NULL
   OR OBJECT_ID(N'seguimiento.AsignarProyectoFase', N'U') IS NULL
BEGIN RAISERROR(N'Base incorrecta o falta integracion.vw_UsuarioSsipe (script 28): ejecucion cancelada.', 16, 1); SET NOEXEC ON; END
GO

CREATE OR ALTER PROCEDURE seguimiento.paListarAsignarProyectoFaseUsuario
    @parametro NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    IF ISJSON(@parametro) = 0
    BEGIN SELECT '{"estado":0,"mensaje":"Json Incorrecto"}'; RETURN; END

    DECLARE @result NVARCHAR(MAX),
            @tipoFase NVARCHAR(50),
            @idUsuarioSesion INT = TRY_CONVERT(INT, JSON_VALUE(@parametro, '$.IdUsuarioSesion')),
            @nombrePerfilSesion NVARCHAR(200);

    DECLARE @codigoObra         VARCHAR(20) = 'P0023',
            @codigoExpediente   VARCHAR(20) = 'P0028',
            @codigoPreinversion VARCHAR(20) = 'P0029';

    SELECT @nombrePerfilSesion = UPPER(NombrePerfil)
    FROM integracion.vw_UsuarioSsipe
    WHERE IdUsuario = @idUsuarioSesion;

    -- Misma regla que usaba el front sobre el NombrePerfil de la sesion, ahora resuelta en el servidor.
    SET @tipoFase = CASE
        WHEN @nombrePerfilSesion LIKE '%ADMINISTRADOR%' THEN 'administrador'
        WHEN @nombrePerfilSesion LIKE '%OBRA%'          THEN 'obra'
        WHEN @nombrePerfilSesion LIKE '%EXPEDIENTE%'    THEN 'expediente'
        WHEN @nombrePerfilSesion LIKE '%PREINVERSION%'  THEN 'preinversion'
    END;

    SELECT @result = (
        SELECT JSON_QUERY(
            COALESCE(
                (
                    SELECT
                        u.IdUsuario,
                        u.IdPersona,
                        u.IdPerfil,
                        u.CodigoPerfil,
                        u.NombrePerfil,
                        u.Usuario,
                        u.Documento,
                        u.Nombres,
                        u.ApellidoPaterno,
                        u.ApellidoMaterno,
                        LTRIM(RTRIM(
                            ISNULL(u.ApellidoPaterno, '') + ' ' +
                            ISNULL(u.ApellidoMaterno, '') + ', ' +
                            ISNULL(u.Nombres, '')
                        )) AS NombreCompleto,
                        u.Area,
                        u.IdArea,
                        ISNULL(asig.CantidadAsignados, 0) AS CantidadProyectosAsignados
                    FROM integracion.vw_UsuarioSsipe u
                    LEFT JOIN (
                        SELECT IdUsuario, COUNT(*) AS CantidadAsignados
                        FROM seguimiento.AsignarProyectoFase
                        WHERE Activo = 1 AND Asignado = 1
                        GROUP BY IdUsuario
                    ) asig ON u.IdUsuario = asig.IdUsuario
                    WHERE u.CodigoPerfil IN (@codigoObra, @codigoExpediente, @codigoPreinversion)
                      AND @tipoFase IS NOT NULL
                      AND (@tipoFase = 'administrador' OR u.NombrePerfil LIKE '%' + @tipoFase + '%')
                    ORDER BY u.ApellidoPaterno, u.ApellidoMaterno, u.Nombres
                    FOR JSON PATH
                )
            , '[]')
        ) AS Usuarios
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    );

    SELECT ISNULL(@result, '{}');
END
GO

/* ---- Parche de una linea en los 3 SPs de Seguimiento ---- */
SET XACT_ABORT ON;
DECLARE @viejo nvarchar(200) = N'DBSSO.login.vw_UsuarioInternoSistemaSsipe',
        @nuevo nvarchar(200) = N'integracion.vw_UsuarioSsipe';
DECLARE @sp TABLE (Nombre sysname);
INSERT @sp VALUES (N'paListarSeguimientoProyecto'), (N'paListarSeguimientoSeguimiento'), (N'paListarSeguimientoConvenio');
DECLARE @reporte TABLE (Procedimiento sysname, Resultado nvarchar(200));

DECLARE @nombre sysname, @def nvarchar(max), @veces int, @pos int, @resto nvarchar(40);
DECLARE c CURSOR LOCAL FAST_FORWARD FOR SELECT Nombre FROM @sp;
OPEN c; FETCH NEXT FROM c INTO @nombre;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @def = OBJECT_DEFINITION(OBJECT_ID(N'seguimiento.' + @nombre));
    IF @def IS NULL
    BEGIN
        DECLARE @msgNoExiste nvarchar(300) = CONCAT(N'No existe seguimiento.', @nombre, N'.');
        THROW 55001, @msgNoExiste, 1;
    END

    SET @veces = (DATALENGTH(@def) - DATALENGTH(REPLACE(@def, @viejo, N''))) / DATALENGTH(@viejo);
    IF @veces = 0 AND CHARINDEX(@nuevo, @def) > 0
        INSERT @reporte VALUES (@nombre, N'YA ESTABA APLICADO (no se toca)');
    ELSE IF @veces <> 1
    BEGIN
        DECLARE @msgVeces nvarchar(300) = CONCAT(N'seguimiento.', @nombre, N': se esperaba 1 referencia a la vista SSO y hay ', @veces, N'. Revisar a mano; no se aplico nada.');
        THROW 55002, @msgVeces, 1;
    END
    ELSE
    BEGIN
        SET @def = REPLACE(@def, @viejo, @nuevo);
        -- CREATE PROCEDURE -> ALTER PROCEDURE conservando permisos y el resto del texto tal cual
        SET @pos = CHARINDEX(N'CREATE', @def);
        SET @resto = LTRIM(REPLACE(REPLACE(REPLACE(SUBSTRING(@def, @pos + 6, 40), CHAR(13), N' '), CHAR(10), N' '), CHAR(9), N' '));
        IF @pos = 0 OR (@resto NOT LIKE N'PROC%' AND @resto NOT LIKE N'OR ALTER PROC%')
        BEGIN
            DECLARE @msgCab nvarchar(300) = CONCAT(N'seguimiento.', @nombre, N': cabecera CREATE PROCEDURE no reconocida. No se aplico nada.');
            THROW 55003, @msgCab, 1;
        END
        IF @resto LIKE N'PROC%' SET @def = STUFF(@def, @pos, 6, N'ALTER');
        EXEC sys.sp_executesql @def;
        INSERT @reporte VALUES (@nombre, N'APLICADO');
    END
    FETCH NEXT FROM c INTO @nombre;
END
CLOSE c; DEALLOCATE c;

SELECT * FROM @reporte;
GO

/* ---- Verificacion: ningun objeto de SSIPE lee identidad del SSO (salvo la homologacion, que lo usa para reutilizar IdUsuario) ---- */
SELECT Objeto = s.name + '.' + o.name, o.type_desc
FROM sys.objects o JOIN sys.schemas s ON s.schema_id = o.schema_id
WHERE o.type IN ('P', 'V', 'FN', 'IF', 'TF')
  AND (OBJECT_DEFINITION(o.object_id) LIKE N'%vw_UsuarioInternoSistemaSsipe%' OR OBJECT_DEFINITION(o.object_id) LIKE N'%vw_PerfilesSistemaSsipe%')
  AND NOT (s.name = N'integracion' AND o.name = N'paHomologarUsuariosPau');
IF EXISTS (
    SELECT 1 FROM sys.objects o JOIN sys.schemas s ON s.schema_id = o.schema_id
    WHERE o.type IN ('P', 'V', 'FN', 'IF', 'TF')
      AND (OBJECT_DEFINITION(o.object_id) LIKE N'%vw_UsuarioInternoSistemaSsipe%' OR OBJECT_DEFINITION(o.object_id) LIKE N'%vw_PerfilesSistemaSsipe%')
      AND NOT (s.name = N'integracion' AND o.name = N'paHomologarUsuariosPau'))
    THROW 55004, 'Quedan objetos leyendo identidad del SSO (ver resultado anterior).', 1;
PRINT 'Corte de identidad SSO aplicado: SSIPE resuelve usuarios y perfiles solo desde PAU.';
GO
GO
GO
-- ############################################################################
-- VERIFICACION PARTE 2
-- ############################################################################
SELECT Verificacion = N'Perfiles homologados', p.CodigoPerfil, p.NombrePerfil, p.PerfilPauId,
       Menus = (SELECT STRING_AGG(m.CodigoMenu, ',') FROM integracion.PauMenu m WHERE m.SistemaId = p.SistemaId AND m.PerfilPauId = p.PerfilPauId AND m.Activo = 1),
       Claims = (SELECT COUNT(*) FROM integracion.PauOperacion o WHERE o.SistemaId = p.SistemaId AND o.PerfilPauId = p.PerfilPauId AND o.Activo = 1)
FROM integracion.PauPerfil p WHERE p.SistemaId = $(PAU_SISTEMA_ID) AND p.Activo = 1 ORDER BY p.CodigoPerfil;
IF (SELECT COUNT(*) FROM integracion.PauPerfil WHERE SistemaId = $(PAU_SISTEMA_ID) AND Activo = 1 AND CodigoPerfil IN ('P0001', 'P0023', 'P0024', 'P0025', 'P0028', 'P0029', 'P0045')) <> 7
BEGIN RAISERROR(N'Parte 2: no quedaron homologados los 7 perfiles del pase.', 16, 1); SET NOEXEC ON; END
IF EXISTS (SELECT 1 FROM integracion.PauOperacion o JOIN integracion.PauPerfil p ON p.SistemaId = o.SistemaId AND p.PerfilPauId = o.PerfilPauId
           WHERE p.CodigoPerfil = 'P0045' AND o.Activo = 1)
BEGIN RAISERROR(N'Parte 2: P0045 (solo lectura) no debe tener claims.', 16, 1); SET NOEXEC ON; END
GO
-- ############################################################################
-- CIERRE: confirma o revierte todo lo anterior
-- ############################################################################
IF @@TRANCOUNT <> 1
BEGIN RAISERROR(N'Transaccion exterior inconsistente: se revierte.', 16, 1); IF @@TRANCOUNT > 0 ROLLBACK; SET NOEXEC ON; END
GO
IF $(CONFIRMAR) = 1 BEGIN COMMIT; PRINT N'COMMIT REALIZADO.'; END
ELSE BEGIN ROLLBACK; PRINT N'SIMULACION: ROLLBACK de todo. Revisar la salida y repetir con CONFIRMAR "1" en una conexion nueva.'; END
GO
SET NOEXEC OFF;
GO
