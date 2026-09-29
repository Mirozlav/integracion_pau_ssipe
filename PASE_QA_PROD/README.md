# Pase a QA/PROD — SSIPE entra solo por PAU (Fase 1)

Objetivo: desde el pase a producción SSIPE **solo** acepta sesiones del PAU. La base del SSO (DBSSO) sigue viva, pero únicamente como **catálogo de solo lectura** (áreas y el `IdUsuario` histórico para homologar). SSIPE ya no lee identidad ni perfiles del SSO, y no hay que desplegar nada en DBSSO.

Revalidado contra **DBSSIPE3** el 28/09/2026: `P00` sale `ListoParaPase=1`. Esto no significa que PAU esté instalado: DBSSIPE3 todavía no tiene el esquema `integracion` y sus SP de Seguimiento son anteriores a DBSSIPE2. Ver el [orden completo y evidencia del pase](../../DESPLIEGUE/README_PASE_PRODUCCION.md). El consolidado actualizado requiere P01, 27 y 28 antes de ejecutarse; después se completa la homologación y el corte 29.

## `DESPLIEGUE/DESPLIEGUE_2_DBSSO.sql` ya NO se ejecuta en QA/PROD

| Bloque del script SSO | Qué hacía | Reemplazo con PAU |
|---|---|---|
| Bloque 1 — `login.paListarLoginArea` + `login.vw_Area` en DBSSO | Catálogo de áreas para el front | `28_identidad_usuario_y_areas.sql` crea `integracion.paListarArea` **en la base SSIPE**, con la misma lógica y el mismo JSON (verificado idéntico en DESA), leyendo las tablas base de DBSSO. `GeneralController.ListarArea` ahora lo llama por `cnx_ssipe`. |
| Bloque 2 — 11 claims de Ejecución CVA en `login.Operacion` para P0023/P0024/P0025 | Mostrar botones nuevo/acciones de Conservación, Mejoramiento, Socioambiental, Liquidación y Panel Fotográfico | Con PAU los claims del token salen de `integracion.PauOperacion`. `P02` ya los trae (vienen del export del SSO de DESA) y `30_claims_ejecucion_cva_PAU.sql` garantiza la misma matriz por perfil, resolviendo todo por código. |

## Requisitos del lado PAU (equipo PAU, en el PAU del ambiente)

`P03_sistema_modulos_perfiles_SSIPE_en_PAU.sql` (28/09) deja todo en un solo script portable, que reemplaza a los scripts 15 y 18:

1. Registra SSIPE como sistema, con `SIS_V_LINKSI = <URL del front SSIPE del ambiente>/pau/callback`.
2. Crea los módulos M0001 Seguimiento, M0007 Proyecto, M0043 Convenio y M1051 Asignar Proyecto.
3. Crea los perfiles, roles y grupos P0001, P0023, P0024, P0025, **P0028 ESPECIALISTA DE EXPEDIENTE**, **P0029 ESPECIALISTA PREINVERSION** y **P0045 LECTOR GENERAL** para QA/PROD.

Su salida entrega los datos que necesita la parte 2: `SistemaId`, los siete `PerfilPauId` y los `ModuloPauId`. En DESA ya se aplicó el alcance anterior: solo creó P0045 (`PerfilPauId` 2053). P0028/P0029 se incorporan en QA/PROD; no reejecutar P03 en DESA para crearlos sin aprobación del ambiente.

### Perfil P0045 LECTOR GENERAL ("Seguimiento" en la lista de usuarios)

Es el perfil de solo lectura. Reutiliza el código y el `IdPerfil` 1051 del P0045 del SSO, así que queda homologado sin tocar DBSSO.

- **Menús:** M0001, M0007 y M0043. No tiene M1051, porque Asignar Proyecto es un módulo de escritura.
- **Qué ve:** los listados no lo restringen a proyectos asignados (solo P0023, P0028 y P0029 tienen esa restricción), así que ve toda la data.
- **Claims en SSIPE: ninguno.** En el front, los `btn_acciones_*` (clasificados como "leer") muestran Editar y Eliminar, por eso no se le asignan.
- **En PAU:** solo tiene el flag PRISEL. Aunque se le agregara un claim de escritura por error, la sesión lo filtraría.
- **Límite:** el back no bloquea los endpoints de escritura por perfil. La solo lectura se garantiza en el front y en el token.

## Scripts consolidados (recomendado para QA/PROD)

`herramientas/armar_integracion_pau_ssipe.py` los genera a partir de los fuentes; no se editan a mano. Todos siguen las mismas reglas:
- se abren y ejecutan tal cual en la ventana de consultas del gestor (sin modo SQLCMD);
- los parámetros van en un único bloque `EDITAR SOLO AQUI` (tabla temporal `#param`): `BASE_SSIPE`, `CONFIRMAR` y, en la parte 2, los ids del PAU;
- van en una transacción: `CONFIRMAR = 0` simula todo y `1` aplica; ante el primer error se detienen y revierten, y se pueden reejecutar en la misma ventana.

| Script | Contiene | Cuándo |
|---|---|---|
| `integracion_pau_ssipe_1_estructura.sql` | P01 + 27 + 28 + 25 | Antes de `DESPLIEGUE_1_DBSSIPE.sql`, que lo requiere. No cambia el comportamiento del back anterior. |
| `integracion_pau_ssipe_2_perfiles_y_corte.sql` | P02 + 30 + 29 | Después de `DESPLIEGUE_1` (y PATS), en la ventana del back/front. Los ids del PAU (salida de P03) van en su bloque `EDITAR SOLO AQUI`. |
| `integracion_pau_ssipe_R_rollback_corte.sql` | 29R | Solo para volver al SSO. |

**Ensayo del 28/09 en DBSSIPE3**, en una sola conexión y transacción revertida:
- Se corrió la cadena parte 1 → `DESPLIEGUE_1` → `despliegue_pats` → parte 2 (con ids de DESA) → carga masiva de 22 proyectos, sin errores.
- Sesión P0045: M0001, M0007 y M0043, con 0 claims.
- Listados: P0045 ve toda la data; P0023 sin asignaciones, vacío. El coordinador ve candidatos en Asignar Proyecto.
- Quedaron 0 objetos leyendo identidad del SSO.
- Tras revertir, DBSSIPE3 quedó sin `integracion`, sin PATS, sin `IdSector` y con 0 transacciones.

## Orden en la base SSIPE del ambiente (scripts sueltos, equivalente a los consolidados)

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

## Consideraciones operativas (no bloquean el pase)

- P0028 (Especialista de Expediente) y P0029 (Especialista Preinversión) quedan incluidos en PAU y en la homologación SSIPE para QA/PROD. En cada ambiente se debe ejecutar P03, capturar los `PerfilPauId` generados y colocarlos en `PAU_PERFIL_P0028` y `PAU_PERFIL_P0029` antes de ejecutar la parte 2. El lote vigente de 51 usuarios no contiene especialistas de estas fases; cuando se definan sus DNI, se agregan a PAU_03/PAU_05 sin cambiar la estructura del pase.
- Los usuarios existentes aparecen en Asignar Proyecto cuando se homologan con el 25 v2 o cuando ingresan por PAU. En DESA, 3 de los 4 usuarios homologados antes de este cambio siguen sin fila en el directorio.
- **Vigencia de la homologación:** el 25 usa 90 días por defecto y el login no la renueva. Para los lotes de producción, el generador pasa `--vigente-dias 365`. Vencida la vigencia, o si PAU cambia la dependencia del usuario (contrato nuevo), el login responde `HOMOLOGACION_PENDIENTE` y hay que volver a correr el lote.
