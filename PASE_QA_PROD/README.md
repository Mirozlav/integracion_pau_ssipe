# Pase a QA/PROD — SSIPE entra solo por PAU (Fase 1)

Objetivo: desde el pase a producción SSIPE **solo** acepta sesiones del PAU. La base del SSO (DBSSO) sigue viva, pero únicamente como **catálogo de solo lectura** (áreas y el `IdUsuario` histórico para homologar). SSIPE ya no lee identidad ni perfiles del SSO, y no hay que desplegar nada en DBSSO.

Revalidado contra **DBSSIPE3** el 28/09/2026: `P00` sale `ListoParaPase=1`. Esto no significa que PAU esté instalado: DBSSIPE3 todavía no tiene el esquema `integracion` y sus SP de Seguimiento son anteriores a DBSSIPE2. Ver el [orden completo y evidencia del pase](../../DESPLIEGUE/README_PASE_PRODUCCION.md). El consolidado actualizado requiere P01, 27 y 28 antes de ejecutarse; después se completa la homologación y el corte 29.

## `DESPLIEGUE/DESPLIEGUE_2_DBSSO.sql` ya NO se ejecuta en QA/PROD

| Bloque del script SSO | Qué hacía | Reemplazo con PAU |
|---|---|---|
| Bloque 1 — `login.paListarLoginArea` + `login.vw_Area` en DBSSO | Catálogo de áreas para el front | `28_identidad_usuario_y_areas.sql` crea `integracion.paListarArea` **en la base SSIPE**, con la misma lógica y el mismo JSON (verificado idéntico en DESA), leyendo las tablas base de DBSSO. `GeneralController.ListarArea` ahora lo llama por `cnx_ssipe`. |
| Bloque 2 — 11 claims de Ejecución CVA en `login.Operacion` para P0023/P0024/P0025 | Mostrar botones nuevo/acciones de Conservación, Mejoramiento, Socioambiental, Liquidación y Panel Fotográfico | Con PAU los claims del token salen de `integracion.PauOperacion`. `P02` ya los trae (vienen del export del SSO de DESA) y `30_claims_ejecucion_cva_PAU.sql` garantiza la misma matriz por perfil, resolviendo todo por código. |

## Requisitos del lado PAU (equipo PAU, en el PAU del ambiente)

1. SSIPE registrado como sistema (como el script 15 en DESA), con `SIS_V_LINKSI = <URL del front SSIPE del ambiente>/pau/callback`.
2. Módulos M0001 Seguimiento, M0007 Proyecto, M0043 Convenio y M1051 Asignar Proyecto.
3. Perfiles/roles/grupos SSIPE (script 18 adaptado al ambiente).

De ahí salen tres datos para `P02`: `SistemaId`, los `PerfilPauId` y los `ModuloPauId`.

## Orden en la base SSIPE del ambiente

En cada script, reemplazar el nombre de base de la cabecera (`<<<`) por el de la base SSIPE del ambiente. Todos arrancan en modo simulación o solo lectura donde aplica.

| Paso | Script | Qué hace |
|---:|---|---|
| 0 | `PASE_QA_PROD/P00_precheck_QA_PROD.sql` | Solo lectura. Correrlo con el usuario del back. Debe dar `ListoParaPase=1`. |
| 1 | `PASE_QA_PROD/P01_infraestructura_integracion.sql` | Esquema `integracion` y sus 5 tablas (01 + directorio del 11), sin candados de DESA. |
| 2 | `27_sp_sesion_directorio_PAU.sql` | `paResolverSesionPau` y `paRegistrarDirectorioPau` sin el `DB_NAME()<>'DBSSIPE2'` que traían en el cuerpo (con él fallaban fuera de DESA). |
| 3 | `28_identidad_usuario_y_areas.sql` | Vista `integracion.vw_UsuarioSsipe` + `integracion.paListarArea` (reemplaza el bloque 1). |
| 4 | `PASE_QA_PROD/P02_homologacion_perfiles_QA_PROD.sql` | Perfiles, menús y claims con los ids del PAU del ambiente. |
| 5 | `30_claims_ejecucion_cva_PAU.sql` | Garantiza los 11 claims del bloque 2. |
| 6 | `25_SP_paHomologarUsuariosPau_DBSSIPE2.sql` | Crea el SP de homologación v2, que también llena el directorio. |
| 7 | `24` (en el PAU) → `EXEC integracion.paHomologarUsuariosPau` | Homologa a los usuarios reales. El JSON que devuelve el 24 va tal cual al 25. |
| 8 | `29_corte_identidad_sso_asignar_proyecto.sql` | Corte: Asignar Proyecto y los filtros de Seguimiento pasan a PAU. **Correrlo en la misma ventana del despliegue del back/front de `dev_pau`.** Con el back anterior, la lista de Asignar Proyecto saldría vacía. |

**Rollback:** poner `PauIntegration:Enabled=false` en el back y correr `29R_rollback_corte_identidad_sso.sql`. Las tablas de `integracion` pueden quedar; no afectan al SSO.

## Back y front (rama `dev_pau`)

- **Back:** con `PauIntegration:Enabled=true`:
  - Solo acepta el token PAU y `api/Token/tksistema` responde `403 SSO_DESHABILITADO`.
  - `IdUsuario` (Seguimiento/Convenio), `IdUsuarioSesion` (Asignar Proyecto) y `UsuarioCreacionAuditoria` se toman de la sesión; lo que mande el front se ignora.
  - Los 5 endpoints de Asignar Proyecto exigen el menú **M1051** en la sesión.
  - Configurar en `appsettings.json` del ambiente: `SistemaId`, las URLs del PAU del ambiente y `SessionKey` (secreto propio del ambiente).
- **Front:**
  - La entrada `sso-interno` (enlace del SSO clásico) redirige al portal PAU.
  - Los guards solo aceptan sesión PAU.
  - `config.json` del ambiente: `apiUrl` y `pauPortalUrl` de ese ambiente. **Ojo:** en `dev_pau` quedó commiteado con `localhost` (commit `331cfbad`).

## Pendiente funcional (no bloquea el pase de Obra)

- P0028 (Especialista de Expediente) y P0029 (Especialista Preinversión) aún no están homologados en PAU. Mientras no se creen con 18/P02, Asignar Proyecto no lista candidatos de esas fases.
- Los usuarios existentes aparecen en Asignar Proyecto cuando se homologan con el 25 v2 o cuando ingresan por PAU. En DESA, 3 de los 4 usuarios homologados antes de este cambio siguen sin fila en el directorio.
